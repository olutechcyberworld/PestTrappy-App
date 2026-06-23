import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/connection_repository.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/event_repository.dart';
import '../data/repositories/sensor_repository.dart';
import '../data/repositories/trap_status_repository.dart';
import '../data/services/mqtt_client_service.dart';
import '../data/services/supabase_client_service.dart';
import '../domain/models/connection_event.dart';
import '../domain/models/device_registration.dart';
import '../domain/models/live_status.dart';
import '../domain/models/sensor_health_status.dart';
import '../domain/models/sensor_reading.dart';
import '../domain/models/trap_event.dart';
import '../domain/repositories/i_connection_repository.dart';
import '../domain/repositories/i_device_repository.dart';
import '../domain/repositories/i_event_repository.dart';
import '../domain/repositories/i_sensor_repository.dart';
import '../domain/repositories/i_trap_status_repository.dart';

// ---------------------------------------------------------------------------
// Service providers
// ---------------------------------------------------------------------------

final mqttClientServiceProvider = Provider<MqttClientService>(
  (ref) => MqttClientService.instance,
);

final supabaseClientServiceProvider = Provider<SupabaseClientService>(
  (ref) => SupabaseClientService.instance,
);

// ---------------------------------------------------------------------------
// Repository providers
// ---------------------------------------------------------------------------

final deviceRepositoryProvider = Provider<IDeviceRepository>((ref) {
  return DeviceRepository(supabase: ref.watch(supabaseClientServiceProvider));
});

final trapStatusRepositoryProvider = Provider<ITrapStatusRepository>((ref) {
  return TrapStatusRepository(mqtt: ref.watch(mqttClientServiceProvider));
});

final sensorRepositoryProvider = Provider<ISensorRepository>((ref) {
  return SensorRepository(supabase: ref.watch(supabaseClientServiceProvider));
});

final eventRepositoryProvider = Provider<IEventRepository>((ref) {
  return EventRepository(supabase: ref.watch(supabaseClientServiceProvider));
});

final connectionRepositoryProvider = Provider<IConnectionRepository>((ref) {
  return ConnectionRepository(
    supabase: ref.watch(supabaseClientServiceProvider),
  );
});

// ---------------------------------------------------------------------------
// Active device ID — Riverpod 3.x NotifierProvider
// ---------------------------------------------------------------------------

class ActiveDeviceIdNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setDeviceId(String id) => state = id;
}

final activeDeviceIdProvider = NotifierProvider<ActiveDeviceIdNotifier, String>(
  ActiveDeviceIdNotifier.new,
);

// ---------------------------------------------------------------------------
// Data providers
// ---------------------------------------------------------------------------

final liveStatusProvider = StreamProvider<LiveStatus>(
  (ref) => ref.watch(trapStatusRepositoryProvider).liveStatusStream,
  name: 'liveStatusProvider',
);

final deviceMetadataProvider = FutureProvider.autoDispose<DeviceRegistration?>((
  ref,
) async {
  final deviceId = ref.watch(activeDeviceIdProvider);
  if (deviceId.isEmpty) return null;
  return ref.watch(deviceRepositoryProvider).getDeviceMetadata(deviceId);
}, name: 'deviceMetadataProvider');

final recentSensorReadingsProvider =
    FutureProvider.autoDispose<List<SensorReading>>((ref) async {
      final deviceId = ref.watch(activeDeviceIdProvider);
      if (deviceId.isEmpty) return [];
      return ref
          .watch(sensorRepositoryProvider)
          .getRecentReadings(deviceId: deviceId, limit: 50);
    }, name: 'recentSensorReadingsProvider');

final latestSensorReadingProvider = FutureProvider.autoDispose<SensorReading?>((
  ref,
) async {
  final deviceId = ref.watch(activeDeviceIdProvider);
  if (deviceId.isEmpty) return null;
  return ref.watch(sensorRepositoryProvider).getLatestReading(deviceId);
}, name: 'latestSensorReadingProvider');

final recentEventsProvider = FutureProvider.autoDispose<List<TrapEvent>>((
  ref,
) async {
  final deviceId = ref.watch(activeDeviceIdProvider);
  if (deviceId.isEmpty) return [];
  return ref
      .watch(eventRepositoryProvider)
      .getRecentEvents(deviceId: deviceId, limit: 50);
}, name: 'recentEventsProvider');

final liveEventStreamProvider = StreamProvider.autoDispose<TrapEvent>((
  ref,
) async* {
  final deviceId = ref.watch(activeDeviceIdProvider);
  if (deviceId.isEmpty) return;

  await for (final event
      in ref.watch(eventRepositoryProvider).liveEventStream(deviceId)) {
    if (event.eventType.name == 'sensorError' ||
        event.eventType.name == 'sensorRecovered') {
      ref.invalidate(sensorHealthProvider);
    }
    if (event.eventType.name == 'killConfirmed') {
      ref.invalidate(killCountProvider);
    }
    yield event;
  }
}, name: 'liveEventStreamProvider');

final killCountProvider = FutureProvider<int>((ref) async {
  final deviceId = ref.watch(activeDeviceIdProvider);
  if (deviceId.isEmpty) return 0;
  return ref.watch(eventRepositoryProvider).getConfirmedKillCount(deviceId);
}, name: 'killCountProvider');

final sensorHealthProvider =
    FutureProvider.autoDispose<List<SensorHealthStatus>>((ref) async {
      final deviceId = ref.watch(activeDeviceIdProvider);
      if (deviceId.isEmpty) return [];
      return ref.watch(eventRepositoryProvider).getSensorHealthStatus(deviceId);
    }, name: 'sensorHealthProvider');

final connectionHistoryProvider =
    FutureProvider.autoDispose<List<ConnectionEvent>>((ref) async {
      final deviceId = ref.watch(activeDeviceIdProvider);
      if (deviceId.isEmpty) return [];
      return ref
          .watch(connectionRepositoryProvider)
          .getConnectionHistory(deviceId: deviceId, limit: 50);
    }, name: 'connectionHistoryProvider');
