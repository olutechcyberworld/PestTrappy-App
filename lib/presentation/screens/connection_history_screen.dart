// lib/presentation/screens/connection_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/connection_event.dart';
import '../../providers/providers.dart';
import '../widgets/glass_card.dart';

class ConnectionHistoryScreen extends ConsumerWidget {
  const ConnectionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(connectionHistoryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Connection History')),
      body: history.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.error, size: 40),
              const SizedBox(height: 12),
              Text(
                'Could not load connection history',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.fontSecondary),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(connectionHistoryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (events) => events.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(context).padding.bottom + 32,
                ),
                itemCount: events.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _ConnectionEventTile(event: events[i]),
              ),
      ),
    );
  }
}

class _ConnectionEventTile extends StatelessWidget {
  const _ConnectionEventTile({required this.event});
  final ConnectionEvent event;

  @override
  Widget build(BuildContext context) {
    final color = event.isOnline
        ? AppTheme.statusOnline
        : AppTheme.statusOffline;

    return GlassCard(
      padding: const EdgeInsets.all(14),
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
            child: Icon(
              event.isOnline ? Icons.wifi_outlined : Icons.wifi_off_outlined,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.isOnline ? 'Device Online' : 'Device Offline',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat(
                    'EEEE d MMM yyyy  HH:mm:ss',
                  ).format(event.occurredAt.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.fontSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
            Icons.history_outlined,
            color: AppTheme.fontSecondary,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No connection events yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.fontSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Connection events are recorded each time\n'
            'the device connects or disconnects.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.fontSecondary),
          ),
        ],
      ),
    );
  }
}
