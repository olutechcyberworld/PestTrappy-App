import 'dart:async';
import 'dart:io';

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
/// - Maintains a 90-second heartbeat watchdog timer; sets [LiveStatus
///   .isUnresponsive] when no heartbeat is received within the window.
/// - Implements exponential backoff reconnection: 2 s initial delay, doubling
///   on each failure, ceiling of 60 s (constants from [AppConfig]).
///
/// This service is subscribe-only. The Flutter application never publishes to
/// any MQTT topic (Backend Architecture Section 2.7, ACL table).
///
/// Lifecycle: [connect] is called once during the application initialisation
/// sequence (Flutter Architecture Section 7, Step 5) with the resolved
/// [deviceId]. [dispose] is called on MQTT client disconnect at re-pair.
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

  /// Current accumulated live status. Mutated by [_applyRetainedMessage] as
  /// each retained or live state message arrives.
  LiveStatus _currentStatus = const LiveStatus.loading();

  final StreamController<LiveStatus> _statusController =
      StreamController<LiveStatus>.broadcast();

  Timer? _heartbeatTimer;
  Duration _reconnectDelay = AppConfig.mqttInitialReconnectDelay;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Broadcast stream of [LiveStatus] values. Begins with [LiveStatus.loading]
  /// and emits a new value on every topic update or heartbeat timer change.
  /// Never closes while the service is alive; consumers do not need to handle
  /// a done event during normal operation.
  Stream<LiveStatus> get liveStatusStream => _statusController.stream;

  /// Establishes the EMQX connection for [deviceId] and begins topic
  /// subscriptions. Safe to call from the splash screen's async init sequence.
  ///
  /// Emits [LiveStatus.loading] immediately so the status screen shows a
  /// loading state while the broker delivers retained messages.
  Future<void> connect(String deviceId) async {
    _deviceId = deviceId;
    _disposed = false;
    _emit(const LiveStatus.loading());
    await _connect();
  }

  /// Cancels the heartbeat timer, disconnects from the broker, and disposes
  /// the stream controller. Called during the re-pair flow (Flutter
  /// Architecture Section 6.3) before navigating to the pairing screen.
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

    final clientId =
        'flutter_${_deviceId}_${DateTime.now().millisecondsSinceEpoch}';

    _client = MqttServerClient(AppConfig.emqxHost, clientId)
      ..port = AppConfig.emqxPort
      ..secure = true
      ..keepAlivePeriod = 60
      ..logging(on: false)
      ..onDisconnected = _onDisconnected
      ..onConnected = _onConnected
      ..onSubscribed = _onSubscribed;

    // EMQX Cloud Serverless uses CA-signed certificates; the system trust
    // store on Android is sufficient. No custom certificate pinning is needed
    // at prototype scale.
    _client!.securityContext = SecurityContext.defaultContext;

    final connectMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(AppConfig.emqxUsername, AppConfig.emqxPassword)
        .withWillQos(MqttQos.atLeastOnce)
        .startClean();

    _client!.connectionMessage = connectMessage;

    try {
      final status = await _client!.connect();
      if (status?.state != MqttConnectionState.connected) {
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

    // Listen to the updates stream for incoming messages.
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

  /// Applies a single incoming MQTT message to [_currentStatus] and emits the
  /// updated value on [liveStatusStream].
  ///
  /// Uses [LiveStatus.copyWith] so that each arriving retained message updates
  /// only its own field, leaving fields from topics not yet received intact.
  /// This is the correct pattern for retained-message accumulation: the broker
  /// delivers each retained message independently rather than as a combined
  /// payload.
  void _applyMessage(String topic, String raw) {
    final id = _deviceId;
    if (id == null) return;

    // Strip JSON manually for the small, fixed payloads used here to avoid
    // importing a JSON library into the service layer. Each payload has at
    // most two keys; a simple string search is deterministic and auditable.
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
      final status = extractStringField(raw, 'status');
      if (status != null) {
        _currentStatus = _currentStatus.copyWith(uvLamp: status);
        _emit(_currentStatus);
      }
    } else if (topic == 'pestTrapping/$id/state/trapDoor') {
      final status = extractStringField(raw, 'status');
      if (status != null) {
        _currentStatus = _currentStatus.copyWith(trapDoor: status);
        _emit(_currentStatus);
      }
    } else if (topic == 'pestTrapping/$id/state/zapper') {
      final status = extractStringField(raw, 'status');
      if (status != null) {
        _currentStatus = _currentStatus.copyWith(zapper: status);
        _emit(_currentStatus);
      }
    } else if (topic == 'pestTrapping/$id/state/connection') {
      final status = extractStringField(raw, 'status');
      if (status != null) {
        _currentStatus = _currentStatus.copyWith(connectionStatus: status);
        _emit(_currentStatus);
      }
    } else if (topic == 'pestTrapping/$id/heartbeat') {
      // Any heartbeat message resets the unresponsive flag and the watchdog.
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

      // Advance the backoff delay for the next failure, capped at the ceiling.
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
    // Reset the backoff delay on a successful connection.
    _reconnectDelay = AppConfig.mqttInitialReconnectDelay;
    _subscribeToTopics();
    _resetHeartbeatTimer();
  }

  void _onDisconnected() {
    _log('Disconnected from EMQX broker.');
    _heartbeatTimer?.cancel();

    if (!_disposed) {
      // Emit offline status immediately so the UI reacts without waiting for
      // the reconnection attempt to complete.
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
