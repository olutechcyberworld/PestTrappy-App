import '../models/sensor_reading.dart';

/// Repository contract for reading environmental sensor history from
/// `pest_trap.sensor_readings`.
///
/// All methods operate on a pre-resolved [deviceId] that the caller supplies.
/// The Supabase query pattern is defined in Flutter Architecture Section 5.2;
/// results are ordered by `recorded_at DESC` at the database layer.
abstract class ISensorRepository {
  /// Returns the [limit] most recent sensor readings for [deviceId], ordered
  /// by [SensorReading.recordedAt] descending. Used to populate the
  /// temperature and humidity line charts on the sensor charts screen.
  ///
  /// Null fields in returned readings represent sensor faults on that sample
  /// and must be rendered as chart gaps, not interpolated or zero-substituted.
  Future<List<SensorReading>> getRecentReadings({
    required String deviceId,
    required int limit,
  });

  /// Returns the single most recent [SensorReading] for [deviceId], or `null`
  /// if no readings have been recorded yet. Used by the dashboard for the
  /// current temperature, humidity, and soil moisture summary tiles.
  Future<SensorReading?> getLatestReading(String deviceId);
}
