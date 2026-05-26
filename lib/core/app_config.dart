import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _ipKey = 'server_ip_address';
  static const String _defaultIP = '13.233.76.8';

  static String _serverIP = _defaultIP;

  /// Get the active server IP address
  static String get serverIP => _serverIP;

  /// Get user API endpoints
  static String get userBaseUrl => 'http://$_serverIP:5000/api/users';

  /// Get device API endpoints
  static String get deviceBaseUrl => 'http://$_serverIP:5000/api/devices';

  /// Get WebSocket endpoint
  static String get wsUrl => 'ws://$_serverIP:5000';

  /// Initialize and load server IP from SharedPreferences
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverIP = prefs.getString(_ipKey) ?? _defaultIP;
    } catch (_) {
      _serverIP = _defaultIP;
    }
  }

  /// Update and save the server IP
  static Future<void> saveIP(String newIP) async {
    final cleanIP = newIP.trim();
    if (cleanIP.isEmpty) return;

    _serverIP = cleanIP;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ipKey, cleanIP);
    } catch (_) {}
  }
}
