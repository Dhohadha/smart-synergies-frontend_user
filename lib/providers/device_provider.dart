import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/device_model.dart';
import '../core/app_config.dart';

// Unified WebSocket Service Provider
final websocketProvider = Provider<WebSocketService>((ref) {
  final wsService = WebSocketService(ref);
  ref.onDispose(() => wsService.dispose());
  return wsService;
});

// Device Family Provider updated to pass Ref
final deviceProvider =
    StateNotifierProvider.family<
      DeviceNotifier,
      AsyncValue<DeviceModel>,
      String
    >((ref, deviceId) {
      return DeviceNotifier(deviceId, ref);
    });

final historyProvider = FutureProvider.family<List<dynamic>, String>((
  ref,
  deviceId,
) async {
  final baseUrl = AppConfig.deviceBaseUrl;
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  final response = await http.get(
    Uri.parse('$baseUrl/$deviceId/history'),
    headers: {
      'Authorization': 'Bearer $token',
    },
  );
  if (response.statusCode == 200) {
    return json.decode(response.body) as List<dynamic>;
  } else {
    throw Exception('Failed to load history');
  }
});

Future<bool> deleteDeviceHistoryItem(String deviceId, String historyId) async {
  try {
    final baseUrl = AppConfig.deviceBaseUrl;
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/$deviceId/history/$historyId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    return response.statusCode == 200;
  } catch (e) {
    debugPrint('Error deleting history item: $e');
    return false;
  }
}

// Global, shared WebSocket Service class
class WebSocketService {
  WebSocketService(this.ref) {
    _connect();
  }

  final Ref ref;
  WebSocket? _webSocket;
  final Set<String> _subscriptions = {};
  bool _isDisposed = false;
  Timer? _reconnectTimer;

  void subscribe(String deviceId) {
    _subscriptions.add(deviceId);
    _sendSubscription(deviceId);
  }

  void unsubscribe(String deviceId) {
    _subscriptions.remove(deviceId);
  }

  void _connect() async {
    if (_isDisposed) return;
    _closeWebSocket();

    try {
      final wsUrl = AppConfig.wsUrl;
      debugPrint('[WS] Connecting to unified WebSocket at $wsUrl...');
      _webSocket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 5));
      
      if (_isDisposed) {
        _closeWebSocket();
        return;
      }

      debugPrint('[WS] Unified WebSocket connected successfully');
      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      // Resubscribe all active deviceIDs
      for (final deviceId in _subscriptions) {
        _sendSubscription(deviceId);
      }

      _webSocket!.listen(
        (message) {
          if (_isDisposed) return;
          try {
            final parsed = json.decode(message) as Map<String, dynamic>;
            debugPrint('[WS] 📥 Received message: $parsed');
            if (parsed['type'] == 'device_update') {
              final deviceId = parsed['deviceID'] as String?;
              final deviceData = parsed['data'];
              if (deviceId != null && deviceData != null) {
                final updatedDevice = DeviceModel.fromJson(deviceData);
                ref.read(deviceProvider(deviceId).notifier).updateStateFromWebSocket(updatedDevice);
              }
            }
          } catch (e) {
            debugPrint('[WS] ⚠️ Error parsing message: $e');
          }
        },
        onError: (err) {
          debugPrint('[WS] ❌ WebSocket stream error: $err');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[WS] ❌ WebSocket connection closed');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[WS] ❌ WebSocket connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _sendSubscription(String deviceId) async {
    if (_webSocket == null || _webSocket!.readyState != WebSocket.open) return;
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (_isDisposed) return;
      if (token != null) {
        _webSocket!.add(json.encode({
          'type': 'subscribe',
          'token': token,
          'deviceID': deviceId,
        }));
        debugPrint('[WS] Sent subscription request for $deviceId');
      }
    } catch (e) {
      debugPrint('[WS] Error sending subscription: $e');
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;

    debugPrint('[WS] ⏳ Scheduling WebSocket reconnect in 5 seconds...');
    _reconnectTimer = Timer(const Duration(seconds: 5), _connect);
  }

  void _closeWebSocket() {
    try {
      _webSocket?.close();
      _webSocket = null;
    } catch (e) {
      debugPrint('[WS] Error closing WebSocket: $e');
    }
  }

  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _closeWebSocket();
  }
}

class DeviceNotifier extends StateNotifier<AsyncValue<DeviceModel>> {
  DeviceNotifier(this.deviceId, this.ref) : super(const AsyncValue.loading()) {
    fetchDeviceData();
    // Register subscription with the unified WebSocket service
    ref.read(websocketProvider).subscribe(deviceId);
  }

  final String deviceId;
  final Ref ref;
  final String baseUrl = AppConfig.deviceBaseUrl;

  void updateStateFromWebSocket(DeviceModel updatedDevice) {
    state = AsyncValue.data(updatedDevice);
    debugPrint('[DEBUG] ⚡ DeviceNotifier state updated from unified WebSocket for $deviceId');
  }

  Future<void> fetchDeviceData({bool showLoading = true}) async {
    if (showLoading) {
      state = const AsyncValue.loading();
    }
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/status/$deviceId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
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
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/$deviceId/calibrate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
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
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/$deviceId/toggle-relay'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
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
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/config/$deviceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
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
