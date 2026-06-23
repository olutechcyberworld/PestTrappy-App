// lib/presentation/screens/sensor_charts_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/sensor_reading.dart';
import '../../providers/providers.dart';
import '../widgets/glass_card.dart';

class SensorChartsScreen extends ConsumerWidget {
  const SensorChartsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readings = ref.watch(recentSensorReadingsProvider);
    final latest = ref.watch(latestSensorReadingProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Sensors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(recentSensorReadingsProvider);
              ref.invalidate(latestSensorReadingProvider);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: readings.when(
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
                'Could not load sensor data',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.fontSecondary),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(recentSensorReadingsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).padding.bottom + 88,
          ),
          children: [
            // Temperature chart
            _ChartCard(
              title: 'Temperature',
              unit: '°C',
              color: const Color(0xFFFF7043),
              icon: Icons.thermostat_outlined,
              spots: _toSpots(list, (r) => r.temperature),
              latest: latest.value?.temperature,
            ),
            const SizedBox(height: 12),

            // Humidity chart
            _ChartCard(
              title: 'Humidity',
              unit: '%',
              color: const Color(0xFF42A5F5),
              icon: Icons.water_drop_outlined,
              spots: _toSpots(list, (r) => r.humidity),
              latest: latest.value?.humidity,
            ),
            const SizedBox(height: 12),

            // Soil moisture — latest value gauge only
            _SoilCard(reading: latest.value),
          ],
        ),
      ),
    );
  }

  /// Converts readings to FlSpot list. Uses x = index (reversed so newest
  /// is rightmost), y = value. Null readings become NaN entries which
  /// split the line into segments, rendering as visual gaps.
  List<FlSpot> _toSpots(
    List<SensorReading> readings,
    double? Function(SensorReading) getValue,
  ) {
    final reversed = readings.reversed.toList();
    return List.generate(reversed.length, (i) {
      final v = getValue(reversed[i]);
      return FlSpot(i.toDouble(), v ?? double.nan);
    });
  }
}

// ---------------------------------------------------------------------------
// Chart card — splits NaN spots into separate bar segments for gap rendering
// ---------------------------------------------------------------------------
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.unit,
    required this.color,
    required this.icon,
    required this.spots,
    required this.latest,
  });

  final String title;
  final String unit;
  final Color color;
  final IconData icon;
  final List<FlSpot> spots;
  final double? latest;

  /// Splits a spot list at NaN values into contiguous valid segments.
  /// Each segment is rendered as an independent LineChartBarData so the
  /// line breaks at null readings — no interpolation across sensor faults.
  List<LineChartBarData> _buildBars() {
    final segments = <List<FlSpot>>[];
    var current = <FlSpot>[];

    for (final spot in spots) {
      if (spot.y.isNaN) {
        if (current.isNotEmpty) {
          segments.add(List.of(current));
          current = [];
        }
      } else {
        current.add(spot);
      }
    }
    if (current.isNotEmpty) segments.add(current);

    return segments
        .map(
          (seg) => LineChartBarData(
            spots: seg,
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.08),
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final validSpots = spots.where((s) => !s.y.isNaN).toList();
    final hasData = validSpots.isNotEmpty;

    final minY = hasData
        ? validSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 2
        : 0.0;
    final maxY = hasData
        ? validSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 2
        : 100.0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: AppTheme.fontPrimary),
              ),
              const Spacer(),
              if (latest != null)
                Text(
                  '${latest!.toStringAsFixed(1)}$unit',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Text(
                  '—',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.statusWarning,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          if (!hasData)
            SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  'No data available',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.fontSecondary,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  lineBarsData: _buildBars(),
                  minY: minY,
                  maxY: maxY,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxY - minY) / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: const Color.fromRGBO(255, 255, 255, 0.06),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: (maxY - minY) / 4,
                        getTitlesWidget: (value, meta) => Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(
                            color: AppTheme.fontSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        interval: (spots.length / 4).ceilToDouble(),
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= spots.length) {
                            return const SizedBox.shrink();
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                ),
              ),
            ),

          if (spots.any((s) => s.y.isNaN))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.statusWarning,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Gaps indicate sensor faults',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.statusWarning,
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

// ---------------------------------------------------------------------------
// Soil moisture card — latest value radial gauge
// ---------------------------------------------------------------------------
class _SoilCard extends StatelessWidget {
  const _SoilCard({required this.reading});
  final SensorReading? reading;

  @override
  Widget build(BuildContext context) {
    final value = reading?.soilMoisture;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.grass_outlined,
                color: Color(0xFF66BB6A),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Soil Moisture',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              value == null
                  ? Text(
                      '—',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.statusWarning,
                      ),
                    )
                  : TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: value),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (context, v, _) => Text(
                        '${v.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF66BB6A),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (value ?? 0) / 100),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, progress, _) => LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: const Color.fromRGBO(255, 255, 255, 0.06),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF66BB6A),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Dry', '25%', '50%', '75%', 'Wet']
                .map(
                  (l) => Text(
                    l,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.fontSecondary,
                    ),
                  ),
                )
                .toList(),
          ),
          if (reading?.recordedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Recorded ${DateFormat('d MMM HH:mm').format(reading!.recordedAt.toLocal())}',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppTheme.fontSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
