import '../models/live_status.dart';

/// Repository contract for the live, MQTT-backed device status stream.
///
/// The concrete implementation (data layer) wraps the [MqttClientService]
/// and accumulates retained messages from the five subscribed state and
/// heartbeat topics into a single [LiveStatus] value emitted on the stream.
///
/// The stream begins immediately with [LiveStatus.loading] and emits updates
/// as each retained message arrives from the EMQX broker on subscription
/// and as subsequent real-time state changes are published by the ESP32.
///
/// Consumers should handle three [LiveStatus] states:
/// - [LiveStatus.isLoading] — initial, before any retained messages arrive.
/// - [LiveStatus.isOnline] — device connected, all component states available.
/// - [LiveStatus.isOffline] — LWT received or TCP connection closed.
///
/// The [LiveStatus.isUnresponsive] flag is orthogonal to the above and may
/// be true simultaneously with [LiveStatus.isOnline].
abstract class ITrapStatusRepository {
  /// Continuous stream of [LiveStatus] values backed by the active MQTT
  /// subscription. Never closes unless the [MqttClientService] is disposed.
  Stream<LiveStatus> get liveStatusStream;
}
