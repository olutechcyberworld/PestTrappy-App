// lib/presentation/screens/splash_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/mqtt_client_service.dart';
import '../../data/services/notification_service.dart';
import '../../providers/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 1400));

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('active_device_id') ?? '';

    if (!mounted) return;

    if (deviceId.isEmpty) {
      context.go('/pair');
      return;
    }

    ref.read(activeDeviceIdProvider.notifier).setDeviceId(deviceId);

    await NotificationService.instance.init();
    if (!mounted) return;

    unawaited(MqttClientService.instance.connect(deviceId));
    context.go('/');
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

          // Radial glow behind the logo
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color.fromRGBO(0, 200, 150, 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Logo + branding
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glass icon badge
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 255, 255, 0.08),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color.fromRGBO(255, 255, 255, 0.20),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.pest_control,
                            size: 52,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    Text(
                      'PestTrappy',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: AppTheme.fontPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Smart Agricultural Monitoring',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.fontSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),

                    const SizedBox(height: 56),

                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.primary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Brand footer — "Powered by OLUTECH CYBERWORLD"
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  Text(
                    'Powered by',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.fontSecondary.withValues(alpha: 0.55),
                      letterSpacing: 0.8,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'OLUTECH CYBERWORLD',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.fontPrimary.withValues(alpha: 0.85),
                      letterSpacing: 2.8,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'v1.0.0',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.fontSecondary.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void unawaited(Future<void> future) {}
