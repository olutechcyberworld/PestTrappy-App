import 'package:equatable/equatable.dart';

/// One environmental sensor sample, sourced from `pest_trap.sensor_readings`.
///
/// All three measurement fields are nullable by design. The schema column
/// definition is intentionally `numeric` without `NOT NULL` (Backend Section
/// 4.2) so that a partial-read payload — where one sensor has faulted and
/// published JSON `null` for its field (Firmware Contract 3) — can be
/// inserted without discarding valid readings from functioning sensors.
///
/// The chart layer renders null data points as visual gaps, never as zero
/// (Flutter Architecture Section 10.6, error handling Section 11).
class SensorReading extends Equatable {
  final String deviceId;

  /// Degrees Celsius from the AHT21 I2C sensor. `null` indicates a sensor
  /// fault on this sample. See Firmware Contracts 3 and 4.
  final double? temperature;

  /// Relative humidity percentage from the AHT21 I2C sensor. `null` indicates
  /// a sensor fault on this sample.
  final double? humidity;

  /// Soil moisture percentage from the capacitive soil sensor. `null`
  /// indicates a sensor fault on this sample.
  final double? soilMoisture;

  /// UTC timestamp of when the firmware recorded this sample, corresponding
  /// to the `recorded_at` timestamptz column. Not to be confused with the
  /// MQTT payload's Unix integer timestamp (Firmware Contract 16).
  final DateTime recordedAt;

  const SensorReading({
    required this.deviceId,
    this.temperature,
    this.humidity,
    this.soilMoisture,
    required this.recordedAt,
  });

  /// Deserialises a `pest_trap.sensor_readings` row as returned by the
  /// Supabase Flutter SDK. Nullable numeric columns arrive as `null` in the
  /// map when no value was written; the cast handles both present and absent
  /// cases correctly.
  factory SensorReading.fromMap(Map<String, dynamic> map) {
    return SensorReading(
      deviceId: map['device_id'] as String,
      temperature: (map['temperature'] as num?)?.toDouble(),
      humidity: (map['humidity'] as num?)?.toDouble(),
      soilMoisture: (map['soil_moisture'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(map['recorded_at'] as String),
    );
  }

  /// Whether all three sensors produced valid readings in this sample.
  bool get isComplete =>
      temperature != null && humidity != null && soilMoisture != null;

  /// Whether any individual sensor produced a null reading in this sample.
  bool get hasPartialFault =>
      temperature == null || humidity == null || soilMoisture == null;

  @override
  List<Object?> get props =>
      [deviceId, temperature, humidity, soilMoisture, recordedAt];

  @override
  String toString() =>
      'SensorReading(deviceId: $deviceId, temp: $temperature, '
      'humidity: $humidity, soil: $soilMoisture, recordedAt: $recordedAt)';
}
