import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:smart_synergies/services/background_alarm.dart';
import 'package:smart_synergies/models/notification_model.dart';
import 'package:smart_synergies/services/local_notification_service.dart';
import 'package:smart_synergies/services/alarm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_synergies/core/app_config.dart';

// --- GLOBAL NAVIGATOR KEY ---
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// --- LOCAL NOTIFICATIONS PLUGIN ---
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Initialize local notifications with Stop Alarm action button.
/// Call this once from main() before runApp.
Future<void> initLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: _onNotificationAction,
    onDidReceiveBackgroundNotificationResponse: _onNotificationActionBackground,
  );

  // 1. Loud alarm channel
  final AndroidNotificationChannel channel = AndroidNotificationChannel(
    'alarm_channel_v3', // Incremented ID to ensure updates on existing devices
    'Alarm Notifications (Loud)',
    description: 'Critical aerator alert notifications',
    importance: Importance.max,
    playSound: true,
    sound: const RawResourceAndroidNotificationSound('alarm'),
    enableVibration: true,
  );

  // 2. Silent alarm channel
  const AndroidNotificationChannel silentChannel = AndroidNotificationChannel(
    'alarm_channel_silent_v2',
    'Alarm Notifications (Silent)',
    description: 'Critical aerator alert notifications without sound',
    importance: Importance.max,
    playSound: false,
    enableVibration: false,
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  await androidPlugin?.createNotificationChannel(channel);
  await androidPlugin?.createNotificationChannel(silentChannel);
}

/// Show a local notification with a STOP ALARM action button.
Future<void> showAlarmNotification({
  required String title,
  required String body,
  bool enableSound = true,
  bool fullScreenIntent = true,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('latest_alarm_title', title);
    await prefs.setString('latest_alarm_body', body);
  } catch (_) {}

  final String channelId = enableSound
      ? 'alarm_channel_v3'
      : 'alarm_channel_silent_v2';

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    channelId,
    enableSound ? 'Alarm Notifications (Loud)' : 'Alarm Notifications (Silent)',
    channelDescription: 'Aerator alert notifications',
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: fullScreenIntent,
    category: AndroidNotificationCategory.alarm,
    ongoing: true,
    autoCancel: false,
    playSound: enableSound,
    sound: enableSound ? const RawResourceAndroidNotificationSound('alarm') : null,
    enableVibration: enableSound,
    vibrationPattern: enableSound ? Int64List.fromList([0, 1000, 1000]) : null,
    actions: <AndroidNotificationAction>[
      const AndroidNotificationAction(
        'stop_alarm',
        '🔕 STOP ALARM',
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ],
  );

  final NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    id: 888, // fixed id so we can cancel it
    title: title,
    body: body,
    notificationDetails: notificationDetails,
    payload: 'alarm',
  );
}

/// Show a normal system notification for updates and recoveries.
Future<void> showNormalNotification({
  required String title,
  required String body,
}) async {
  const AndroidNotificationChannel normalChannel = AndroidNotificationChannel(
    'normal_channel_v1',
    'General Updates',
    description: 'System and device status updates',
    importance: Importance.defaultImportance,
    playSound: true,
    enableVibration: true,
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(normalChannel);

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    normalChannel.id,
    normalChannel.name,
    channelDescription: normalChannel.description,
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    playSound: true,
    enableVibration: true,
  );

  final NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    id: DateTime.now().millisecondsSinceEpoch % 100000,
    title: title,
    body: body,
    notificationDetails: notificationDetails,
  );
}

/// Cancel the alarm notification (call when alarm is stopped)
Future<void> cancelAlarmNotification() async {
  await flutterLocalNotificationsPlugin.cancel(id: 888);
}

/// Handles notification action taps (foreground / background)
@pragma('vm:entry-point')
void _onNotificationActionBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint(
    '🛑 Background Notification Action received: ID=${response.id}, ActionID=${response.actionId}',
  );

  if (response.actionId == 'stop_alarm') {
    // Stop foreground player if any
    try {
      await AlarmService().stopAlarm();
    } catch (_) {}

    // Stop native alarm service via MethodChannel (if main isolate is alive)
    try {
      const platform = MethodChannel('com.smart_synergies_user.app/alarm');
      await platform.invokeMethod('stopAlarm');
    } catch (e) {
      debugPrint('Error stopping native alarm from background: $e');
    }

    // Also stop the Flutter-side background isolate alarm if any
    try {
      await stopBackgroundAlarm();
    } catch (_) {}

    // Update SharedPreferences flags to trigger the native SharedPreferences listener
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarm_playing', false);
    await prefs.setBool('isAlarmStopped', true);
    await cancelAlarmNotification();
  }
}

void _onNotificationAction(NotificationResponse response) async {
  debugPrint(
    '🔔 Local Notification Action received: ID=${response.id}, ActionID=${response.actionId}, Payload=${response.payload}',
  );

  if (response.actionId == 'stop_alarm') {
    debugPrint(
      '🛑 "Stop Alarm" action button pressed from foreground notification',
    );
    // Stop foreground player if any
    try {
      await AlarmService().stopAlarm();
    } catch (_) {}

    try {
      const platform = MethodChannel('com.smart_synergies_user.app/alarm');
      await platform.invokeMethod('stopAlarm');
    } catch (e) {
      debugPrint('Error stopping native alarm: $e');
    }
    try {
      await stopBackgroundAlarm();
    } catch (e) {
      debugPrint('Error stopping background alarm: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarm_playing', false);
    await prefs.setBool('isAlarmStopped', true);
    await cancelAlarmNotification();
  } else if (response.payload == 'alarm') {
    debugPrint('📲 Notification body tapped. Redirecting to Alarm Screen...');

    // Set alarm flag to ensure dialog shows up
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarm_playing', true);

    // Handle redirecting to alarm page when the notification body itself is tapped
    final Map<String, dynamic> arguments = {
      'title': 'Aerator Alert', // Fallback title
      'body': 'Tap to stop alarm.', // Fallback body
      'isFromNotification': true,
      'isForegroundTakeover': false,
    };

    // Use the global navigator key to push the route
    Future.microtask(() async {
      int retryCount = 0;
      while (navigatorKey.currentState == null && retryCount < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        retryCount++;
      }

      if (navigatorKey.currentState != null) {
        debugPrint('🚀 Navigating to /alarm from local notification tap');
        navigatorKey.currentState?.pushNamed('/alarm', arguments: arguments);
      } else {
        debugPrint('❌ ERROR: Navigator state still null after retries');
      }
    });
  }
}

class NotificationServices {
  final _firebaseMessaging = FirebaseMessaging.instance;
  static const String _tokenKey = 'fcm_token';
  // No in-app audio playback here to avoid double alarms.

  // Foreground dialog removed to avoid double notifications; rely on backend/system notification.

  // In-app sound helpers removed to avoid double alarms; backend/system drives sound.

  Future<void> initFcm() async {
    String? fcmToken;
    // await _firebaseMessaging.requestPermission();
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint("✅ Notifications permission granted");
      fcmToken = await _firebaseMessaging.getToken();
    } else {
      debugPrint("❌ Notifications permission denied");
    }

    debugPrint("------------------------------------------------------------");
    debugPrint("🔑 [FCM TOKEN LOG] ACTIVE FCM TOKEN ON DEVICE:");
    debugPrint("$fcmToken");
    debugPrint("------------------------------------------------------------");

    if (fcmToken != null) {
      await _saveTokenToPrefs(fcmToken);
    }

    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      debugPrint("------------------------------------------------------------");
      debugPrint("🔑 [FCM TOKEN LOG] REFREShed FCM TOKEN ON DEVICE:");
      debugPrint(newToken);
      debugPrint("------------------------------------------------------------");
      await _saveTokenToPrefs(newToken);
    });

    // 1. Handle Cold Start (App launched from terminated state via notification)
    RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM: App launched from terminated state via message');
      _handleNotificationClick(initialMessage, isForegroundTakeover: false);
    }

    // 2. Handle Resume (App in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM: App resumed from background via message');
      _handleNotificationClick(message, isForegroundTakeover: false);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // Foreground: trigger same background alarm path (with duplicate guard and timed stop)
      debugPrint(
        '📥 Foreground FCM received: ID=${message.messageId} | Title=${message.notification?.title}',
      );
      // Persist to local storage so it shows in Notifications screen with time/title/body
      try {
        final notification = NotificationModel.fromRemoteMessage(message);
        await LocalNotificationService.saveNotification(notification);
      } catch (e) {
        debugPrint('Failed to save foreground notification: $e');
      }
      final bool shouldTrigger = (message.data['alarm'] == '1') || 
          (message.notification != null && !(message.notification!.title ?? '').contains('Recovered'));

      try {
        final prefs = await SharedPreferences.getInstance();
        
        if (shouldTrigger) {
          await prefs.setBool('alarm_playing', true);
          debugPrint('🔔 Saved alarm_playing = true to SharedPreferences in foreground');

          final bool alertSoundEnabled =
              prefs.getBool('alert_sound_enabled') ?? true;

          if (alertSoundEnabled) {
            // Play loop sound in foreground
            await AlarmService().playAlarm();
          }
          // Always show local notification with Stop button regardless of sound setting
          await showAlarmNotification(
            title: message.notification?.title ?? message.data['title'] ?? '⚠️ Aerator Alert!',
            body: alertSoundEnabled
                ? (message.notification?.body ?? message.data['body'] ?? 'Tap to stop alarm.')
                : (message.notification?.body ?? message.data['body'] ?? 'Alert received.'),
            enableSound: alertSoundEnabled, // Respect the toggle
          );

          // IMMEDIATE TAKEOVER: If app is open/foreground, navigate to alarm page automatically
          debugPrint(
            '🚀 Foreground takeover: Navigating to Alarm Screen immediately',
          );
          _handleNotificationClick(message, isForegroundTakeover: true);
        } else {
          // Just show standard local notification for recovery/updates in foreground
          await showNormalNotification(
            title: message.notification?.title ?? message.data['title'] ?? 'System Update',
            body: message.notification?.body ?? message.data['body'] ?? 'All aerators working.',
          );
        }
      } catch (e) {
        debugPrint('Failed to trigger alarm in foreground: $e');
      }
    });
  }

  /// Unified handler for notification clicks (Cold Start & Resume)
  void _handleNotificationClick(RemoteMessage message, {bool isForegroundTakeover = false}) async {
    debugPrint('🔔 FCM Notification click handled. Data: ${message.data}');

    // Persist to local storage so it shows in Notifications screen
    try {
      final notification = NotificationModel.fromRemoteMessage(message);
      await LocalNotificationService.saveNotification(notification);
    } catch (e) {
      debugPrint('Failed to save clicked notification: $e');
    }

    // Determine if it's an alarm based on 'alarm' flag in data
    final bool isAlarm = (message.data['alarm'] == '1') || 
        (message.notification != null && !(message.notification!.title ?? '').contains('Recovered'));
    final String title =
        message.data['title'] ??
        message.notification?.title ??
        '⚠️ Aerator Alert!';
    final String body =
        message.data['body'] ??
        message.notification?.body ??
        'Tap to stop alarm.';

    if (isAlarm) {
      // Set alarm flag to ensure UI reflects active emergency state
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('alarm_playing', true);
      } catch (e) {
        debugPrint('Failed to set alarm_playing flag in click handler: $e');
      }
    }

    final String routeName = isAlarm ? '/alarm' : '/notifications';
    final Map<String, dynamic> arguments = {
      'title': title,
      'body': body,
      'isFromNotification': true,
      'isForegroundTakeover': isForegroundTakeover,
    };

    // Ensure navigator is ready.
    Future.microtask(() async {
      int retryCount = 0;
      while (navigatorKey.currentState == null && retryCount < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        retryCount++;
      }

      if (navigatorKey.currentState != null) {
        debugPrint('Navigating to $routeName with title: $title');
        navigatorKey.currentState?.pushNamed(routeName, arguments: arguments);
      } else {
        debugPrint('ERROR: Navigator state still null after retries');
      }
    });
  }

  /// _showForegroundAlert removed as per user request to open full screen alert directly.
  /// The app now navigates immediately using _handleNotificationClick.

  /// Stop native alarm service and clear playing flags
  Future<void> stopAlarmNow() async {
    try {
      await AlarmService().stopAlarm();
    } catch (_) {}
    try {
      const platform = MethodChannel('com.smart_synergies_user.app/alarm');
      await platform.invokeMethod('stopAlarm');
    } catch (_) {}
    try {
      await stopBackgroundAlarm();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarm_playing', false);
    // Also dismiss the persistent local notification with the Stop button
    await cancelAlarmNotification();
  }

  // Local persistence of notifications disabled per requirement to rely on backend notifications only.

  /// Save FCM token in SharedPreferences + Backend
  Future<void> _saveTokenToPrefs(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    debugPrint("FCM Token saved to SharedPreferences.");

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      try {
        final idToken = await firebaseUser.getIdToken();
        final response = await http.post(
          Uri.parse('${AppConfig.userBaseUrl}/fcm-token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'token': token}),
        );
        if (response.statusCode == 200) {
          debugPrint("✅ FCM Token registered with Backend for user: ${firebaseUser.email}");
        } else {
          debugPrint("❌ Failed to register FCM token: ${response.body}");
        }
      } catch (e) {
        debugPrint("❌ Failed to register FCM token in backend: $e");
      }
    }
  }

  static Future<String?> getDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Ensure Backend user document contains the latest FCM token.
  /// Call this after login or app resume.
  static Future<void> ensureTokenSynced() async {
    final token = await getDeviceToken();
    if (token == null) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      try {
        final idToken = await firebaseUser.getIdToken();
        final response = await http.post(
          Uri.parse('${AppConfig.userBaseUrl}/fcm-token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'token': token}),
        );
        if (response.statusCode == 200) {
          debugPrint("✅ FCM Token sync complete for user: ${firebaseUser.email}");
        }
      } catch (e) {
        debugPrint("❌ FCM Token sync failed: $e");
      }
    }
  }
}

// NOTE: For Android FCM custom sound to play from the system notification,
// you must place a native raw resource file at:
// android/app/src/main/res/raw/alarm.mp3
// This is separate from the Flutter asset (assets/alarm.mp3) used by the in-app/foreground service.
// Both can exist so system notification plays instantly while the foreground loop continues.

