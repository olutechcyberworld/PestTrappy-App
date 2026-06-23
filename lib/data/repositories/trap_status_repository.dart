import '../../domain/models/live_status.dart';
import '../../domain/repositories/i_trap_status_repository.dart';
import '../services/mqtt_client_service.dart';

class TrapStatusRepository implements ITrapStatusRepository {
  const TrapStatusRepository({required MqttClientService mqtt}) : _mqtt = mqtt;

  final MqttClientService _mqtt;

  @override
  Stream<LiveStatus> get liveStatusStream => _mqtt.liveStatusStream;
}
