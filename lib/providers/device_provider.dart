import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/device_model.dart';
import '../core/app_config.dart';

final deviceProvider =
    StateNotifierProvider.family<
      DeviceNotifier,
      AsyncValue<DeviceModel>,
      String
    >((ref, deviceId) {
      return DeviceNotifier(deviceId);
    });

final historyProvider = FutureProvider.family<List<dynamic>, String>((
  ref,
  deviceId,
) async {
  final baseUrl = AppConfig.deviceBaseUrl;
  final response = await http.get(Uri.parse('$baseUrl/$deviceId/history'));
  if (response.statusCode == 200) {
    return json.decode(response.body) as List<dynamic>;
  } else {
    throw Exception('Failed to load history');
  }
});

Future<bool> deleteDeviceHistoryItem(String deviceId, String historyId) async {
  try {
    final baseUrl = AppConfig.deviceBaseUrl;
    final response = await http.delete(Uri.parse('$baseUrl/$deviceId/history/$historyId'));
    return response.statusCode == 200;
  } catch (e) {
    debugPrint('Error deleting history item: $e');
    return false;
  }
}

class DeviceNotifier extends StateNotifier<AsyncValue<DeviceModel>> {
  DeviceNotifier(this.deviceId) : super(const AsyncValue.loading()) {
    fetchDeviceData();
    _initWebSocket();
  }

  final String deviceId;
  final String baseUrl = AppConfig.deviceBaseUrl;

  WebSocket? _webSocket;
  Timer? _reconnectTimer;
  bool _isDisposed = false;

  void _initWebSocket() async {
    if (_isDisposed) return;

    _closeWebSocket();

    try {
      final wsUrl = AppConfig.wsUrl;
      debugPrint('[DEBUG] ðŸ”Œ Connecting to WebSocket at $wsUrl for device $deviceId...');
      _webSocket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 5));
      
      if (_isDisposed) {
        _closeWebSocket();
        return;
      }

      debugPrint('[DEBUG] âœ… WebSocket connected successfully for device $deviceId');
      
      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      _webSocket!.listen(
        (message) {
          if (_isDisposed) return;
          try {
            final parsed = json.decode(message) as Map<String, dynamic>;
            debugPrint('[DEBUG] ðŸ“© Received WebSocket message: $parsed');
            
            if (parsed['type'] == 'device_update' && parsed['deviceID'] == deviceId) {
              final deviceData = parsed['data'];
              if (deviceData != null) {
                final updatedDevice = DeviceModel.fromJson(deviceData);
                state = AsyncValue.data(updatedDevice);
                debugPrint('[DEBUG] âš¡ Successfully updated state for $deviceId from live WebSocket!');
              }
            }
          } catch (e) {
            debugPrint('[DEBUG] âš ï¸ Error parsing WebSocket message: $e');
          }
        },
        onError: (err) {
          debugPrint('[DEBUG] âŒ WebSocket stream error for device $deviceId: $err');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[DEBUG] âŒ WebSocket connection closed for device $deviceId');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[DEBUG] âŒ WebSocket connection failed for device $deviceId: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;

    debugPrint('[DEBUG] â³ Scheduling WebSocket reconnect in 5 seconds for device $deviceId...');
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _initWebSocket();
    });
  }

  void _closeWebSocket() {
    try {
      _webSocket?.close();
      _webSocket = null;
    } catch (e) {
      debugPrint('[DEBUG] Error closing WebSocket: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _closeWebSocket();
    super.dispose();
  }



  Future<void> fetchDeviceData({bool showLoading = true}) async {
    if (showLoading) {
      state = const AsyncValue.loading();
    }
    try {
      final response = await http.get(Uri.parse('$baseUrl/status/$deviceId'));
      if (response.statusCode == 200) {
        state = AsyncValue.data(
          DeviceModel.fromJson(json.decode(response.body)),
        );
      } else {
        if (showLoading) {
          state = AsyncValue.error(
            'Failed to load device data',
            StackTrace.current,
          );
        }
      }
    } catch (e, st) {
      if (showLoading) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<String?> calibrate({
    required int runningAerators,
    required int totalAerators,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$deviceId/calibrate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'runningAerators': runningAerators,
          'totalAerators': totalAerators,
        }),
      );
      if (response.statusCode == 200) {
        await fetchDeviceData(showLoading: false);
        return null; // Success
      } else {
        try {
          final data = json.decode(response.body);
          return data['message'] ?? 'Calibration failed';
        } catch (_) {
          return 'Calibration failed with status code ${response.statusCode}';
        }
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<bool> toggleRelay({bool? r1, bool? r2}) async {
    // Capture previous state for rollback on failure
    final previousState = state;
    
    // Optimistically update the UI immediately
    state.whenData((device) {
      final updatedRelays = List<RelayStatus>.from(device.relays);
      if (r1 != null && updatedRelays.isNotEmpty) {
        updatedRelays[0] = RelayStatus(name: updatedRelays[0].name, status: r1);
      }
      if (r2 != null && updatedRelays.length > 1) {
        updatedRelays[1] = RelayStatus(name: updatedRelays[1].name, status: r2);
      }
      state = AsyncValue.data(device.copyWith(relays: updatedRelays));
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$deviceId/toggle-relay'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'relay1toggle': r1,
          'relay2toggle': r2,
        }),
      );
      debugPrint('[RELAY] Toggle response for $deviceId: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        return true;
      } else {
        // Revert on failure
        state = previousState;
        return false;
      }
    } catch (e) {
      debugPrint('[RELAY] Toggle error for $deviceId: $e');
      // Revert on error
      state = previousState;
      return false;
    }
  }

  Future<bool> updateDeviceName(String newName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/config/$deviceId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': newName}),
      );
      if (response.statusCode == 200) {
        state.whenData((device) {
          state = AsyncValue.data(device.copyWith(name: newName));
        });
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating device name: $e');
      return false;
    }
  }
}
