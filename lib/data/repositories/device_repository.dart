import '../../domain/models/device_registration.dart';
import '../../domain/repositories/i_device_repository.dart';
import '../services/supabase_client_service.dart';

class DeviceRepository implements IDeviceRepository {
  const DeviceRepository({required SupabaseClientService supabase})
    : _supabase = supabase;

  final SupabaseClientService _supabase;

  @override
  Future<DeviceRegistration?> getDeviceMetadata(String deviceId) {
    return _supabase.fetchDeviceMetadata(deviceId);
  }
}
