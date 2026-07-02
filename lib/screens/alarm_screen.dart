import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_services.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String title = '⚠️ Aerator Alert!';
  String body = 'Critical condition detected. Tap STOP to acknowledge.';
  Timer? _statusWatcher;
  bool isForegroundTakeover = false;

  @override
  void initState() {
    super.initState();

    // ── Pulsing animation ────────────────────────────────────────────────
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ── Audio is now handled natively ─────────────────────────────────────────
    // SmartSynergiesApplication natively monitors the flutter.alarm_playing
    // flag in SharedPreferences and starts AlarmSoundService automatically.
    // We no longer need to manually trigger audio in Dart.

    // ── Watch for external stop (notification STOP button etc.) ───────────
    _statusWatcher = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkAlarmFlagAndExit();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() {
        if (args.containsKey('title')) title = args['title'] as String;
        if (args.containsKey('body')) body = args['body'] as String;
        if (args.containsKey('isForegroundTakeover')) {
          isForegroundTakeover = args['isForegroundTakeover'] == true;
        }
      });
    }
    // Refresh title/body from prefs in case they were set by the FCM handler
    _refreshTitleBodyFromPrefs();
  }

  Future<void> _refreshTitleBodyFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTitle = prefs.getString('latest_alarm_title');
      final savedBody = prefs.getString('latest_alarm_body');
      if (mounted && (savedTitle != null || savedBody != null)) {
        setState(() {
          if (savedTitle != null && savedTitle.isNotEmpty) title = savedTitle;
          if (savedBody != null && savedBody.isNotEmpty) body = savedBody;
        });
      }
    } catch (e) {
      debugPrint('[AlarmScreen] Error refreshing title/body: $e');
    }
  }

  // ── Periodic check: close screen when alarm is stopped externally ─────────
  Future<void> _checkAlarmFlagAndExit() async {
    try {
      const platform = MethodChannel('com.smart_synergies_user.app/alarm');
      final bool isPlaying = await platform.invokeMethod('checkAlarmStatus') ?? false;
      if (!isPlaying && mounted) {
        debugPrint('[AlarmScreen] alarm_playing=false (native) — closing screen');
        _dismiss();
      }
    } catch (e) {
      debugPrint('[AlarmScreen] Status watcher native error: $e');
    }
  }

  // ── STOP button pressed ───────────────────────────────────────────────────
  void _handleStopAlarm() {
    debugPrint('[AlarmScreen] STOP pressed');
    _statusWatcher?.cancel();
    // Do not await to ensure the UI dismisses instantly
    NotificationServices().stopAlarmNow();
    if (mounted) _dismiss();
  }

  // ── Close / navigate away ─────────────────────────────────────────────────
  void _dismiss() {
    _statusWatcher?.cancel();
    const platform = MethodChannel('com.smart_synergies_user.app/alarm');
    // Instantly drop the lock screen bypass flags to prevent app roaming!
    platform.invokeMethod('removeLockScreenFlags').catchError((_) {});

    if (isForegroundTakeover) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      }
    } else {
      // Alarm was shown as the root screen (cold start or full-screen intent)
      const platform = MethodChannel('com.smart_synergies_user.app/alarm');
      platform.invokeMethod('closeApp').catchError((_) {
        SystemNavigator.pop();
      });
    }
  }

  @override
  void dispose() {
    _statusWatcher?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF8B0000), // dark red
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 80,
                        ),
                        const SizedBox(height: 30),
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, _) => Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Text(
                              'CRITICAL ALERT',
                              style: GoogleFonts.outfit(
                                color: Colors.red.shade400,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            body,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 60),
                        GestureDetector(
                          onTap: _handleStopAlarm,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, _) => Container(
                                  width: 180 * _pulseAnimation.value,
                                  height: 180 * _pulseAnimation.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red.withValues(
                                        alpha: 0.2 * (2.0 - _pulseAnimation.value)),
                                  ),
                                ),
                              ),
                              AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, _) => Transform.scale(
                                  scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.25, // scales 1.0 to 1.05
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.red.shade600,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withValues(alpha: 0.5),
                                          blurRadius: 20,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        'STOP',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
