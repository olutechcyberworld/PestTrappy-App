import 'package:equatable/equatable.dart';

import 'event_type.dart';

/// Per-sensor fault state, derived by [IEventRepository.getSensorHealthStatus]
/// from the most recent `sensorError` or `sensorRecovered` event row for each
/// distinct `sensor` value in `pest_trap.events`.
///
/// A sensor is considered faulted when the most recent qualifying event is a
/// [EventType.sensorError]. It is considered healthy when the most recent
/// qualifying event is a [EventType.sensorRecovered], or when no qualifying
/// event exists at all (no fault has ever been recorded for this sensor).
///
/// The health badges on the dashboard and live status screen are driven by a
/// list of [SensorHealthStatus] values and are invalidated reactively when a
/// new [EventType.sensorError] or [EventType.sensorRecovered] event arrives
/// on the Supabase real-time subscription (Flutter Architecture Section 5.2).
class SensorHealthStatus extends Equatable {
  /// Sensor identifier matching the `sensor` column in `pest_trap.events`.
  /// Current valid values: `"aht21"`, `"soilMoisture"`.
  final String sensor;

  /// `true` if the most recent qualifying event for this sensor was a
  /// [EventType.sensorError]. `false` if it was [EventType.sensorRecovered]
  /// or if no qualifying event has ever been recorded.
  final bool isFaulted;

  /// Timestamp of the most recent qualifying event for this sensor. Used to
  /// show when the fault was last detected or when recovery was confirmed.
  final DateTime lastEventAt;

  const SensorHealthStatus({
    required this.sensor,
    required this.isFaulted,
    required this.lastEventAt,
  });

  /// Human-readable sensor label for display in health badges and
  /// notification bodies.
  String get displayName {
    switch (sensor) {
      case 'aht21':
        return 'Temp & Humidity (AHT21)';
      case 'soilMoisture':
        return 'Soil Moisture';
      default:
        return sensor;
    }
  }

  @override
  List<Object?> get props => [sensor, isFaulted, lastEventAt];

  @override
  String toString() =>
      'SensorHealthStatus(sensor: $sensor, isFaulted: $isFaulted, '
      'lastEventAt: $lastEventAt)';
}
