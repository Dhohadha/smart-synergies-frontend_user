import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/device_provider.dart';
import '../providers/user_provider.dart';
import '../core/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class AlertsHistoryScreen extends ConsumerWidget {
  const AlertsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (userState.value == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: Text('Notifications History', 
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(isDark))),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Text('Please log in.', style: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark))),
        ),
      );
    }

    final devices = (userState.value!['assignedDevices'] as List<dynamic>? ?? [])
        .cast<String>()
        .toList();

    if (devices.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: Text('Notifications History', 
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(isDark))),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
        ),
        body: Center(
          child: Text('No devices assigned.', style: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark))),
        ),
      );
    }

    // Watch all history providers reactively
    final List<AsyncValue<List<dynamic>>> historyStates = devices.map((id) {
      return ref.watch(historyProvider(id));
    }).toList();

    // Check loading and error states across all watched devices
    final anyLoading = historyStates.any((state) => state.isLoading);
    final anyError = historyStates.any((state) => state.hasError);

    if (anyLoading) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: Text('Notifications History', 
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(isDark))),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.cyan)),
      );
    }

    if (anyError) {
      final errorState = historyStates.firstWhere((state) => state.hasError);
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: Text('Notifications History', 
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(isDark))),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
        ),
        body: Center(
          child: Text('Error loading history: ${errorState.error}', 
            style: GoogleFonts.outfit(color: AppColors.red)),
        ),
      );
    }

    // Merge and attach device label context
    final List<Map<String, dynamic>> allHistory = [];
    for (int i = 0; i < devices.length; i++) {
      final deviceId = devices[i];
      final deviceHistory = historyStates[i].value ?? [];
      
      // Resolve device friendly name
      final deviceState = ref.watch(deviceProvider(deviceId)).value;
      final displayName = deviceState?.name != null && deviceState!.name!.isNotEmpty
          ? deviceState.name!
          : 'Device $deviceId';

      for (var item in deviceHistory) {
        final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
        itemMap['deviceId'] = deviceId;
        itemMap['deviceName'] = displayName;
        allHistory.add(itemMap);
      }
    }

    if (allHistory.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: Text('Notifications History', 
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(isDark))),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
        ),
        body: Center(
          child: Text('No history found.', style: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark))),
        ),
      );
    }

    // Sort descending by timestamp
    allHistory.sort((a, b) => DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: Text('Notifications History', 
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(isDark))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: allHistory.length,
        itemBuilder: (context, index) {
          final item = allHistory[index];
          final date = DateTime.parse(item['timestamp']).toLocal();
          final isAlert = item['type'] == 'Alert';
          final deviceLabel = item['deviceName'] ?? item['deviceId'] ?? '';
          
          final historyId = item['_id'] ?? '';
          final deviceId = item['deviceId'] ?? '';
          final uniqueKey = '${item['timestamp']}_${deviceId}_$historyId';

          return Dismissible(
            key: ValueKey(uniqueKey),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.delete_sweep_rounded,
                color: AppColors.red,
                size: 28,
              ),
            ),
            onDismissed: (direction) async {
              if (deviceId.isNotEmpty && historyId.isNotEmpty) {
                final success = await deleteDeviceHistoryItem(deviceId, historyId);
                if (success) {
                  ref.invalidate(historyProvider(deviceId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Notification log deleted.', style: GoogleFonts.outfit()),
                        backgroundColor: AppColors.cyan,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  ref.invalidate(historyProvider(deviceId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete notification log.', style: GoogleFonts.outfit()),
                        backgroundColor: AppColors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              }
            },
            child: Card(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              elevation: isDark ? 0 : 2,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isAlert ? AppColors.red : AppColors.cyan).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAlert ? Icons.warning_rounded : Icons.info_rounded, 
                    color: isAlert ? AppColors.red : AppColors.cyan,
                    size: 20,
                  ),
                ),
                title: Text(item['message'] ?? 'Unknown event',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.getTextPrimary(isDark))),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '${DateFormat('dd MMM, hh:mm a').format(date)} • $deviceLabel',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.getTextMuted(isDark)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
