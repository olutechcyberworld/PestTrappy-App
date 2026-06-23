import 'package:go_router/go_router.dart';

import '../presentation/screens/about_screen.dart';
import '../presentation/screens/connection_history_screen.dart';
import '../presentation/screens/dashboard_screen.dart';
import '../presentation/screens/event_log_screen.dart';
import '../presentation/screens/live_status_screen.dart';
import '../presentation/screens/notification_history_screen.dart';
import '../presentation/screens/pairing_screen.dart';
import '../presentation/screens/sensor_charts_screen.dart';
import '../presentation/screens/settings_screen.dart';
import '../presentation/screens/splash_screen.dart';
import '../presentation/shell/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/pair', builder: (context, state) => const PairingScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/status',
              builder: (context, state) => const LiveStatusScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/events',
              builder: (context, state) => const EventLogScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/sensors',
              builder: (context, state) => const SensorChartsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
      routes: [
        GoRoute(
          path: 'about',
          builder: (context, state) => const AboutScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationHistoryScreen(),
    ),
    GoRoute(
      path: '/connection-history',
      builder: (context, state) => const ConnectionHistoryScreen(),
    ),
  ],
);
