// lib/presentation/screens/event_log_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/event_type.dart';
import '../../domain/models/trap_event.dart';
import '../../providers/providers.dart';
import '../widgets/glass_card.dart';

class EventLogScreen extends ConsumerStatefulWidget {
  const EventLogScreen({super.key});
  @override
  ConsumerState<EventLogScreen> createState() => _EventLogScreenState();
}

class _EventLogScreenState extends ConsumerState<EventLogScreen> {
  // Local list that merges historical batch with live-prepended events
  final List<TrapEvent> _events = [];
  bool _initialised = false;

  @override
  Widget build(BuildContext context) {
    // Seed from historical batch once
    ref.listen(recentEventsProvider, (_, next) {
      next.whenData((list) {
        if (!_initialised) {
          setState(() {
            _events
              ..clear()
              ..addAll(list);
            _initialised = true;
          });
        }
      });
    });

    // Prepend live events
    ref.listen(liveEventStreamProvider, (_, next) {
      next.whenData((event) {
        setState(() => _events.insert(0, event));
      });
    });

    final isLoading = ref.watch(recentEventsProvider).isLoading;
    final killCount = ref.watch(killCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Event Log'),
        actions: [
          if (killCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                label: Text(
                  '$killCount kills',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: const Color.fromRGBO(0, 200, 150, 0.12),
                side: const BorderSide(
                  color: Color.fromRGBO(0, 200, 150, 0.35),
                ),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
      body: isLoading && _events.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : RefreshIndicator(
              color: AppTheme.primary,
              backgroundColor: AppTheme.surface,
              onRefresh: () async {
                setState(() {
                  _events.clear();
                  _initialised = false;
                });
                ref.invalidate(recentEventsProvider);
              },
              child: _events.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        MediaQuery.of(context).padding.bottom + 88,
                      ),
                      itemCount: _events.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) =>
                          _EventTile(event: _events[i]),
                    ),
            ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final TrapEvent event;

  @override
  Widget build(BuildContext context) {
    final color = _color(event.eventType);
    final icon = _icon(event.eventType);

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.30)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.eventType.displayLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(event),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            DateFormat('d MMM\nHH:mm').format(event.occurredAt.toLocal()),
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppTheme.fontSecondary),
          ),
        ],
      ),
    );
  }

  String _subtitle(TrapEvent e) {
    if (e.eventType == EventType.killConfirmed && e.pestCount != null) {
      return 'Running total: ${e.pestCount} pest(s)';
    }
    if ((e.eventType == EventType.sensorError ||
            e.eventType == EventType.sensorRecovered) &&
        e.sensor != null) {
      return 'Sensor: ${e.sensor}';
    }
    return '';
  }

  Color _color(EventType t) {
    switch (t) {
      case EventType.killConfirmed:
        return AppTheme.primary;
      case EventType.pestDetected:
        return const Color(0xFFFFB347);
      case EventType.trapTriggered:
        return const Color(0xFF42A5F5);
      case EventType.sensorError:
        return AppTheme.statusFault;
      case EventType.sensorRecovered:
        return AppTheme.statusHealthy;
      case EventType.unknown:
        return AppTheme.fontSecondary;
    }
  }

  IconData _icon(EventType t) {
    switch (t) {
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.list_alt_outlined,
            color: AppTheme.fontSecondary,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No events yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.fontSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Events will appear here as the trap operates.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.fontSecondary),
          ),
        ],
      ),
    );
  }
}
