import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_config.dart';

final serverStatusProvider = StateNotifierProvider<ServerStatusNotifier, bool>((ref) {
  return ServerStatusNotifier();
});

class ServerStatusNotifier extends StateNotifier<bool> {
  ServerStatusNotifier() : super(false) {
    _initWebSocket();
  }

  WebSocket? _webSocket;
  Timer? _reconnectTimer;
  bool _isDisposed = false;

  void _initWebSocket() async {
    if (_isDisposed) return;
    _closeWebSocket();

    try {
      final wsUrl = AppConfig.wsUrl;
      _webSocket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 5));
      
      if (_isDisposed) {
        _closeWebSocket();
        return;
      }

      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      _webSocket!.listen(
        (message) {
          if (_isDisposed) return;
          try {
            final parsed = json.decode(message) as Map<String, dynamic>;
            if (parsed['type'] == 'server_issue_warning') {
              final isIssue = parsed['status'] == true;
              if (state != isIssue) {
                state = isIssue;
              }
            }
          } catch (e) {
            // ignore
          }
        },
        onError: (err) {
          _scheduleReconnect();
        },
        onDone: () {
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _initWebSocket();
    });
  }

  void _closeWebSocket() {
    try {
      _webSocket?.close();
      _webSocket = null;
    } catch (e) {}
  }

  @override
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _closeWebSocket();
    super.dispose();
  }
}
