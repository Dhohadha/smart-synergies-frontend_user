import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';

class ErrorScreen extends StatefulWidget {
  final Object error;
  final VoidCallback onRefresh;

  const ErrorScreen({
    super.key,
    required this.error,
    required this.onRefresh,
  });

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorMessage = widget.error.toString();
    
    // Default fallback messages
    String friendlyTitle = 'Connection Failed';
    String friendlyMessage = 'We could not connect to the server. Please verify your network settings and try again.';
    IconData icon = Icons.wifi_off_rounded;

    // Detailed user-friendly diagnostics
    if (errorMessage.contains('SocketException') || 
        errorMessage.contains('ClientException') || 
        errorMessage.contains('No route to host') ||
        errorMessage.contains('Connection refused') ||
        errorMessage.contains('Connection timed out')) {
      friendlyTitle = 'Server Unreachable';
      friendlyMessage = 'The app cannot reach the server at the moment. Please check your internet connection or check if the backend service is running.';
      icon = Icons.cloud_off_rounded;
    } else if (errorMessage.contains('404')) {
      friendlyTitle = 'Endpoint Not Found';
      friendlyMessage = 'The requested server endpoint could not be found. Please check if your app version is up to date.';
      icon = Icons.find_in_page_outlined;
    } else if (errorMessage.contains('500') || errorMessage.contains('Server error')) {
      friendlyTitle = 'Server Maintenance';
      friendlyMessage = 'The server encountered an unexpected error. Please wait a few moments and try reloading.';
      icon = Icons.dns_outlined;
    } else if (errorMessage.contains('401') || errorMessage.contains('403')) {
      friendlyTitle = 'Session Expired';
      friendlyMessage = 'Your credentials are no longer valid. Please try logging out and logging back in.';
      icon = Icons.lock_outline_rounded;
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: Stack(
        children: [
          // Background ambient glows
          if (isDark) ...[
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.red.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cyan.withValues(alpha: 0.04),
                ),
              ),
            ),
          ] else ...[
            Positioned(
              top: -120,
              right: -120,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cyan.withValues(alpha: 0.03),
                ),
              ),
            ),
          ],
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  
                  // Pulsing animated icon container
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark 
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      border: Border.all(
                        color: AppColors.getGlassBorder(isDark),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyan.withValues(alpha: isDark ? 0.08 : 0.04),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: AppColors.cyan,
                        size: 46,
                      ),
                    ),
                  )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.06, 1.06), duration: 2500.ms, curve: Curves.easeInOutSine),
                  
                  const SizedBox(height: 32),
                  
                  // Friendly Title
                  Text(
                    friendlyTitle,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.getTextPrimary(isDark),
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutQuad),
                  
                  const SizedBox(height: 14),
                  
                  // Explanatory Message
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      friendlyMessage,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        height: 1.55,
                        fontWeight: FontWeight.w400,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 100.ms)
                  .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutQuad),
                  
                  const SizedBox(height: 36),
                  
                  // Custom retry button
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyan.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: widget.onRefresh,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: Text(
                        'Refresh Connection',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyan,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 200.ms)
                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), duration: 500.ms, curve: Curves.easeOutBack),
                  
                  const Spacer(flex: 3),
                  
                  // Collapsible details toggle
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showDetails = !_showDetails;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showDetails ? 'Hide Error Details' : 'Show Error Details',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextMuted(isDark),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showDetails ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: AppColors.getTextMuted(isDark),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  if (_showDetails) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 120),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131C2E) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.getGlassBorder(isDark),
                          width: 1.0,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          errorMessage,
                          style: GoogleFonts.firaCode(
                            fontSize: 10.5,
                            height: 1.45,
                            color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1, end: 0, duration: 250.ms),
                  ],
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
