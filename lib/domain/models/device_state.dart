import 'package:equatable/equatable.dart';

/// Current operational state of a single device's physical components, sourced
/// from `pest_trap.device_state`. One row exists per registered device; the
/// firmware upserts each column individually as state-change messages arrive
/// (Firmware Contract 15).
///
/// This model is structurally distinct from [LiveStatus]. [DeviceState] is a
/// Supabase-sourced snapshot representing the last known persisted state,
/// suitable as a cold-start fallback before the first MQTT retained message
/// arrives. [LiveStatus] is the live, MQTT-backed representation used by the
/// status screen throughout normal operation.
///
/// Decision note (Phase 4 implementation): [DeviceState] currently has no
/// active repository consumer. Its role as a cold-start fallback is an
/// identified future use case; the [ITrapStatusRepository] live stream
/// populates the UI directly from MQTT retained messages. This model is
/// retained for completeness and for potential use during MQTT reconnection
/// latency windows.
class DeviceState extends Equatable {
  final String deviceId;

  /// UV lamp state. Valid values: `"on"`, `"off"`.
  final String uvLamp;

  /// Trap door state. Valid values: `"open"`, `"closed"`.
  final String trapDoor;

  /// Electrocution grid state. Valid values: `"active"`, `"idle"`.
  final String zapper;

  /// Device network connection state. Valid values: `"online"`, `"offline"`.
  final String connectionStatus;

  /// UTC timestamp of the most recent upsert to this row.
  final DateTime lastUpdated;

  const DeviceState({
    required this.deviceId,
    required this.uvLamp,
    required this.trapDoor,
    required this.zapper,
    required this.connectionStatus,
    required this.lastUpdated,
  });

  /// Deserialises a `pest_trap.device_state` row as returned by the Supabase
  /// Flutter SDK.
  factory DeviceState.fromMap(Map<String, dynamic> map) {
    return DeviceState(
      deviceId: map['device_id'] as String,
      uvLamp: map['uv_lamp'] as String,
      trapDoor: map['trap_door'] as String,
      zapper: map['zapper'] as String,
      connectionStatus: map['connection_status'] as String,
      lastUpdated: DateTime.parse(map['last_updated'] as String),
    );
  }

  @override
  List<Object?> get props =>
      [deviceId, uvLamp, trapDoor, zapper, connectionStatus, lastUpdated];

  @override
  String toString() =>
      'DeviceState(deviceId: $deviceId, uvLamp: $uvLamp, '
      'trapDoor: $trapDoor, zapper: $zapper, '
      'connectionStatus: $connectionStatus)';
}
