import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/connection_event.dart';
import '../../domain/models/device_registration.dart';
import '../../domain/models/event_type.dart';
import '../../domain/models/sensor_health_status.dart';
import '../../domain/models/sensor_reading.dart';
import '../../domain/models/trap_event.dart';

/// Singleton service wrapping the Supabase Flutter SDK for all database
/// interactions against the `pest_trap` PostgreSQL schema.
///
/// All tables for this project reside in the `pest_trap` schema rather than
/// the default `public` schema (Backend Architecture Section 4.1). The SDK
/// applies the required `Accept-Profile: pest_trap` header automatically when
/// the client is constructed with `.schema('pest_trap')`.
///
/// This service is read-only from the application perspective. All writes to
/// `pest_trap` tables are performed exclusively by the ESP32 firmware via the
/// Supabase REST API using the secret key (Firmware Contracts 13–16). The
/// Flutter application uses only the publishable key, which carries SELECT-only
/// permissions under the RLS policies defined in Backend Architecture Section
/// 4.4.
///
/// The Supabase client is initialised once during the application startup
/// sequence (Flutter Architecture Section 7, Step 2) via
/// `Supabase.initialize()` in `main.dart`. This service accesses the
/// already-initialised client via `Supabase.instance.client`; it does not
/// call `initialize()` itself.
class SupabaseClientService {
  SupabaseClientService._();
  static final SupabaseClientService instance = SupabaseClientService._();

  /// Supabase client scoped to the `pest_trap` schema. All REST queries
  /// issued through this reference automatically carry the
  /// `Accept-Profile: pest_trap` header required by PostgREST for non-public
  /// schemas (Backend Architecture Section 4.1).
  SupabaseQuerySchema get _db => Supabase.instance.client.schema('pest_trap');

  /// Unscoped client reference, used only for Realtime channel operations.
  /// Realtime subscriptions require the base client, not the schema-scoped
  /// wrapper, because the schema is specified separately in the channel
  /// configuration via [PostgresChangeFilter].
  SupabaseClient get _base => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Device registry
  // ---------------------------------------------------------------------------

  /// Fetches display metadata for [deviceId] from `pest_trap.device_registry`.
  /// Returns `null` if the device has not yet published its registration
  /// payload (possible briefly on first boot).
  Future<DeviceRegistration?> fetchDeviceMetadata(String deviceId) async {
    final response = await _db
        .from('device_registry')
        .select()
        .eq('device_id', deviceId)
        .maybeSingle();

    if (response == null) return null;
    return DeviceRegistration.fromMap(response);
  }

  // ---------------------------------------------------------------------------
  // Sensor readings
  // ---------------------------------------------------------------------------

  /// Returns the [limit] most recent sensor readings for [deviceId] from
  /// `pest_trap.sensor_readings`, ordered by `recorded_at` descending.
  ///
  /// Null fields in the returned rows represent sensor faults on that sample
  /// (Firmware Contract 3). The caller must render these as chart gaps, not
  /// as zero values.
  Future<List<SensorReading>> fetchSensorReadings(
    String deviceId, {
    required int limit,
  }) async {
    final response = await _db
        .from('sensor_readings')
        .select()
        .eq('device_id', deviceId)
        .order('recorded_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((row) => SensorReading.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Returns the single most recent [SensorReading] for [deviceId], or `null`
  /// if no readings have been recorded yet.
  Future<SensorReading?> fetchLatestSensorReading(String deviceId) async {
    final response = await _db
        .from('sensor_readings')
        .select()
        .eq('device_id', deviceId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return SensorReading.fromMap(response);
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  /// Returns the [limit] most recent [TrapEvent] rows for [deviceId] from
  /// `pest_trap.events`, ordered by `occurred_at` descending.
  Future<List<TrapEvent>> fetchEvents(
    String deviceId, {
    required int limit,
  }) async {
    final response = await _db
        .from('events')
        .select()
        .eq('device_id', deviceId)
        .order('occurred_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((row) => TrapEvent.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Returns the total count of [EventType.killConfirmed] rows for [deviceId].
  Future<int> fetchKillCount(String deviceId) async {
    final response = await _db
        .from('events')
        .select()
        .eq('device_id', deviceId)
        .eq('event_type', EventType.killConfirmed.toWireString())
        .count(CountOption.exact);

    return response.count;
  }

  /// Returns the current fault state for each known sensor by querying the
  /// most recent `sensorError` or `sensorRecovered` event per sensor.
  ///
  /// PostgREST does not natively expose `DISTINCT ON`, so this method fetches
  /// the relevant event rows ordered by `occurred_at` descending and processes
  /// them in Dart, taking only the first (most recent) row per distinct sensor
  /// value. This is correct at prototype scale; the sensor set is two entries
  /// (`aht21` and `soilMoisture`) and the result set is always small.
  Future<List<SensorHealthStatus>> fetchSensorHealth(String deviceId) async {
    final response = await _db
        .from('events')
        .select()
        .eq('device_id', deviceId)
        .inFilter('event_type', [
          EventType.sensorError.toWireString(),
          EventType.sensorRecovered.toWireString(),
        ])
        .not('sensor', 'is', null)
        .order('occurred_at', ascending: false)
        .limit(50);

    final rows = (response as List)
        .map((row) => TrapEvent.fromMap(row as Map<String, dynamic>))
        .toList();

    // Group by sensor, taking the first (most recent) row for each.
    final Map<String, TrapEvent> latestBySensor = {};
    for (final event in rows) {
      final sensor = event.sensor;
      if (sensor != null && !latestBySensor.containsKey(sensor)) {
        latestBySensor[sensor] = event;
      }
    }

    return latestBySensor.entries.map((entry) {
      return SensorHealthStatus(
        sensor: entry.key,
        isFaulted: entry.value.eventType == EventType.sensorError,
        lastEventAt: entry.value.occurredAt,
      );
    }).toList();
  }

  /// Supabase Realtime stream of INSERT events on `pest_trap.events` for
  /// [deviceId]. Each emission is a single new [TrapEvent] as it is written
  /// by the ESP32 firmware. Used by the event log screen to prepend live
  /// events without polling (Flutter Architecture Section 5.2).
  ///
  /// The caller is responsible for cancelling the returned stream subscription
  /// when the consumer is disposed. Cancellation removes the Realtime channel
  /// from the Supabase client, releasing the WebSocket subscription.
  Stream<TrapEvent> eventsRealtimeStream(String deviceId) {
    final controller = StreamController<TrapEvent>.broadcast();

    final channel = _base
        .channel('pest_trap_events_$deviceId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'pest_trap',
          table: 'events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'device_id',
            value: deviceId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              try {
                controller.add(TrapEvent.fromMap(record));
              } catch (_) {
                // Malformed record from an unexpected firmware payload shape.
                // Swallowed here; the event log will catch up on next manual
                // refresh rather than crashing the stream.
              }
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      _base.removeChannel(channel);
    };

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // Connection events
  // ---------------------------------------------------------------------------

  /// Returns the [limit] most recent [ConnectionEvent] rows for [deviceId]
  /// from `pest_trap.connection_events`, ordered by `occurred_at` descending.
  Future<List<ConnectionEvent>> fetchConnectionEvents(
    String deviceId, {
    required int limit,
  }) async {
    final response = await _db
        .from('connection_events')
        .select()
        .eq('device_id', deviceId)
        .order('occurred_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((row) => ConnectionEvent.fromMap(row as Map<String, dynamic>))
        .toList();
  }
}
