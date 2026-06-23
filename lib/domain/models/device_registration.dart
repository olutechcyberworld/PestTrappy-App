import 'package:equatable/equatable.dart';

/// Display-only metadata for a registered trap device, sourced from the
/// `pest_trap.device_registry` table via [IDeviceRepository].
///
/// This model has no role in the pairing flow. The [deviceId] is resolved
/// once by the pairing screen and stored in `shared_preferences`; this class
/// is only fetched afterwards, to display [deviceName] and [lastSeenAt] in
/// the dashboard and settings screens.
///
/// Corresponds to Section 3 of the Phase 4 Flutter Architecture document
/// and the `device_registry` table definition in Phase 4 Backend Section 4.2.
class DeviceRegistration extends Equatable {
  /// MAC-derived device identifier (e.g. `a4cf12abcdef`), matching
  /// `device_registry.device_id`. Twelve lowercase hexadecimal characters,
  /// no colons or separators.
  final String deviceId;

  /// Human-readable label entered by the operator during Wi-Fi provisioning
  /// via the captive portal (Firmware Contract 9).
  final String deviceName;

  /// Timestamp of the first successful registration publish from this device.
  final DateTime registeredAt;

  /// Timestamp of the most recent registration upsert, updated on every boot.
  final DateTime lastSeenAt;

  const DeviceRegistration({
    required this.deviceId,
    required this.deviceName,
    required this.registeredAt,
    required this.lastSeenAt,
  });

  /// Deserialises a `pest_trap.device_registry` row as returned by the
  /// Supabase Flutter SDK. PostgREST delivers timestamptz columns as ISO 8601
  /// strings; [DateTime.parse] handles both the UTC `Z` suffix and offset
  /// variants produced by PostgreSQL.
  factory DeviceRegistration.fromMap(Map<String, dynamic> map) {
    return DeviceRegistration(
      deviceId: map['device_id'] as String,
      deviceName: map['device_name'] as String,
      registeredAt: DateTime.parse(map['registered_at'] as String),
      lastSeenAt: DateTime.parse(map['last_seen_at'] as String),
    );
  }

  @override
  List<Object?> get props => [deviceId, deviceName, registeredAt, lastSeenAt];

  @override
  String toString() =>
      'DeviceRegistration(deviceId: $deviceId, deviceName: $deviceName, '
      'lastSeenAt: $lastSeenAt)';
}
