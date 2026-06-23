// lib/presentation/screens/about_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../widgets/glass_card.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App identity
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(0, 200, 150, 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color.fromRGBO(0, 200, 150, 0.30),
                    ),
                  ),
                  child: const Icon(
                    Icons.pest_control,
                    color: AppTheme.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'PestTrappy',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'v1.0.0',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.fontSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'OLUTECH CYBERWORLD',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.primary,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About this system',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'PestTrappy is an IoT-based automated pest trapping and '
                  'monitoring system designed for smart agricultural '
                  'environments. The system combines an ESP32-based hardware '
                  'unit with a cloud-connected mobile application to provide '
                  'real-time pest detection, trap actuation, environmental '
                  'sensing, and operational event logging.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Technology Stack',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                ...[
                  (
                    'EMQX Cloud Serverless',
                    'MQTT message broker',
                    Icons.cloud_outlined,
                  ),
                  (
                    'Supabase',
                    'PostgreSQL database and Edge Functions',
                    Icons.storage_outlined,
                  ),
                  (
                    'Firebase Cloud Messaging',
                    'Push notification delivery',
                    Icons.notifications_outlined,
                  ),
                  (
                    'Flutter',
                    'Cross-platform mobile application',
                    Icons.phone_android_outlined,
                  ),
                  ('ESP32', 'Embedded device firmware', Icons.memory_outlined),
                ].map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(item.$3, color: AppTheme.primary, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              Text(
                                item.$2,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppTheme.fontSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          GlassCard(
            fillOpacity: 0.04,
            borderOpacity: 0.10,
            child: Text(
              'HND Final-Year Project — Automated Pest Trapping System '
              'for Smart Agricultural Monitoring.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.fontSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
