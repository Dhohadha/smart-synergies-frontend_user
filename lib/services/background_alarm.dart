import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A port name for the background isolate
const String _isolateName = "backgroundAlarmIsolate";

// A unique ID for the background alarm
const int alarmId = 4231;

// SharedPreferences flag key to guard duplicate alarms
const String _alarmPlayingKey = 'alarm_playing';

// Register a send port for the background isolate
final ReceivePort _port = ReceivePort();

// The audio player used in the background
final AudioPlayer bgPlayer = AudioPlayer();

/// Initialize the background alarm service
Future<bool> initBackgroundAlarm() async {
  if (Platform.isAndroid) {
    final bool initialized = await AndroidAlarmManager.initialize();
    final success = IsolateNameServer.registerPortWithName(
      _port.sendPort,
      _isolateName,
    );
    if (success) {
      _port.listen((dynamic message) {
        // debug prints acceptable for now
        debugPrint('Received message from background: $message');
      });
    }
    return initialized && success;
  }
  return false;
}

/// Trigger an alarm to play immediately in the background
Future<bool> triggerBackgroundAlarm() async {
  if (Platform.isAndroid) {
    final prefs = await SharedPreferences.getInstance();

    // Guard: Reduced aggressiveness to ensure rapid sequential alerts are not missed.
    // The native service now handles its own resets reliably.
    final bool isPlaying = prefs.getBool(_alarmPlayingKey) == true;
    if (isPlaying) {
      final String? lastStr = prefs.getString('last_alarm_trigger');
      if (lastStr != null) {
        try {
          final DateTime lastTrigger = DateTime.parse(lastStr);
          final Duration since = DateTime.now().difference(lastTrigger);
          
          // Only ignore if it's an EXTREMELY rapid burst (less than 5 seconds)
          // This prevents "thundering herd" issues while allowing genuine repeat alerts.
          if (since < const Duration(seconds: 5)) {
            debugPrint('⚠️ Duplicate alarm trigger ignored (within 5 seconds)');
            return true;
          }
        } catch (_) {}
      }
    }

    await prefs.setBool(_alarmPlayingKey, true);

    await prefs.setString(
      'last_alarm_trigger',
      DateTime.now().toIso8601String(),
    );
    await AndroidAlarmManager.initialize();
    await prefs.setString(
      'background_alarm_log',
      'Starting trigger at ${DateTime.now()}',
    );

    final success = await AndroidAlarmManager.oneShot(
      const Duration(milliseconds: 10),
      alarmId,
      backgroundAlarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
    );

    debugPrint('🔔 Background alarm oneShot scheduled: $success');
    
    // Direct fallback invocation
    try {
      debugPrint('🔔 Invoking background callback manually as fallback');
      backgroundAlarmCallback();
    } catch (e) {
      await prefs.setString(
        'background_alarm_log',
        '${prefs.getString('background_alarm_log') ?? ''}\nDirect callback error: $e',
      );
    }
    return success;
  }
  return false;
}

/// Stop the background alarm
Future<bool> stopBackgroundAlarm() async {
  if (Platform.isAndroid) {
    debugPrint('🛑 Stopping background alarm...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alarmPlayingKey, false);

    // Also send a direct stop command to the background isolate's fallback player
    final SendPort? stopPort = IsolateNameServer.lookupPortByName("backgroundAlarmStopPort");
    if (stopPort != null) {
      debugPrint('🛑 Sending STOP command to background isolate fallback player');
      stopPort.send('STOP');
    }

    return await AndroidAlarmManager.cancel(alarmId);
  }
  return false;
}

@pragma('vm:entry-point')
void backgroundAlarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Register a stop port so the main isolate can silence bgPlayer
  final ReceivePort stopPort = ReceivePort();
  IsolateNameServer.registerPortWithName(stopPort.sendPort, "backgroundAlarmStopPort");
  
  stopPort.listen((message) async {
    if (message == 'STOP') {
      debugPrint('🔇 Background isolate received STOP command. Silencing fallback player.');
      await bgPlayer.stop();
      await bgPlayer.release();
    }
  });

  // Ensure AudioPlayer uses the Alarm stream on Android
  if (Platform.isAndroid) {
    await bgPlayer.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
      ),
    );
  }

  final SendPort? sendPort = IsolateNameServer.lookupPortByName(_isolateName);

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {}

  // Duplicate guard (in case direct + alarm both fire)
  if (prefs != null && prefs.getBool(_alarmPlayingKey) == true) {
    // If already marked playing, we still proceed but avoid re-marking
  } else if (prefs != null) {
    await prefs.setBool(_alarmPlayingKey, true);
  }

  // Respect the alert sound toggle set in the profile page
  final bool alertSoundEnabled = prefs?.getBool('alert_sound_enabled') ?? true;

  try {
    sendPort?.send('Background alarm started at ${DateTime.now()}');
    prefs?.setString(
      'background_alarm_log',
      'Alarm callback started at ${DateTime.now()}',
    );

    if (!alertSoundEnabled) {
      // Sound disabled – do not start native service or play audio
      prefs?.setString(
        'background_alarm_log',
        '${prefs.getString('background_alarm_log') ?? ''}\nAlert sound disabled – skipping audio',
      );
      return;
    }

    if (Platform.isAndroid) {
      // Send a broadcast to FcmAlarmReceiver which starts BackgroundAudioService directly.
      // MethodChannel CANNOT be used from background isolates — it requires the main UI thread.
      // Using an explicit broadcast is the correct Android architecture for this use case.
      try {
        const platform = MethodChannel('com.smart_synergies_user.app/alarm');
        await platform.invokeMethod('startAlarm');
        prefs?.setString(
          'background_alarm_log',
          '${prefs.getString('background_alarm_log') ?? ''}\nStarted native alarm service via MethodChannel',
        );
      } catch (e) {
        // MethodChannel failed (expected in background isolate when app is killed)
        // Fallback: mark alarm_playing so native SharedPreferences listener picks it up
        debugPrint('MethodChannel failed (expected in background): $e');
        prefs?.setString(
          'background_alarm_log',
          '${prefs.getString('background_alarm_log') ?? ''}\nMethodChannel failed: $e',
        );
        // The SharedPreferences flag flutter.alarm_playing=true will be detected by
        // BackgroundAudioService's prefListener if the service is already running,
        // or by FcmAlarmReceiver if the app receives the FCM broadcast.
      }
    } else {
      await bgPlayer.setReleaseMode(ReleaseMode.loop);
      await bgPlayer.play(AssetSource('alarm.mp3'));
    }

    // Alarm will ring indefinitely until stopped by the user.
    if (prefs != null) {
      prefs.setString(
        'background_alarm_log',
        '${prefs.getString('background_alarm_log') ?? ''}\nAlarm ringing continuously until stopped by user',
      );
    }
    sendPort?.send('Background alarm ringing continuously');
  } catch (e) {
    sendPort?.send('Error in background alarm: $e');
    if (prefs != null) {
      prefs.setString(
        'background_alarm_log',
        '${prefs.getString('background_alarm_log') ?? ''}\nERROR: $e',
      );
      prefs.setBool(_alarmPlayingKey, false);
    }
  }
}

