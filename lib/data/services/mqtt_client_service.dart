import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/live_status.dart';

/// Singleton service managing the full lifecycle of the EMQX Cloud Serverless
/// MQTT connection for the Flutter application.
///
/// Responsibilities (Flutter Architecture Section 5.1):
/// - Establishes and maintains a TLS-secured MQTT connection to EMQX Cloud.
/// - Subscribes to the five per-device state and heartbeat topics.
/// - Accumulates retained messages from each topic into a single [LiveStatus]
///   value emitted on [liveStatusStream].
/// - Maintains a 90-second heartbeat watchdog timer; sets
///   [LiveStatus.isUnresponsive] when no heartbeat is received within the window.
/// - Implements exponential backoff reconnection: 2 s initial delay, doubling
///   on each failure, ceiling of 60 s (constants from [AppConfig]).
///
/// This service is subscribe-only. The Flutter application never publishes to
/// any MQTT topic (Backend Architecture Section 2.7, ACL table).
class MqttClientService {
  MqttClientService._();
  static final MqttClientService instance = MqttClientService._();

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  MqttServerClient? _client;
  String? _deviceId;
  bool _disposed = false;
  bool _reconnecting = false;

  LiveStatus _currentStatus = const LiveStatus.loading();

  final StreamController<LiveStatus> _statusController =
      StreamController<LiveStatus>.broadcast();

  Timer? _heartbeatTimer;
  Duration _reconnectDelay = AppConfig.mqttInitialReconnectDelay;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Stream<LiveStatus> get liveStatusStream => _statusController.stream;

  Future<void> connect(String deviceId) async {
    _deviceId = deviceId;
    _disposed = false;
    _emit(const LiveStatus.loading());
    await _connect();
  }

  void dispose() {
    _disposed = true;
    _heartbeatTimer?.cancel();
    _client?.disconnect();
    _statusController.close();
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  Future<void> _connect() async {
    if (_disposed || _deviceId == null) return;

    // Use a timestamp suffix to guarantee a unique clientId on every attempt.
    // EMQX Cloud Serverless rejects connections from a clientId that is already
    // connected; the timestamp prevents accidental collisions across reconnects.
    final clientId =
        'flutter_${_deviceId}_${DateTime.now().millisecondsSinceEpoch}';

    _client = MqttServerClient(AppConfig.emqxHost, clientId)
      ..port = AppConfig.emqxPort
      ..secure = true
      ..keepAlivePeriod = 60
      // Increase connection timeout: default 5 s is too short for some mobile
      // networks. 30 s gives the TLS handshake time to complete on poor signals.
      // ..connectionTimeoutPeriod = 30
      ..logging(on: false)
      ..onDisconnected = _onDisconnected
      ..onConnected = _onConnected
      ..onSubscribed = _onSubscribed;

    // Do NOT set securityContext explicitly on Android. The mqtt_client package
    // initialises its own TLS context from the platform trust store when
    // secure = true and securityContext is left null. Assigning
    // SecurityContext.defaultContext directly can interfere with that
    // initialisation on some Android versions and cause the broker to drop the
    // connection before sending a CONNACK.

    final connectMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(AppConfig.emqxUsername, AppConfig.emqxPassword)
        .startClean();

    _client!.connectionMessage = connectMessage;

    try {
      _log(
        'Connecting to ${AppConfig.emqxHost}:${AppConfig.emqxPort} '
        'as $clientId',
      );
      final status = await _client!.connect();
      if (status?.state != MqttConnectionState.connected) {
        _log('Connection returned non-connected state: ${status?.state}');
        _scheduleReconnect();
      }
    } on Exception catch (e) {
      _log('Connection failed: $e');
      _scheduleReconnect();
    }
  }

  // ---------------------------------------------------------------------------
  // Topic subscriptions
  // ---------------------------------------------------------------------------

  void _subscribeToTopics() {
    final id = _deviceId;
    if (id == null || _client == null) return;

    final topics = [
      'pestTrapping/$id/state/uvLamp',
      'pestTrapping/$id/state/trapDoor',
      'pestTrapping/$id/state/zapper',
      'pestTrapping/$id/state/connection',
      'pestTrapping/$id/heartbeat',
    ];

    for (final topic in topics) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }

    _client!.updates?.listen(_onMessage);
  }

  // ---------------------------------------------------------------------------
  // Message handling
  // ---------------------------------------------------------------------------

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final topic = message.topic;
      final payload = message.payload as MqttPublishMessage;
      final raw = MqttPublishPayload.bytesToStringAsString(
        payload.payload.message,
      );
      _applyMessage(topic, raw);
    }
  }

  void _applyMessage(String topic, String raw) {
    final id = _deviceId;
    if (id == null) return;

    String? extractStringField(String json, String key) {
      final pattern = '"$key"';
      final keyIndex = json.indexOf(pattern);
      if (keyIndex == -1) return null;
      final afterColon = json.indexOf(':', keyIndex) + 1;
      final valueStart = json.indexOf('"', afterColon) + 1;
      final valueEnd = json.indexOf('"', valueStart);
      if (valueStart <= 0 || valueEnd <= 0) return null;
      return json.substring(valueStart, valueEnd);
    }

    if (topic == 'pestTrapping/$id/state/uvLamp') {
      final s = extractStringField(raw, 'status');
      if (s != null) {
        _currentStatus = _currentStatus.copyWith(uvLamp: s);
        _emit(_currentStatus);
      }
    } else if (topic == 'pestTrapping/$id/state/trapDoor') {
      final s = extractStringField(raw, 'status');
      if (s != null) {
        _currentStatus = _currentStatus.copyWith(trapDoor: s);
        _emit(_currentStatus);
      }
    } else if (topic == 'pestTrapping/$id/state/zapper') {
      final s = extractStringField(raw, 'status');
      if (s != null) {
        _currentStatus = _currentStatus.copyWith(zapper: s);
        _emit(_currentStatus);
      }
    } else if (topic == 'pestTrapping/$id/state/connection') {
      final s = extractStringField(raw, 'status');
      if (s != null) {
        _currentStatus = _currentStatus.copyWith(connectionStatus: s);
        _emit(_currentStatus);
      }
    } else if (topic == 'pestTrapping/$id/heartbeat') {
      _currentStatus = _currentStatus.copyWith(isUnresponsive: false);
      _emit(_currentStatus);
      _resetHeartbeatTimer();
    }
  }

  // ---------------------------------------------------------------------------
  // Heartbeat watchdog
  // ---------------------------------------------------------------------------

  void _resetHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer(AppConfig.heartbeatTimeout, _onHeartbeatTimeout);
  }

  void _onHeartbeatTimeout() {
    _log('Heartbeat timeout — marking device as unresponsive.');
    _currentStatus = _currentStatus.copyWith(isUnresponsive: true);
    _emit(_currentStatus);
  }

  // ---------------------------------------------------------------------------
  // Reconnection
  // ---------------------------------------------------------------------------

  void _scheduleReconnect() {
    if (_disposed || _reconnecting) return;
    _reconnecting = true;

    _log('Scheduling reconnect in ${_reconnectDelay.inSeconds}s.');
    Future.delayed(_reconnectDelay, () async {
      _reconnecting = false;
      if (_disposed) return;

      _reconnectDelay = Duration(
        seconds: (_reconnectDelay.inSeconds * 2).clamp(
          0,
          AppConfig.mqttMaxReconnectDelay.inSeconds,
        ),
      );

      await _connect();
    });
  }

  // ---------------------------------------------------------------------------
  // MQTT client callbacks
  // ---------------------------------------------------------------------------

  void _onConnected() {
    _log('Connected to EMQX broker.');
    _reconnectDelay = AppConfig.mqttInitialReconnectDelay;
    _subscribeToTopics();
    _resetHeartbeatTimer();
  }

  void _onDisconnected() {
    _log('Disconnected from EMQX broker.');
    _heartbeatTimer?.cancel();

    if (!_disposed) {
      _currentStatus = _currentStatus.copyWith(
        connectionStatus: 'offline',
        isUnresponsive: false,
      );
      _emit(_currentStatus);
      _scheduleReconnect();
    }
  }

  void _onSubscribed(String topic) {
    _log('Subscribed: $topic');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _emit(LiveStatus status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[MqttClientService] $message');
    }
  }
}
