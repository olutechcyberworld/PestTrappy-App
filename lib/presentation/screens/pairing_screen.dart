// lib/presentation/screens/pairing_screen.dart
// import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../widgets/glass_card.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen>
    with SingleTickerProviderStateMixin {
  final _manualController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _scannerActive = true;
  bool _manualMode = false;
  String? _scanError;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  static final _deviceIdRegex = RegExp(r'^[0-9a-f]{12}$');

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _manualController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  bool _isValid(String value) => _deviceIdRegex.hasMatch(value.toLowerCase());

  Future<void> _saveAndProceed(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_device_id', deviceId.toLowerCase());
    if (mounted) context.go('/splash');
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_scannerActive) return;
    final raw = capture.barcodes.firstOrNull?.rawValue ?? '';
    final candidate = raw.toLowerCase().trim();
    if (_isValid(candidate)) {
      setState(() => _scannerActive = false);
      _saveAndProceed(candidate);
    } else {
      setState(
        () =>
            _scanError = 'Invalid QR code — expected a 12-character device ID.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
          ),

          // Top glow accent
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color.fromRGBO(0, 200, 150, 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    // Header
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(0, 200, 150, 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color.fromRGBO(0, 200, 150, 0.30),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.pest_control,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PestTrappy',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: AppTheme.fontPrimary),
                            ),
                            Text(
                              'Device Pairing',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppTheme.primary),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    Text(
                      'Connect your trap',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: AppTheme.fontPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan the QR code on your trap unit or enter the '
                      'device ID printed on the label.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.fontSecondary,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Mode toggle pills
                    GlassCard(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _ModeTab(
                            label: 'Scan QR',
                            icon: Icons.qr_code_scanner,
                            selected: !_manualMode,
                            onTap: () => setState(() {
                              _manualMode = false;
                              _scannerActive = true;
                              _scanError = null;
                            }),
                          ),
                          _ModeTab(
                            label: 'Enter ID',
                            icon: Icons.keyboard_alt_outlined,
                            selected: _manualMode,
                            onTap: () => setState(() => _manualMode = true),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // QR scanner panel
                    if (!_manualMode) ...[
                      GlassCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            // Scanner viewport
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(15),
                              ),
                              child: SizedBox(
                                height: 300,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    MobileScanner(onDetect: _onDetect),
                                    // Corner frame overlay
                                    const _ScannerOverlay(),
                                  ],
                                ),
                              ),
                            ),
                            // Status row
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    _scanError == null
                                        ? Icons.info_outline
                                        : Icons.warning_amber_rounded,
                                    size: 16,
                                    color: _scanError == null
                                        ? AppTheme.fontSecondary
                                        : AppTheme.statusWarning,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _scanError ??
                                          'Point camera at the QR code on '
                                              'your trap unit.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: _scanError == null
                                                ? AppTheme.fontSecondary
                                                : AppTheme.statusWarning,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Manual entry panel
                    if (_manualMode) ...[
                      GlassCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Device ID',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: AppTheme.fontSecondary),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _manualController,
                                style: const TextStyle(
                                  color: AppTheme.fontPrimary,
                                  fontFamily: 'monospace',
                                  fontSize: 16,
                                  letterSpacing: 1.5,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'e.g. a4cf12abcdef',
                                  counterText: '',
                                  prefixIcon: Icon(
                                    Icons.memory_outlined,
                                    color: AppTheme.fontSecondary,
                                  ),
                                ),
                                autocorrect: false,
                                maxLength: 12,
                                textInputAction: TextInputAction.done,
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  if (v == null || !_isValid(v.toLowerCase())) {
                                    return 'Enter the 12-character hex ID '
                                        'from the label on your unit.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed:
                                    _isValid(
                                      _manualController.text.toLowerCase(),
                                    )
                                    ? () {
                                        if (_formKey.currentState?.validate() ??
                                            false) {
                                          _saveAndProceed(
                                            _manualController.text,
                                          );
                                        }
                                      }
                                    : null,
                                icon: const Icon(Icons.link_rounded),
                                label: const Text('Connect Device'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Help note
                    GlassCard(
                      fillOpacity: 0.04,
                      borderOpacity: 0.10,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline,
                            color: AppTheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'If setting up for the first time, power on '
                              'the trap unit and complete the Wi-Fi setup '
                              'via the PestTrap-Setup network before pairing.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.fontSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mode toggle tab
// ---------------------------------------------------------------------------

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color.fromRGBO(0, 200, 150, 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(
                    color: const Color.fromRGBO(0, 200, 150, 0.35),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppTheme.primary : AppTheme.fontSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppTheme.primary : AppTheme.fontSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scanner corner overlay
// ---------------------------------------------------------------------------

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CornerPainter());
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const length = 28.0;
    const margin = 40.0;

    // Top-left
    canvas.drawLine(
      Offset(margin, margin + length),
      Offset(margin, margin),
      paint,
    );
    canvas.drawLine(
      Offset(margin, margin),
      Offset(margin + length, margin),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(size.width - margin - length, margin),
      Offset(size.width - margin, margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin, margin + length),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(margin, size.height - margin - length),
      Offset(margin, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin + length, size.height - margin),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - margin - length, size.height - margin),
      Offset(size.width - margin, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin - length),
      Offset(size.width - margin, size.height - margin),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
