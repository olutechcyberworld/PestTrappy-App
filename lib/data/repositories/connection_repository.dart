import '../../domain/models/connection_event.dart';
import '../../domain/repositories/i_connection_repository.dart';
import '../services/supabase_client_service.dart';

class ConnectionRepository implements IConnectionRepository {
  const ConnectionRepository({required SupabaseClientService supabase})
    : _supabase = supabase;

  final SupabaseClientService _supabase;

  @override
  Future<List<ConnectionEvent>> getConnectionHistory({
    required String deviceId,
    required int limit,
  }) {
    return _supabase.fetchConnectionEvents(deviceId, limit: limit);
  }
}
