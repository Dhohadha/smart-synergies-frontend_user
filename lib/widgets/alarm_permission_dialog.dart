import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

/// Checks and prompts the user to grant the USE_FULL_SCREEN_INTENT permission.
///
/// On Android 14+ this permission is required for the alarm screen to
/// appear over the lock screen. Without it, only a notification banner
/// is shown even when the phone is locked.
///
/// Call [AlarmPermissionHelper.checkAndPromptIfNeeded] from [AppRootGate]
/// once after the user is logged in.
class AlarmPermissionHelper {
  static const _platform = MethodChannel('com.smart_synergies_user.app/alarm');
  static const _askedKey = 'full_screen_intent_permission_asked';

  /// Checks the permission and shows a dialog if it's not granted.
  /// Only shows once per installation (tracked via SharedPreferences).
  static Future<void> checkAndPromptIfNeeded(BuildContext context) async {
    try {
      // Only relevant on Android 14+ (API 34)
      final bool hasPermission =
          await _platform.invokeMethod<bool>('checkFullScreenPermission') ??
              true;

      if (hasPermission) return; // All good

      final prefs = await SharedPreferences.getInstance();
      final bool alreadyAsked = prefs.getBool(_askedKey) ?? false;
      if (alreadyAsked) return; // Don't nag

      await prefs.setBool(_askedKey, true);

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _FullScreenIntentDialog(platform: _platform),
      );
    } catch (e) {
      debugPrint('[AlarmPermission] Check failed: $e');
    }
  }

  /// Force re-check (e.g. after user returns from Settings).
  /// Returns true if the permission is now granted.
  static Future<bool> isGranted() async {
    try {
      return await _platform.invokeMethod<bool>('checkFullScreenPermission') ??
          true;
    } catch (_) {
      return true;
    }
  }
}

class _FullScreenIntentDialog extends StatelessWidget {
  final MethodChannel platform;
  const _FullScreenIntentDialog({required this.platform});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.alarm_on_rounded, color: Colors.red, size: 32),
      ),
      title: Text(
        'Enable Lock-Screen Alarm',
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        textAlign: TextAlign.center,
      ),
      content: Text(
        'To show the alarm screen when your phone is locked, please allow '
        '"Display pop-up windows when locked" for Smart Synergies.\n\n'
        'Without this, you will only receive a notification banner.',
        style: GoogleFonts.outfit(
          color: Colors.white70,
          fontSize: 14,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Later',
            style: GoogleFonts.outfit(color: Colors.white38),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () async {
            Navigator.of(context).pop();
            try {
              await platform.invokeMethod('openFullScreenSettings');
            } catch (e) {
              debugPrint('[AlarmPermission] openFullScreenSettings failed: $e');
            }
          },
          child: Text(
            'Open Settings',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
