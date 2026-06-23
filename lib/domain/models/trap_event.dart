import 'package:equatable/equatable.dart';

import 'event_type.dart';

/// A discrete operational event published by the ESP32 firmware to
/// `pestTrapping/{deviceId}/events` and written to `pest_trap.events`.
///
/// All five event types share a single topic and table. The [eventType] field
/// discriminates between them. The [pestCount] and [sensor] fields are
/// selectively populated depending on the event type, with all other
/// combinations being null (Backend Section 2.3, events payload table).
///
/// Population rules:
/// - [killConfirmed]: [pestCount] is an integer, [sensor] is null.
/// - [sensorError] / [sensorRecovered]: [sensor] is `"aht21"` or
///   `"soilMoisture"`, [pestCount] is null.
/// - [pestDetected] / [trapTriggered]: both [pestCount] and [sensor] are null.
class TrapEvent extends Equatable {
  final String deviceId;
  final EventType eventType;

  /// Running confirmed kill count at the moment this event was produced.
  /// Populated only when [eventType] is [EventType.killConfirmed].
  final int? pestCount;

  /// Identifier of the affected sensor. One of `"aht21"` or `"soilMoisture"`.
  /// Populated only when [eventType] is [EventType.sensorError] or
  /// [EventType.sensorRecovered].
  final String? sensor;

  /// UTC timestamp of when the firmware recorded this event, corresponding to
  /// the `occurred_at` timestamptz column (Firmware Contract 16).
  final DateTime occurredAt;

  const TrapEvent({
    required this.deviceId,
    required this.eventType,
    this.pestCount,
    this.sensor,
    required this.occurredAt,
  });

  /// Deserialises a `pest_trap.events` row as returned by the Supabase Flutter
  /// SDK. The `event_type` string is parsed via [EventType.fromString], which
  /// maps unrecognised values to [EventType.unknown] rather than throwing.
  factory TrapEvent.fromMap(Map<String, dynamic> map) {
    return TrapEvent(
      deviceId: map['device_id'] as String,
      eventType: EventType.fromString(map['event_type'] as String),
      pestCount: map['pest_count'] as int?,
      sensor: map['sensor'] as String?,
      occurredAt: DateTime.parse(map['occurred_at'] as String),
    );
  }

  @override
  List<Object?> get props =>
      [deviceId, eventType, pestCount, sensor, occurredAt];

  @override
  String toString() =>
      'TrapEvent(deviceId: $deviceId, eventType: $eventType, '
      'pestCount: $pestCount, sensor: $sensor, occurredAt: $occurredAt)';
}
