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
  String title = 'Alert';
  String body = 'Critical condition detected';
  Timer? _statusWatcher;
  bool isForegroundTakeover = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Watch for alarm status changes (e.g. from notification STOP button)
    _statusWatcher = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkAlarmFlagAndExit();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      if (args.containsKey('title')) title = args['title'];
      if (args.containsKey('body')) body = args['body'];
      if (args.containsKey('isForegroundTakeover')) {
        isForegroundTakeover = args['isForegroundTakeover'] == true;
      }
    }
    _checkAlarmFlag();
  }

  Future<void> _checkAlarmFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isPlaying = prefs.getBool('alarm_playing') ?? false;
      if (isPlaying) {
        debugPrint('ðŸ”” Alarm is active (alarm_playing flag is TRUE)');
      }
      if (mounted) {
        setState(() {
          title = prefs.getString('latest_alarm_title') ?? title;
          body = prefs.getString('latest_alarm_body') ?? body;
        });
      }
    } catch (e) {
      debugPrint('Error checking alarm flag: $e');
    }
  }

  Future<void> _checkAlarmFlagAndExit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final bool isPlaying = prefs.getBool('alarm_playing') ?? false;
      if (!isPlaying && mounted) {
        debugPrint('ðŸ›‘ Alarm stopped externally. Closing Alarm Screen.');
        _statusWatcher?.cancel();
        
        if (isForegroundTakeover) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          }
        } else {
          const platform = MethodChannel('com.smart_synergies_user.app/alarm');
          try {
            await platform.invokeMethod('closeApp');
          } catch (e) {
            SystemNavigator.pop();
          }
        }
      }
    } catch (e) {
      debugPrint('Error in status watcher: $e');
    }
  }

  @override
  void dispose() {
    _statusWatcher?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleStopAlarm() async {
    final svc = NotificationServices();
    await svc.stopAlarmNow();
    if (mounted) {
      debugPrint('âœ… STOP pressed. Closing app.');
      _statusWatcher?.cancel();
      
      if (isForegroundTakeover) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
      } else {
        const platform = MethodChannel('com.smart_synergies_user.app/alarm');
        try {
          await platform.invokeMethod('closeApp');
        } catch (e) {
          SystemNavigator.pop();
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          }
        }
      }
    }
  }

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
              Color(0xFF8B0000), // Dark red
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
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
                builder: (context, child) {
                  return Transform.scale(
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
                  );
                },
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
              const Spacer(),
              GestureDetector(
                onTap: _handleStopAlarm,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 180 * _pulseAnimation.value,
                          height: 180 * _pulseAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withValues(alpha: 0.2 * (2.0 - _pulseAnimation.value)),
                          ),
                        );
                      },
                    ),
                    Container(
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
                  ],
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
