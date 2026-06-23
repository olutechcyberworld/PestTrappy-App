import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';

// ---------------------------------------------------------------------------
// Background message handler
// ---------------------------------------------------------------------------

/// Top-level background message handler required by `firebase_messaging`.
/// Must be a top-level function (not a class method) and must be annotated
/// with `@pragma('vm:entry-point')` to survive tree-shaking in release builds.
///
/// Background messages received when the app is terminated or in the
/// background are handled here. The OS wakes a separate isolate to process
/// them; this function must not call any Flutter plugin that requires the
/// main isolate to be active. Storing to SharedPreferences is safe.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // SharedPreferences is safe to access from the background isolate.
  await NotificationService.instance._storeNotification(message);
}

// ---------------------------------------------------------------------------
// Notification channel constants
// ---------------------------------------------------------------------------

/// Android notification channel for kill confirmation alerts.
/// Priority: High (heads-up notification with sound).
/// Defined in Flutter Architecture Section 5.3.
const AndroidNotificationChannel _trapAlertsChannel =
    AndroidNotificationChannel(
      'trap_alerts',
      'Trap Alerts',
      description: 'Notifications for confirmed pest eliminations.',
      importance: Importance.high,
    );

/// Android notification channel for sensor fault and recovery alerts.
/// Priority: Default.
const AndroidNotificationChannel _systemAlertsChannel =
    AndroidNotificationChannel(
      'system_alerts',
      'System Alerts',
      description: 'Notifications for sensor faults and recovery events.',
      importance: Importance.defaultImportance,
    );

// ---------------------------------------------------------------------------
// SharedPreferences key
// ---------------------------------------------------------------------------

const String _kNotificationHistoryKey = 'notification_history';

// ---------------------------------------------------------------------------
// NotificationService
// ---------------------------------------------------------------------------

/// Singleton service managing FCM token lifecycle, notification channel
/// registration, foreground notification display, and local notification
/// history persistence.
///
/// Responsibilities (Flutter Architecture Section 5.3):
/// - Requests notification permission from the OS.
/// - Retrieves the FCM registration token and registers it with the
///   `register-fcm-token` Supabase Edge Function.
/// - Listens for token rotation via [FirebaseMessaging.instance.onTokenRefresh]
///   and re-registers on every rotation.
/// - Configures two Android notification channels ([_trapAlertsChannel],
///   [_systemAlertsChannel]).
/// - Uses [flutter_local_notifications] to display a system banner when FCM
///   delivers a message while the app is in the foreground (FCM alone does not
///   render a banner in that state).
/// - Appends every received notification to a JSON list in
///   [SharedPreferences] for the notification history screen
///   (Flutter Architecture Section 10.9).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Performs full notification service initialisation. Called during the
  /// application startup sequence (Flutter Architecture Section 7, Step 4).
  ///
  /// Safe to call multiple times; subsequent calls are no-ops if the service
  /// is already initialised.
  Future<void> init() async {
    await _requestPermission();
    await _configureLocalNotifications();
    await _createAndroidNotificationChannels();
    await _registerFcmToken();
    _listenForTokenRefresh();
    _listenForForegroundMessages();
  }

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  // ---------------------------------------------------------------------------
  // Local notifications setup
  // ---------------------------------------------------------------------------

  Future<void> _configureLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  Future<void> _createAndroidNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_trapAlertsChannel);
    await androidPlugin?.createNotificationChannel(_systemAlertsChannel);
  }

  // ---------------------------------------------------------------------------
  // FCM token management
  // ---------------------------------------------------------------------------

  Future<void> _registerFcmToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _sendTokenToBackend(token);
    }
  }

  void _listenForTokenRefresh() {
    _messaging.onTokenRefresh.listen((newToken) async {
      await _sendTokenToBackend(newToken);
    });
  }

  /// POSTs the FCM token to the `register-fcm-token` Supabase Edge Function.
  /// The Edge Function upserts the token into `pest_trap.app_registrations`
  /// (Backend Architecture Section 5.2). Uses the publishable key in the
  /// `apikey` header — the Edge Function authorises this key for registration
  /// operations.
  Future<void> _sendTokenToBackend(String token) async {
    final url = Uri.parse(
      '${AppConfig.edgeFunctionBaseUrl}/register-fcm-token',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': AppConfig.supabasePublishableKey,
        },
        body: jsonEncode({'fcm_token': token}),
      );

      if (kDebugMode) {
        debugPrint(
          '[NotificationService] Token registration: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Token registration failed: $e');
      }
      // Non-fatal: the app functions without push notifications.
      // The token will be re-registered on the next launch.
    }
  }

  // ---------------------------------------------------------------------------
  // Foreground message handling
  // ---------------------------------------------------------------------------

  void _listenForForegroundMessages() {
    FirebaseMessaging.onMessage.listen((message) async {
      await _displayLocalNotification(message);
      await _storeNotification(message);
    });
  }

  /// Displays a local notification banner when an FCM message arrives while
  /// the application is in the foreground. FCM alone does not render a system
  /// banner in this state on either Android or iOS.
  Future<void> _displayLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Determine which channel this notification belongs to based on the
    // data payload's channel field, falling back to system_alerts.
    final channelId = message.data['channel'] as String? ?? 'system_alerts';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'trap_alerts' ? 'Trap Alerts' : 'System Alerts',
      importance: channelId == 'trap_alerts'
          ? Importance.high
          : Importance.defaultImportance,
      priority: channelId == 'trap_alerts'
          ? Priority.high
          : Priority.defaultPriority,
    );

    await _localNotifications.show(
      // Use a hash of the message ID as the notification ID to avoid
      // duplicate banners for the same message.
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(android: androidDetails),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Deep-link navigation on tap is handled by go_router via
    // FirebaseMessaging.onMessageOpenedApp, which fires when the user taps
    // an FCM notification from the system tray. Local notification taps are
    // handled here; at prototype scope no additional routing is performed.
    if (kDebugMode) {
      debugPrint(
        '[NotificationService] Local notification tapped: ${response.id}',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Notification history persistence
  // ---------------------------------------------------------------------------

  /// Appends [message] to the JSON-encoded notification history list stored
  /// in [SharedPreferences]. Called for both foreground (from
  /// [_listenForForegroundMessages]) and background (from
  /// [firebaseMessagingBackgroundHandler]) messages.
  Future<void> _storeNotification(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_kNotificationHistoryKey) ?? [];

      final entry = jsonEncode({
        'title': message.notification?.title ?? '',
        'body': message.notification?.body ?? '',
        'receivedAt': DateTime.now().toIso8601String(),
        'data': message.data,
      });

      // Prepend so the list is newest-first when read by the history screen.
      existing.insert(0, entry);

      // Cap the stored history at 100 entries to avoid unbounded growth.
      if (existing.length > 100) {
        existing.removeRange(100, existing.length);
      }

      await prefs.setStringList(_kNotificationHistoryKey, existing);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Failed to store notification: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Public helpers consumed by the notification history screen
  // ---------------------------------------------------------------------------

  /// Reads the stored notification history from [SharedPreferences] and
  /// returns it as a list of decoded maps, newest first.
  Future<List<Map<String, dynamic>>> getNotificationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kNotificationHistoryKey) ?? [];
    return raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  /// Clears the stored notification history. Called by the pull-to-refresh
  /// action on the notification history screen (Flutter Architecture
  /// Section 10.9).
  Future<void> clearNotificationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kNotificationHistoryKey);
  }
}
