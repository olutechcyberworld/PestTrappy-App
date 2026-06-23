import '../../domain/models/sensor_health_status.dart';
import '../../domain/models/trap_event.dart';
import '../../domain/repositories/i_event_repository.dart';
import '../services/supabase_client_service.dart';

class EventRepository implements IEventRepository {
  const EventRepository({required SupabaseClientService supabase})
    : _supabase = supabase;

  final SupabaseClientService _supabase;

  @override
  Future<List<TrapEvent>> getRecentEvents({
    required String deviceId,
    required int limit,
  }) {
    return _supabase.fetchEvents(deviceId, limit: limit);
  }

  @override
  Stream<TrapEvent> liveEventStream(String deviceId) {
    return _supabase.eventsRealtimeStream(deviceId);
  }

  @override
  Future<int> getConfirmedKillCount(String deviceId) {
    return _supabase.fetchKillCount(deviceId);
  }

  @override
  Future<List<SensorHealthStatus>> getSensorHealthStatus(String deviceId) {
    return _supabase.fetchSensorHealth(deviceId);
  }
}
