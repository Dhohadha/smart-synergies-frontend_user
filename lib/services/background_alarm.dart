import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// SharedPreferences flag key for alarm state
const String _alarmPlayingKey = 'alarm_playing';

/// Kept as a stub — audio is driven entirely from the main isolate via AlarmService.
Future<bool> initBackgroundAlarm() async {
  debugPrint('[BackgroundAlarm] init — audio handled by main isolate AlarmService');
  return true;
}

/// Sets alarm SharedPreferences flags so the app reads the correct state
/// on cold-start / resume. Audio is started by AlarmScreen.initState().
Future<bool> triggerBackgroundAlarm() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alarmPlayingKey, true);
    await prefs.setBool('flutter.alarm_playing', true);
    await prefs.setBool('isAlarmStopped', false);
    await prefs.setBool('flutter.isAlarmStopped', false);
    await prefs.setString('last_alarm_trigger', DateTime.now().toIso8601String());
    debugPrint('[BackgroundAlarm] alarm_playing flag set to true');
    return true;
  } catch (e) {
    debugPrint('[BackgroundAlarm] Failed to set prefs: $e');
    return false;
  }
}

/// Clears all alarm flags. Used when stopping an alarm.
Future<bool> stopBackgroundAlarm() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alarmPlayingKey, false);
    await prefs.setBool('flutter.alarm_playing', false);
    await prefs.setBool('isAlarmStopped', true);
    await prefs.setBool('flutter.isAlarmStopped', true);
    debugPrint('[BackgroundAlarm] alarm_playing flag cleared');
    return true;
  } catch (e) {
    debugPrint('[BackgroundAlarm] stopBackgroundAlarm error: $e');
    return false;
  }
}
