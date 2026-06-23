import 'package:equatable/equatable.dart';

/// The live, MQTT-backed snapshot of a device's operational state, as
/// maintained by the [ITrapStatusRepository] stream and consumed by
/// `liveStatusProvider` (Flutter Architecture Sections 5.1 and 8).
///
/// This is the primary data model for the live trap status screen and the
/// dashboard connection badge. It differs from [DeviceState] in that it is
/// not sourced from Supabase: all fields are populated from retained MQTT
/// messages delivered by the EMQX broker on subscription, and updated in
/// real time as the ESP32 publishes state changes.
///
/// The [isUnresponsive] field has no Supabase or MQTT equivalent; it is
/// synthesised entirely by the MQTT client service's internal 90-second
/// heartbeat timer (Backend Architecture Section 2.5, Flutter Architecture
/// Section 5.1). It is orthogonal to [connectionStatus]: a device can be
/// [connectionStatus] = `"online"` (TCP alive, LWT not triggered) while
/// simultaneously [isUnresponsive] = `true` (no heartbeat in 90 s), which
/// indicates the ESP32 process has stalled without closing the TCP connection.
class LiveStatus extends Equatable {
  /// UV lamp state derived from the retained `state/uvLamp` message.
  /// Valid values: `"on"`, `"off"`. Empty string during initial load.
  final String uvLamp;

  /// Trap door state derived from the retained `state/trapDoor` message.
  /// Valid values: `"open"`, `"closed"`. Empty string during initial load.
  final String trapDoor;

  /// Electrocution grid state derived from the retained `state/zapper` message.
  /// Valid values: `"active"`, `"idle"`. Empty string during initial load.
  final String zapper;

  /// Device connection state derived from the retained `state/connection`
  /// message or the LWT delivery. Valid values: `"online"`, `"offline"`.
  final String connectionStatus;

  /// Whether the 90-second heartbeat watchdog has fired without receiving a
  /// heartbeat message. Set independently of [connectionStatus] by the MQTT
  /// client service timer. `true` implies the ESP32 may be stalled even if the
  /// TCP connection is still alive.
  final bool isUnresponsive;

  const LiveStatus({
    required this.uvLamp,
    required this.trapDoor,
    required this.zapper,
    required this.connectionStatus,
    required this.isUnresponsive,
  });

  /// Produces the initial loading state emitted by the stream before the first
  /// retained messages arrive from the EMQX broker. The UI renders a loading
  /// indicator when [connectionStatus] is empty.
  const LiveStatus.loading()
      : uvLamp = '',
        trapDoor = '',
        zapper = '',
        connectionStatus = '',
        isUnresponsive = false;

  /// Returns a copy of this [LiveStatus] with the specified fields replaced.
  /// Used by the MQTT client service to apply incremental retained-message
  /// updates to a single accumulated state object.
  LiveStatus copyWith({
    String? uvLamp,
    String? trapDoor,
    String? zapper,
    String? connectionStatus,
    bool? isUnresponsive,
  }) {
    return LiveStatus(
      uvLamp: uvLamp ?? this.uvLamp,
      trapDoor: trapDoor ?? this.trapDoor,
      zapper: zapper ?? this.zapper,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isUnresponsive: isUnresponsive ?? this.isUnresponsive,
    );
  }

  bool get isOnline => connectionStatus == 'online';
  bool get isOffline => connectionStatus == 'offline';
  bool get isLoading => connectionStatus.isEmpty;

  @override
  List<Object?> get props =>
      [uvLamp, trapDoor, zapper, connectionStatus, isUnresponsive];

  @override
  String toString() =>
      'LiveStatus(uvLamp: $uvLamp, trapDoor: $trapDoor, zapper: $zapper, '
      'connectionStatus: $connectionStatus, isUnresponsive: $isUnresponsive)';
}
