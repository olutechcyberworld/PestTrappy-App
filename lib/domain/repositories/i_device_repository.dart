import '../models/device_registration.dart';

/// Repository contract for reading device metadata from
/// `pest_trap.device_registry`.
///
/// This interface does not participate in device pairing. The [deviceId]
/// is always provided by the caller, resolved beforehand from
/// `shared_preferences` by the application initialisation sequence
/// (Flutter Architecture Section 7, Step 3).
abstract class IDeviceRepository {
  /// Fetches the display metadata for a known [deviceId] from
  /// `pest_trap.device_registry`. Returns `null` if the device has not
  /// yet published its registration payload, which can occur briefly on
  /// first boot before the ESP32 completes its Wi-Fi and MQTT sequence.
  Future<DeviceRegistration?> getDeviceMetadata(String deviceId);
}
