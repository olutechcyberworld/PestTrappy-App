import '../../domain/models/sensor_reading.dart';
import '../../domain/repositories/i_sensor_repository.dart';
import '../services/supabase_client_service.dart';

class SensorRepository implements ISensorRepository {
  const SensorRepository({required SupabaseClientService supabase})
    : _supabase = supabase;

  final SupabaseClientService _supabase;

  @override
  Future<List<SensorReading>> getRecentReadings({
    required String deviceId,
    required int limit,
  }) {
    return _supabase.fetchSensorReadings(deviceId, limit: limit);
  }

  @override
  Future<SensorReading?> getLatestReading(String deviceId) {
    return _supabase.fetchLatestSensorReading(deviceId);
  }
}
