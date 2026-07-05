import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:smart_synergies/services/local_notification_service.dart';
import 'package:smart_synergies/models/notification_model.dart';
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

  // 1. Loud alarm channel — created NATIVELY in MainActivity.kt with
  //    AudioAttributes.USAGE_ALARM so that the sound follows the phone's
  //    ALARM volume slider, not media/notification volume.
  //    Do NOT recreate it here from Dart — flutter_local_notifications
  //    doesn't expose USAGE_ALARM and would overwrite the native channel
  //    with default (notification stream) audio attributes.

  // 2. Silent alarm channel (safe to create from Dart — no sound)
  const AndroidNotificationChannel silentChannel = AndroidNotificationChannel(
    'alarm_channel_silent_v4',
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

  // Only create the silent channel from Dart; loud channel is native-only
  await androidPlugin?.createNotificationChannel(silentChannel);
}

/// Show an alarm notification.
/// - On LOCKED screen: Android fires the fullScreenIntent → launches MainActivity → AlarmScreen
/// - On UNLOCKED screen: Android shows a heads-up banner at the top with the STOP action
/// - `fullScreenIntent` is always true — Android decides how to present it based on lock state
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
      ? 'alarm_channel_v5'
      : 'alarm_channel_silent_v4';

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    channelId,
    enableSound ? 'Alarm Notifications (Loud)' : 'Alarm Notifications (Silent)',
    channelDescription: 'Aerator alert notifications',
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: fullScreenIntent,
    // PUBLIC visibility is required so Android shows the notification and
    // fires the fullScreenIntent over the lock screen
    visibility: NotificationVisibility.public,
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
        // showsUserInterface=false → action works even from lock screen
        // without requiring the user to unlock
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ],
  );

  final NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    id: 888,
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

  // Use a fixed notification ID (888) for aerator alerts so they overwrite each other 
  // and get cleared properly, rather than piling up in the system tray.
  final int notificationId = (title.contains('AERATOR ALERT') || title.contains('Aerator Alert'))
      ? 888
      : DateTime.now().millisecondsSinceEpoch % 100000;

  await flutterLocalNotificationsPlugin.show(
    id: notificationId,
    title: title,
    body: body,
    notificationDetails: notificationDetails,
  );
}

/// Cancel the alarm notification (call when alarm is stopped)
Future<void> cancelAlarmNotification() async {
  await flutterLocalNotificationsPlugin.cancel(id: 888);
}

/// Handles notification action taps when the app is NOT in foreground.
@pragma('vm:entry-point')
void _onNotificationActionBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint(
    '[NotifAction-BG] Received: ID=${response.id}, ActionID=${response.actionId}',
  );

  if (response.actionId == 'stop_alarm') {
    // Note: Audio stopping is handled natively by clearing flutter.alarm_playing

    // Clear all alarm flags so the app shows the correct state when it opens
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('alarm_playing', false);
      await prefs.setBool('flutter.alarm_playing', false);
      await prefs.setBool('isAlarmStopped', true);
      await prefs.setBool('flutter.isAlarmStopped', true);
    } catch (_) {}

    try {
      await cancelAlarmNotification();
    } catch (_) {}

    debugPrint('[NotifAction-BG] stop_alarm handled — flags cleared');
  }
}

/// Handles notification action taps when the app IS in foreground.
void _onNotificationAction(NotificationResponse response) async {
  debugPrint(
    '[NotifAction-FG] ID=${response.id}, ActionID=${response.actionId}, Payload=${response.payload}',
  );

  if (response.actionId == 'stop_alarm') {
    debugPrint('[NotifAction-FG] stop_alarm tapped');
    // Note: Audio stopping is handled natively by clearing flutter.alarm_playing

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('alarm_playing', false);
      await prefs.setBool('flutter.alarm_playing', false);
      await prefs.setBool('isAlarmStopped', true);
      await prefs.setBool('flutter.isAlarmStopped', true);
    } catch (_) {}

    try {
      await cancelAlarmNotification();
    } catch (_) {}
  } else if (response.payload == 'alarm') {
    // Notification body tapped — navigate to alarm screen
    debugPrint('[NotifAction-FG] alarm payload tapped — navigating to /alarm');

    Future.microtask(() async {
      int retryCount = 0;
      while (navigatorKey.currentState == null && retryCount < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        retryCount++;
      }

      if (navigatorKey.currentState != null) {
        // Read title/body from prefs set by the FCM handler
        final prefs = await SharedPreferences.getInstance();
        navigatorKey.currentState?.pushNamed('/alarm', arguments: {
          'title': prefs.getString('latest_alarm_title') ?? '⚠️ Aerator Alert!',
          'body': prefs.getString('latest_alarm_body') ?? 'Tap to stop alarm.',
          'isFromNotification': true,
          'isForegroundTakeover': false,
        });
      } else {
        debugPrint('[NotifAction-FG] Navigator still null after retries');
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

    // ── Foreground FCM: App is open and user is actively using it ──────────
    // In this state: go straight to the pulsing red AlarmScreen.
    // DO NOT show a notification banner — that's for background/locked states.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('[FCM-FG] Received: ID=${message.messageId} | ${message.notification?.title}');

      // Always persist to history
      try {
        final notification = NotificationModel.fromRemoteMessage(message);
        await LocalNotificationService.saveNotification(notification);
      } catch (e) {
        debugPrint('[FCM-FG] Failed to save notification: $e');
      }

      final bool shouldTrigger = (message.data['alarm'] == '1') ||
          (message.notification != null &&
              !(message.notification!.title ?? '').contains('Recovered'));

      final bool isRecovery = (message.data['alarm'] == '0') ||
          (message.notification != null &&
              (message.notification!.title ?? '').contains('Recovered'));

      final prefs = await SharedPreferences.getInstance();
      final bool globalSoundEnabled = prefs.getBool('alert_sound_enabled') ?? true;
      final List<String> mutedDevices = prefs.getStringList('muted_devices') ?? [];
      final String? deviceID = message.data['deviceID'];
      final bool alertSoundEnabled = globalSoundEnabled &&
          (deviceID == null || !mutedDevices.contains(deviceID));

      if (!shouldTrigger || !alertSoundEnabled) {
        if (isRecovery) {
          debugPrint('[FCM-FG] Recovery received — stopping active alarm');
          await stopAlarmNow();
        }
        // Recovery / update / silent — show a quiet banner
        await showNormalNotification(
          title: message.notification?.title ?? message.data['title'] as String? ?? 'System Update',
          body: message.notification?.body ?? message.data['body'] as String? ?? 'All aerators working.',
        );
        return;
      }

      // It's an alarm and the app is in the foreground ──────────────────────
      final String alarmTitle = message.notification?.title ??
          message.data['title'] as String? ??
          '⚠️ Aerator Alert!';
      final String alarmBody = message.notification?.body ??
          message.data['body'] as String? ??
          'Tap to stop alarm.';


      // Write flags first so AlarmScreen.initState() reads them correctly
      await prefs.setBool('alarm_playing', true);
      await prefs.setBool('flutter.alarm_playing', true);
      await prefs.setBool('isAlarmStopped', false);
      await prefs.setBool('flutter.isAlarmStopped', false);
      await prefs.setString('latest_alarm_title', alarmTitle);
      await prefs.setString('latest_alarm_body', alarmBody);
      debugPrint('[FCM-FG] alarm_playing=true, navigating to /alarm');

      // ── Audio is handled natively ──────────────────────────────────────────
      // SmartSynergiesApplication natively monitors the flutter.alarm_playing
      // flag and starts AlarmSoundService automatically. We don't need Dart audio.

      // Navigate to the pulsing red AlarmScreen — the screen IS the alarm
      _navigateToAlarm(
        title: alarmTitle,
        body: alarmBody,
        isForegroundTakeover: true,
      );
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

    final prefs = await SharedPreferences.getInstance();
    final bool globalSoundEnabled = prefs.getBool('alert_sound_enabled') ?? true;
    final List<String> mutedDevices = prefs.getStringList('muted_devices') ?? [];
    final String? deviceID = message.data['deviceID'];
    final bool alertSoundEnabled = globalSoundEnabled &&
        (deviceID == null || !mutedDevices.contains(deviceID));

    if (isAlarm && alertSoundEnabled) {
      // Set alarm flag to ensure UI reflects active emergency state
      try {
        await prefs.setBool('alarm_playing', true);
      } catch (e) {
        debugPrint('Failed to set alarm_playing flag in click handler: $e');
      }
    }

    final String routeName = (isAlarm && alertSoundEnabled) ? '/alarm' : '/notifications';
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

  /// Navigate to the alarm screen using the global navigator key.
  /// Retries up to 10 times (2 seconds total) while the navigator is initialising.
  void _navigateToAlarm({
    required String title,
    required String body,
    bool isForegroundTakeover = false,
  }) {
    Future.microtask(() async {
      int retries = 0;
      while (navigatorKey.currentState == null && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        retries++;
      }
      if (navigatorKey.currentState != null) {
        debugPrint('[Nav] Pushing /alarm (isForegroundTakeover=$isForegroundTakeover)');
        navigatorKey.currentState?.pushNamed('/alarm', arguments: {
          'title': title,
          'body': body,
          'isForegroundTakeover': isForegroundTakeover,
        });
      } else {
        debugPrint('[Nav] Navigator still null after retries — cannot show AlarmScreen');
      }
    });
  }

  /// Stop all alarm components and clear all state flags.
  Future<void> stopAlarmNow() async {
    // 1. (Obsolete) Dart-side audio loop is now handled natively
    // We no longer call AlarmService() to avoid deadlocks with audioplayers.

    // 2. Dismiss persistent notification (if showing)
    try {
      await cancelAlarmNotification();
    } catch (_) {}

    // 3. Clear all SharedPreferences alarm flags
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('alarm_playing', false);
      await prefs.setBool('flutter.alarm_playing', false);
      await prefs.setBool('isAlarmStopped', true);
      await prefs.setBool('flutter.isAlarmStopped', true);
    } catch (_) {}

    debugPrint('[NotificationServices] stopAlarmNow complete');
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

