import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/access_revoked_screen.dart';
import 'screens/not_registered_screen.dart';
import 'screens/alarm_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/theme_provider.dart';
import 'core/app_theme.dart';
import 'core/app_colors.dart';
import 'services/notification_services.dart';
import 'services/local_notification_service.dart';
import 'models/notification_model.dart';
import 'core/app_config.dart';
import 'widgets/alarm_permission_dialog.dart';

// ─── Background FCM handler ────────────────────────────────────────────────
// This runs in a background Dart isolate (separate from main).
// IMPORTANT: Do NOT call AlarmService() here — it is a singleton bound to the
// main isolate.  Audio will be started by AlarmScreen.initState() when
// MainActivity opens as a result of the full-screen intent notification.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();

  debugPrint('[FCM-BG] Handling background message: ${message.messageId}');

  // Persist notification for history screen
  try {
    final notification = NotificationModel.fromRemoteMessage(message);
    await LocalNotificationService.saveNotification(notification);
  } catch (e) {
    debugPrint('[FCM-BG] Failed to save notification: $e');
  }

  final title = message.notification?.title ??
      message.data['title'] as String? ??
      'AERATOR ALERT';
  final body = message.notification?.body ??
      message.data['body'] as String? ??
      'Tap to stop alarm.';

  final bool shouldTrigger = (message.data['alarm'] == '1') ||
      (message.notification != null &&
          !(message.notification!.title ?? '').contains('Recovered'));

  final bool alertSoundEnabled = prefs.getBool('alert_sound_enabled') ?? true;
  final List<String> mutedDevices = prefs.getStringList('muted_devices') ?? [];
  final String? deviceID = message.data['deviceID'];
  final bool soundEnabled = alertSoundEnabled &&
      (deviceID == null || !mutedDevices.contains(deviceID));

  try {
    await initLocalNotifications();

    if (shouldTrigger && soundEnabled) {
      // ── Set alarm flags so app reads state correctly on cold start ──
      await prefs.setBool('alarm_playing', true);
      await prefs.setBool('flutter.alarm_playing', true);
      await prefs.setBool('isAlarmStopped', false);
      await prefs.setBool('flutter.isAlarmStopped', false);
      await prefs.setString('latest_alarm_title', title);
      await prefs.setString('latest_alarm_body', body);
      debugPrint('[FCM-BG] alarm_playing=true saved to SharedPreferences');

      // The native SmartSynergiesApplication listens to flutter.alarm_playing
      // and starts AlarmSoundService, which provides the full-screen intent
      // notification AND loops the audio perfectly.
      debugPrint('[FCM-BG] Native AlarmSoundService will handle audio and notification.');
    } else {
      await showNormalNotification(title: title, body: body);
    }
  } catch (e) {
    debugPrint('[FCM-BG] Error in background handler: $e');
  }
}

// ─── Entry point ───────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.init();
  await Firebase.initializeApp();

  // Required for google_sign_in 7.0.0+
  await GoogleSignIn.instance.initialize();

  // ── Check for pending alarm from a background/cold-start scenario ───
  bool startWithAlarm = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    startWithAlarm = prefs.getBool('alarm_playing') ?? false;
    debugPrint('[main] Startup alarm check: startWithAlarm=$startWithAlarm');
  } catch (e) {
    debugPrint('[main] Error reading alarm startup state: $e');
  }

  // ── Init notification channels + FCM ────────────────────────────────
  try {
    await initLocalNotifications();

    // Fire-and-forget: non-blocking network calls
    NotificationServices().initFcm().catchError((e) {
      debugPrint('[main] Error initialising FCM: $e');
    });
    NotificationServices.ensureTokenSynced().catchError((e) {
      debugPrint('[main] Error syncing token: $e');
    });
  } catch (e) {
    debugPrint('[main] Error initialising local notifications: $e');
  }

  // Register background handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    ProviderScope(
      child: SmartSynergiesApp(startWithAlarm: startWithAlarm),
    ),
  );
}

// ─── App ───────────────────────────────────────────────────────────────────
class SmartSynergiesApp extends ConsumerWidget {
  final bool startWithAlarm;
  const SmartSynergiesApp({super.key, required this.startWithAlarm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Synergies',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      navigatorKey: navigatorKey,
      // If alarm was active before this launch, go straight to AlarmScreen
      home: startWithAlarm ? const AlarmScreen() : const AppRootGate(),
      routes: {
        '/alarm': (context) => const AlarmScreen(),
      },
    );
  }
}

// ─── Root gate ─────────────────────────────────────────────────────────────
class AppRootGate extends ConsumerStatefulWidget {
  const AppRootGate({super.key});

  @override
  ConsumerState<AppRootGate> createState() => _AppRootGateState();
}

class _AppRootGateState extends ConsumerState<AppRootGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ── 1. Check USE_FULL_SCREEN_INTENT permission (Android 14+) ────
      // This is required for the alarm screen to appear over the lock screen.
      // Show a one-time prompt if not yet granted.
      if (mounted) {
        await AlarmPermissionHelper.checkAndPromptIfNeeded(context);
      }

      // ── 2. Redirect to AlarmScreen if an alarm is already active ────
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final isAlarmPlaying = prefs.getBool('alarm_playing') ?? false;
        if (isAlarmPlaying && mounted) {
          debugPrint('[RootGate] Active alarm on startup — redirecting to AlarmScreen');
          navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/alarm', (route) => false);
        }
      } catch (e) {
        debugPrint('[RootGate] Startup alarm check error: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[Lifecycle] App resumed.');
      ref.read(userProvider.notifier).refreshProfileQuietly();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();

        // ── Handle externally-stopped alarm ──────────────────────────
        final isAlarmStopped = prefs.getBool('isAlarmStopped') ?? false;
        if (isAlarmStopped) {
          debugPrint('[Lifecycle] isAlarmStopped=true — cleaning up');
          await NotificationServices().stopAlarmNow();
          await prefs.setBool('isAlarmStopped', false);
          await prefs.setBool('flutter.isAlarmStopped', false);
        }

        // ── Handle active alarm on resume ─────────────────────────────
        // AlarmService().playAlarm() is NOT called here — the AlarmScreen
        // itself calls playAlarm() in initState(). Just navigate to it.
        final isAlarmPlaying = prefs.getBool('alarm_playing') ?? false;
        if (isAlarmPlaying && navigatorKey.currentState != null) {
          debugPrint('[Lifecycle] alarm_playing=true on resume — redirecting');

          bool isAlreadyOnAlarm = false;
          navigatorKey.currentState?.popUntil((route) {
            if (route.settings.name == '/alarm') isAlreadyOnAlarm = true;
            return true;
          });

          if (!isAlreadyOnAlarm) {
            navigatorKey.currentState?.pushNamed('/alarm', arguments: {
              'title': prefs.getString('latest_alarm_title') ?? '⚠️ Aerator Alert!',
              'body': prefs.getString('latest_alarm_body') ?? 'Tap to stop alarm.',
              'isForegroundTakeover': true,
            });
          }
        }
      } catch (e) {
        debugPrint('[Lifecycle] Error on resume: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    return authState.when(
      data: (user) {
        if (user == null) return const LoginScreen();

        final userProfileAsync = ref.watch(userProvider);
        return userProfileAsync.when(
          data: (profile) {
            if (profile != null && profile['accessRevoked'] == true) {
              return AccessRevokedScreen(revokedBy: profile['revokedBy']);
            }
            return const MainScreen();
          },
          loading: () => const Scaffold(
            body:
                Center(child: CircularProgressIndicator(color: AppColors.cyan)),
          ),
          error: (e, _) {
            final errStr = e.toString().toLowerCase();
            if (errStr.contains('404') ||
                errStr.contains('403') ||
                errStr.contains('not found') ||
                errStr.contains('profile not found')) {
              return const NotRegisteredScreen();
            }
            return const MainScreen();
          },
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.cyan)),
      ),
      error: (e, _) => const LoginScreen(),
    );
  }
}
