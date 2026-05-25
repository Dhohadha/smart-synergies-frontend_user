import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'services/background_alarm.dart';
import 'services/local_notification_service.dart';
import 'models/notification_model.dart';
import 'core/app_config.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  
  debugPrint("Handling a background message: ${message.messageId}");

  try {
    final notification = NotificationModel.fromRemoteMessage(message);
    await LocalNotificationService.saveNotification(notification);
  } catch (e) {
    debugPrint('Failed to save background notification: $e');
  }

  final title = message.notification?.title ?? 
                message.data['title'] ?? 'AERATOR ALERT';
  final body = message.notification?.body ?? 
               message.data['body'] ?? 'Tap to stop alarm.';

  final bool shouldTrigger = (message.data['alarm'] == '1') || 
      (message.notification != null && !(message.notification!.title ?? '').contains('Recovered'));
  
  final bool alertSoundEnabled = prefs.getBool('alert_sound_enabled') ?? true;

  try {
    await initLocalNotifications();
    
    if (shouldTrigger) {
      await flutterLocalNotificationsPlugin.cancelAll(); 
      await prefs.setBool('alarm_playing', true);
      await prefs.setBool('isAlarmStopped', false);
      // Also set flutter-namespaced keys for the native SharedPreferences listener
      await prefs.setBool('flutter.alarm_playing', true);
      await prefs.setBool('flutter.isAlarmStopped', false);
      debugPrint('🔔 Saved alarm_playing = true to SharedPreferences in background');
      
      // Show the Flutter local notification with STOP button
      await showAlarmNotification(
        title: title,
        body: body,
        enableSound: alertSoundEnabled,
        fullScreenIntent: true,
      );

    } else {
      // Normal notification for recovery/updates
      await showNormalNotification(
        title: title,
        body: body,
      );
    }
  } catch (e) {
    debugPrint('Error in background message handler: $e');
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.init();
  await Firebase.initializeApp();
  
  // Required for google_sign_in 7.0.0+
  await GoogleSignIn.instance.initialize();

  bool startWithAlarm = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    startWithAlarm = prefs.getBool('alarm_playing') ?? false;
    debugPrint('🔔 Startup check: startWithAlarm = $startWithAlarm');
  } catch (e) {
    debugPrint('Error checking alarm startup: $e');
  }
  
  // Initialize FCM and Alarms asynchronously to boot the app instantly
  try {
    await initLocalNotifications();
    await initBackgroundAlarm();
    
    // Fire-and-forget network-bound initializations to prevent blocking app startup
    NotificationServices().initFcm().catchError((e) {
      debugPrint('Error initializing FCM: $e');
    });
    NotificationServices.ensureTokenSynced().catchError((e) {
      debugPrint('Error syncing token: $e');
    });
  } catch (e) {
    debugPrint('Error initializing local notification services: $e');
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    ProviderScope(
      child: SmartSynergiesApp(startWithAlarm: startWithAlarm),
    ),
  );
}

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
      home: startWithAlarm ? const AlarmScreen() : const AppRootGate(),
      routes: {
        '/alarm': (context) => const AlarmScreen(),
      },
    );
  }
}

class AppRootGate extends ConsumerStatefulWidget {
  const AppRootGate({super.key});

  @override
  ConsumerState<AppRootGate> createState() => _AppRootGateState();
}

class _AppRootGateState extends ConsumerState<AppRootGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[Lifecycle] App resumed. Refreshing user profile quietly.');
      ref.read(userProvider.notifier).refreshProfileQuietly();

      final prefs = await SharedPreferences.getInstance();
      final isAlarmStopped = prefs.getBool('isAlarmStopped') ?? false;
      if (isAlarmStopped) {
        debugPrint('[Lifecycle] Alarm stopped flag detected on resume. Cleaning up native alarm.');
        await NotificationServices().stopAlarmNow();
        await prefs.setBool('isAlarmStopped', false);
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
            body: Center(child: CircularProgressIndicator(color: AppColors.cyan)),
          ),
          error: (e, _) {
            final errStr = e.toString().toLowerCase();
            if (errStr.contains('404') || errStr.contains('403') || errStr.contains('not found') || errStr.contains('profile not found')) {
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
