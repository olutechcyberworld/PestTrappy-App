import '../models/connection_event.dart';

/// Repository contract for reading device connection session history from
/// `pest_trap.connection_events`.
///
/// Each row in this table is an append-only record of a single online/offline
/// transition, written by the ESP32 firmware per Firmware Contract 15 of the
/// Backend Architecture document. Unlike `pest_trap.device_state` (which holds
/// only the current connection status), this table provides the full
/// chronological history for review in the connection session history screen
/// (Flutter Architecture Section 10.10).
abstract class IConnectionRepository {
  /// Returns the [limit] most recent [ConnectionEvent] rows for [deviceId],
  /// ordered by [ConnectionEvent.occurredAt] descending.
  Future<List<ConnectionEvent>> getConnectionHistory({
    required String deviceId,
    required int limit,
  });
}
