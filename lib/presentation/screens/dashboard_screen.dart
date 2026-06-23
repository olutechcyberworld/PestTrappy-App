// lib/presentation/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/event_type.dart';
import '../../domain/models/live_status.dart';
import '../../domain/models/sensor_health_status.dart';
import '../../domain/models/sensor_reading.dart';
import '../../domain/models/trap_event.dart';
import '../../providers/providers.dart';
import '../widgets/glass_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveStatus = ref.watch(liveStatusProvider);
    final deviceMeta = ref.watch(deviceMetadataProvider);
    final killCount = ref.watch(killCountProvider);
    final latestSensor = ref.watch(latestSensorReadingProvider);
    final sensorHealth = ref.watch(sensorHealthProvider);
    final recentEvents = ref.watch(recentEventsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        onRefresh: () async {
          ref.invalidate(deviceMetadataProvider);
          ref.invalidate(killCountProvider);
          ref.invalidate(latestSensorReadingProvider);
          ref.invalidate(sensorHealthProvider);
          ref.invalidate(recentEventsProvider);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).padding.bottom + 88,
          ),
          children: [
            // ----------------------------------------------------------------
            // Device header card
            // ----------------------------------------------------------------
            _DeviceHeaderCard(deviceMeta: deviceMeta, liveStatus: liveStatus),

            const SizedBox(height: 12),

            // ----------------------------------------------------------------
            // Kill count card
            // ----------------------------------------------------------------
            killCount.when(
              data: (count) => _KillCountCard(count: count),
              loading: () => const _SkeletonCard(height: 96),
              error: (e, _) => _ErrorCard(
                message: 'Could not load pest count.',
                onRetry: () => ref.invalidate(killCountProvider),
              ),
            ),

            const SizedBox(height: 12),

            // ----------------------------------------------------------------
            // Sensor readings row
            // ----------------------------------------------------------------
            latestSensor.when(
              data: (reading) => _SensorRow(reading: reading),
              loading: () => const _SkeletonCard(height: 130),
              error: (e, _) => _ErrorCard(
                message: 'Could not load sensor readings.',
                onRetry: () => ref.invalidate(latestSensorReadingProvider),
              ),
            ),

            const SizedBox(height: 12),

            // ----------------------------------------------------------------
            // Sensor health badges
            // ----------------------------------------------------------------
            sensorHealth.when(
              data: (health) => _SensorHealthCard(statuses: health),
              loading: () => const _SkeletonCard(height: 64),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 12),

            // ----------------------------------------------------------------
            // Most recent event
            // ----------------------------------------------------------------
            recentEvents.when(
              data: (events) => events.isEmpty
                  ? const SizedBox.shrink()
                  : _RecentEventCard(event: events.first),
              loading: () => const _SkeletonCard(height: 80),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Device header card
// ---------------------------------------------------------------------------

class _DeviceHeaderCard extends StatelessWidget {
  const _DeviceHeaderCard({required this.deviceMeta, required this.liveStatus});

  final AsyncValue<dynamic> deviceMeta;
  final AsyncValue<LiveStatus> liveStatus;

  @override
  Widget build(BuildContext context) {
    final status = liveStatus.value ?? const LiveStatus.loading();

    return GlassCard(
      child: Row(
        children: [
          // Status indicator dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusColor(status),
              boxShadow: [
                BoxShadow(
                  color: _statusColor(status).withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                deviceMeta.when(
                  data: (meta) => Text(
                    meta?.deviceName ?? 'Pest Trap Unit',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  loading: () => _shimmer(context, width: 140, height: 16),
                  error: (_, _) => Text(
                    'Pest Trap Unit',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _statusLabel(status),
                    key: ValueKey(_statusLabel(status)),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _statusColor(status),
                    ),
                  ),
                ),
              ],
            ),
          ),
          deviceMeta.when(
            data: (meta) => meta?.lastSeenAt != null
                ? Text(
                    'Last seen ${_relativeTime(meta!.lastSeenAt)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.fontSecondary,
                    ),
                  )
                : const SizedBox.shrink(),
            loading: () => _shimmer(context, width: 70, height: 10),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Color _statusColor(LiveStatus s) {
    if (s.isLoading) return AppTheme.fontSecondary;
    if (s.isUnresponsive) return AppTheme.statusWarning;
    if (s.isOffline) return AppTheme.statusOffline;
    return AppTheme.statusOnline;
  }

  String _statusLabel(LiveStatus s) {
    if (s.isLoading) return 'Connecting…';
    if (s.isUnresponsive) return 'Unresponsive';
    if (s.isOffline) return 'Offline';
    return 'Online';
  }
}

// ---------------------------------------------------------------------------
// Kill count card — GENERIC_CARD with counter tween
// ---------------------------------------------------------------------------

class _KillCountCard extends StatelessWidget {
  const _KillCountCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(0, 200, 150, 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color.fromRGBO(0, 200, 150, 0.25),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.bug_report_outlined,
              color: AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Eliminated',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 2),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: count.toDouble()),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  builder: (context, value, _) => Text(
                    value.toInt().toString(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'pests',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppTheme.fontSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sensor readings row — TEMP_CARD · HUMIDITY_CARD · SOIL_CARD
// ---------------------------------------------------------------------------

class _SensorRow extends StatelessWidget {
  const _SensorRow({required this.reading});

  final SensorReading? reading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SensorTile(
            icon: Icons.thermostat_outlined,
            label: 'Temp',
            value: reading?.temperature,
            unit: '°C',
            color: const Color(0xFFFF7043),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SensorTile(
            icon: Icons.water_drop_outlined,
            label: 'Humidity',
            value: reading?.humidity,
            unit: '%',
            color: const Color(0xFF42A5F5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SensorTile(
            icon: Icons.grass_outlined,
            label: 'Soil',
            value: reading?.soilMoisture,
            unit: '%',
            color: const Color(0xFF66BB6A),
          ),
        ),
      ],
    );
  }
}

class _SensorTile extends StatelessWidget {
  const _SensorTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final double? value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          value == null
              ? Text(
                  '—',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.statusWarning,
                  ),
                )
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  builder: (context, v, _) => RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: v.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        TextSpan(
                          text: unit,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sensor health badges
// ---------------------------------------------------------------------------

class _SensorHealthCard extends StatelessWidget {
  const _SensorHealthCard({required this.statuses});

  final List<SensorHealthStatus> statuses;

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppTheme.statusHealthy,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'All sensors healthy',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppTheme.statusHealthy),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: statuses.map((s) => _HealthBadge(status: s)).toList(),
      ),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.status});

  final SensorHealthStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.isFaulted
        ? AppTheme.statusFault
        : AppTheme.statusHealthy;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.isFaulted
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            status.displayName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Most recent event card
// ---------------------------------------------------------------------------

class _RecentEventCard extends StatelessWidget {
  const _RecentEventCard({required this.event});

  final TrapEvent event;

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event.eventType);

    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.30)),
            ),
            child: Icon(_eventIcon(event.eventType), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last Event',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.fontSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    event.eventType.displayLabel,
                    key: ValueKey(event.eventType),
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _relativeTime(event.occurredAt),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppTheme.fontSecondary),
          ),
        ],
      ),
    );
  }

  Color _eventColor(EventType type) {
    switch (type) {
      case EventType.killConfirmed:
        return AppTheme.primary;
      case EventType.pestDetected:
        return const Color(0xFFFFB347);
      case EventType.trapTriggered:
        return const Color(0xFF42A5F5);
      case EventType.sensorError:
        return AppTheme.error;
      case EventType.sensorRecovered:
        return AppTheme.statusHealthy;
      case EventType.unknown:
        return AppTheme.fontSecondary;
    }
  }

  IconData _eventIcon(EventType type) {
    switch (type) {
      case EventType.killConfirmed:
        return Icons.check_circle_outline;
      case EventType.pestDetected:
        return Icons.sensors;
      case EventType.trapTriggered:
        return Icons.door_front_door_outlined;
      case EventType.sensorError:
        return Icons.warning_amber_rounded;
      case EventType.sensorRecovered:
        return Icons.health_and_safety_outlined;
      case EventType.unknown:
        return Icons.help_outline;
    }
  }
}

// ---------------------------------------------------------------------------
// Shared skeleton and error helpers
// ---------------------------------------------------------------------------

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: SizedBox(height: height),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.fontSecondary),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

Widget _shimmer(
  BuildContext context, {
  required double width,
  required double height,
}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color.fromRGBO(255, 255, 255, 0.06),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return DateFormat('d MMM').format(dt);
}
