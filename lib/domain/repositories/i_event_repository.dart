import '../models/sensor_health_status.dart';
import '../models/trap_event.dart';

/// Repository contract for discrete operational events stored in
/// `pest_trap.events`, the live Supabase real-time event stream, and the
/// derived sensor health view.
///
/// This is the most operationally significant repository in the application.
/// It serves the event log screen, the kill count dashboard tile, the sensor
/// health badges on both the dashboard and status screen, and the real-time
/// event prepend mechanism in the event log.
abstract class IEventRepository {
  /// Returns the [limit] most recent [TrapEvent] rows for [deviceId], ordered
  /// by [TrapEvent.occurredAt] descending. Used to populate the initial
  /// historical batch on the event log screen.
  Future<List<TrapEvent>> getRecentEvents({
    required String deviceId,
    required int limit,
  });

  /// Supabase real-time stream of INSERT events on `pest_trap.events` for
  /// [deviceId]. Each emission is a single new [TrapEvent] as it is written
  /// by the ESP32 firmware. Used by the event log screen to prepend live
  /// events and by the provider layer to invalidate [getSensorHealthStatus]
  /// when a sensor fault event arrives.
  Stream<TrapEvent> liveEventStream(String deviceId);

  /// Returns the total count of [EventType.killConfirmed] rows for [deviceId].
  /// Corresponds to `SELECT COUNT(*) FROM pest_trap.events WHERE
  /// device_id = ? AND event_type = 'killConfirmed'`.
  ///
  /// Carried with `keepAlive` in the provider graph (Section 8) because it
  /// is shared across the dashboard and event log screens and must not be
  /// disposed on navigation.
  Future<int> getConfirmedKillCount(String deviceId);

  /// Returns the current fault state for each known sensor by inspecting
  /// the most recent `sensorError` or `sensorRecovered` event per distinct
  /// `sensor` value in `pest_trap.events`.
  ///
  /// A sensor is faulted when its most recent qualifying event is
  /// [EventType.sensorError]. It is healthy when the most recent qualifying
  /// event is [EventType.sensorRecovered] or when no qualifying event exists.
  ///
  /// This method is called reactively: the provider layer invalidates it
  /// whenever [liveEventStream] emits a [EventType.sensorError] or
  /// [EventType.sensorRecovered] event (Flutter Architecture Section 5.2).
  Future<List<SensorHealthStatus>> getSensorHealthStatus(String deviceId);
}
