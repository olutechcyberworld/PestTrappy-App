// lib/presentation/screens/live_status_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/live_status.dart';
import '../../providers/providers.dart';
import '../widgets/glass_card.dart';

class LiveStatusScreen extends ConsumerWidget {
  const LiveStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveStatus = ref.watch(liveStatusProvider);
    final sensorHealth = ref.watch(sensorHealthProvider);

    final status = liveStatus.value ?? const LiveStatus.loading();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Live Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).padding.bottom + 88,
        ),
        children: [
          // Connection state banner
          _ConnectionBanner(status: status),
          const SizedBox(height: 12),

          // Component states grid
          Text(
            'Components',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppTheme.fontSecondary),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _ComponentCard(
                  label: 'UV Lamp',
                  icon: Icons.light_mode_outlined,
                  value: status.uvLamp,
                  onLabel: 'on',
                  activeColor: const Color(0xFFFFD54F),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ComponentCard(
                  label: 'Trap Door',
                  icon: Icons.door_front_door_outlined,
                  value: status.trapDoor,
                  onLabel: 'open',
                  activeColor: const Color(0xFF42A5F5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ComponentCard(
            label: 'Zapper',
            icon: Icons.bolt_outlined,
            value: status.zapper,
            onLabel: 'active',
            activeColor: AppTheme.primary,
            wide: true,
          ),

          const SizedBox(height: 20),

          // Sensor health
          Text(
            'Sensor Health',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppTheme.fontSecondary),
          ),
          const SizedBox(height: 8),

          sensorHealth.when(
            data: (list) => list.isEmpty
                ? GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
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
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppTheme.statusHealthy),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: list
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    s.isFaulted
                                        ? Icons.warning_amber_rounded
                                        : Icons.check_circle_outline,
                                    color: s.isFaulted
                                        ? AppTheme.statusFault
                                        : AppTheme.statusHealthy,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      s.displayName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                  ),
                                  Text(
                                    s.isFaulted ? 'Fault' : 'Healthy',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: s.isFaulted
                                              ? AppTheme.statusFault
                                              : AppTheme.statusHealthy,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
            loading: () => const SizedBox(height: 48),
            error: (_, _) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.push('/connection-history'),
            icon: const Icon(Icons.history, size: 16),
            label: const Text('View Connection History'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.status});
  final LiveStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final IconData icon;

    if (status.isLoading) {
      color = AppTheme.fontSecondary;
      label = 'Connecting…';
      icon = Icons.wifi_find_outlined;
    } else if (status.isUnresponsive) {
      color = AppTheme.statusWarning;
      label = 'Unresponsive';
      icon = Icons.wifi_off_outlined;
    } else if (status.isOffline) {
      color = AppTheme.statusOffline;
      label = 'Offline';
      icon = Icons.wifi_off_outlined;
    } else {
      color = AppTheme.statusOnline;
      label = 'Online';
      icon = Icons.wifi_outlined;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.glassRadius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.onLabel,
    required this.activeColor,
    this.wide = false,
  });

  final String label;
  final IconData icon;
  final String value;
  final String onLabel;
  final Color activeColor;
  final bool wide;

  bool get _isActive => value == onLabel;
  bool get _isLoading => value.isEmpty;

  @override
  Widget build(BuildContext context) {
    final color = _isLoading
        ? AppTheme.fontSecondary
        : _isActive
        ? activeColor
        : AppTheme.fontSecondary;

    return GlassCard(
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.30)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _isLoading ? '—' : value.toUpperCase(),
                    key: ValueKey(value),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (wide) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: _isActive
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
