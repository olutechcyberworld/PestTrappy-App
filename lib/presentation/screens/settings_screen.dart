// lib/presentation/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/mqtt_client_service.dart';
import '../../providers/providers.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _killAlerts = true;
  bool _sensorAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _killAlerts = prefs.getBool('pref_kill_alerts') ?? true;
      _sensorAlerts = prefs.getBool('pref_sensor_alerts') ?? true;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _repairDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.glassRadius),
        ),
        title: const Text(
          'Re-pair Device',
          style: TextStyle(color: AppTheme.fontPrimary),
        ),
        content: Text(
          'This will disconnect from the current trap unit and return '
          'you to the pairing screen.',
          style: Theme.of(
            ctx,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.fontSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Re-pair'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_device_id');
    MqttClientService.instance.dispose();
    if (mounted) context.go('/pair');
  }

  @override
  Widget build(BuildContext context) {
    final deviceMeta = ref.watch(deviceMetadataProvider);
    final deviceId = ref.watch(activeDeviceIdProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).padding.bottom + 32,
        ),
        children: [
          // ----------------------------------------------------------------
          // Device section
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Device'),
          const SizedBox(height: 8),

          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _InfoTile(
                  label: 'Device Name',
                  value: deviceMeta.value?.deviceName ?? '—',
                  isLoading: deviceMeta.isLoading,
                ),
                _divider(),
                _InfoTile(
                  label: 'Device ID',
                  value: deviceId.isNotEmpty
                      ? '…${deviceId.substring(deviceId.length > 6 ? deviceId.length - 6 : 0)}'
                      : '—',
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.copy_outlined,
                      size: 16,
                      color: AppTheme.fontSecondary,
                    ),
                    tooltip: 'Copy full ID',
                    onPressed: deviceId.isNotEmpty
                        ? () {
                            Clipboard.setData(ClipboardData(text: deviceId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Device ID copied')),
                            );
                          }
                        : null,
                  ),
                ),
                _divider(),
                _InfoTile(
                  label: 'Last Seen',
                  value: deviceMeta.value?.lastSeenAt != null
                      ? _formatDateTime(deviceMeta.value!.lastSeenAt)
                      : '—',
                  isLoading: deviceMeta.isLoading,
                ),
                _divider(),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: const Icon(
                    Icons.link_off_outlined,
                    color: AppTheme.error,
                    size: 20,
                  ),
                  title: const Text(
                    'Re-pair Device',
                    style: TextStyle(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Switch to a different trap unit',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.fontSecondary,
                    ),
                  ),
                  onTap: _repairDevice,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ----------------------------------------------------------------
          // Notifications section
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Notifications'),
          const SizedBox(height: 8),

          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ToggleTile(
                  icon: Icons.bug_report_outlined,
                  iconColor: AppTheme.primary,
                  label: 'Kill Alerts',
                  subtitle: 'Notify when a pest is confirmed eliminated',
                  value: _killAlerts,
                  onChanged: (v) {
                    setState(() => _killAlerts = v);
                    _savePreference('pref_kill_alerts', v);
                  },
                ),
                _divider(),
                _ToggleTile(
                  icon: Icons.sensors_outlined,
                  iconColor: AppTheme.statusWarning,
                  label: 'Sensor Alerts',
                  subtitle: 'Notify on sensor faults and recovery',
                  value: _sensorAlerts,
                  onChanged: (v) {
                    setState(() => _sensorAlerts = v);
                    _savePreference('pref_sensor_alerts', v);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ----------------------------------------------------------------
          // About row
          // ----------------------------------------------------------------
          GlassCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: const Icon(
                Icons.info_outline,
                color: AppTheme.fontSecondary,
                size: 20,
              ),
              title: const Text('About PestTrappy'),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppTheme.fontSecondary,
              ),
              onTap: () => context.push('/settings/about'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
    height: 1,
    indent: 16,
    endIndent: 16,
    color: Color.fromRGBO(255, 255, 255, 0.08),
  );

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day} ${_month(local.month)} ${local.year}  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _month(int m) => const [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m];
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: AppTheme.fontSecondary),
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    this.isLoading = false,
    this.trailing,
  });
  final String label;
  final String value;
  final bool isLoading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppTheme.fontSecondary),
      ),
      trailing:
          trailing ??
          (isLoading
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppTheme.fontSecondary,
                  ),
                )
              : Text(value, style: Theme.of(context).textTheme.bodyMedium)),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(label),
      subtitle: Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppTheme.fontSecondary),
      ),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
