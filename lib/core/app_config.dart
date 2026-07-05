import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _ipKey = 'server_ip_address';
  static const String _defaultIP = '10.34.170.35';

  static String _serverIP = _defaultIP;

  /// Get the active server IP address
  static String get serverIP => _serverIP;

  /// Get user API endpoints
  static String get userBaseUrl {
    if (_serverIP.startsWith('http://') || _serverIP.startsWith('https://')) {
      return '$_serverIP/api/users';
    }
    return 'http://$_serverIP:6565/api/users';
  }

  /// Get device API endpoints
  static String get deviceBaseUrl {
    if (_serverIP.startsWith('http://') || _serverIP.startsWith('https://')) {
      return '$_serverIP/api/devices';
    }
    return 'http://$_serverIP:6565/api/devices';
  }

  /// Get WebSocket endpoint
  static String get wsUrl {
    if (_serverIP.startsWith('https://')) {
      return _serverIP.replaceFirst('https://', 'wss://');
    } else if (_serverIP.startsWith('http://')) {
      return _serverIP.replaceFirst('http://', 'ws://');
    }
    return 'ws://$_serverIP:6565';
  }

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
