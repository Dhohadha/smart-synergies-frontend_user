import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../providers/device_provider.dart';
import '../alerts_history_screen.dart';
import '../../models/device_model.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/error_screen.dart';
import '../../providers/server_status_provider.dart';

import '../../widgets/alarm_permission_dialog.dart';
class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});
  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surface : AppColors.backgroundLight,
      body: Stack(
        children: [
          // Background ambient glows
          if (isDark) ...[
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cyan.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blue.withValues(alpha: 0.08),
                ),
              ),
            ),
          ] else ...[
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cyan.withValues(alpha: 0.04),
                ),
              ),
            ),
          ],
          SafeArea(
            child: userState.when(
              data: (user) {
                if (user == null) {
                  return const Center(child: Text('Please log in.'));
                }

                final assignedDevices =
                    (user['assignedDevices'] as List<dynamic>?)?.cast<String>() ??
                    [];

                final pendingInvitations =
                    ((user['pendingInvitations'] as List<dynamic>?) ?? [])
                        .where((i) => (i['status'] ?? 'pending') != 'declined')
                        .toList();

                return Column(
                  children: [
                    _header(context, isDark),
                    
                    // Server Warning Banner
                    Consumer(
                      builder: (context, ref, child) {
                        final hasServerIssue = ref.watch(serverStatusProvider);
                        if (!hasServerIssue) return const SizedBox.shrink();
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_rounded, color: AppColors.red, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Server Issue Detected: All devices are offline.',
                                  style: GoogleFonts.outfit(
                                    color: AppColors.red,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn().slideY(begin: -0.2, end: 0);
                      },
                    ),

                    // Pending invitations banner
                    if (pendingInvitations.isNotEmpty)
                      _InvitationBanner(
                        invitations: pendingInvitations
                            .map((e) => Map<String, dynamic>.from(e))
                            .toList(),
                        isDark: isDark,
                      ),
                    Expanded(
                      child: assignedDevices.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                              child: Center(
                                child: Text(
                                  'No devices assigned to you yet.',
                                  style: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark)),
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                Expanded(
                                  child: PageView.builder(
                                    controller: _pageController,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: assignedDevices.length,
                                    itemBuilder: (context, index) {
                                      final deviceId = assignedDevices[index];
                                      return _buildDevicePage(context, deviceId, isDark);
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SmoothPageIndicator(
                                  controller: _pageController,
                                  count: assignedDevices.length,
                                  effect: ExpandingDotsEffect(
                                    dotHeight: 6,
                                    dotWidth: 6,
                                    activeDotColor: AppColors.cyan,
                                    dotColor: isDark
                                        ? AppColors.textMuted
                                        : AppColors.textMutedLight,
                                    expansionFactor: 3,
                                    spacing: 8,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => ErrorScreen(
                error: e,
                onRefresh: () => ref.read(userProvider.notifier).fetchUserProfile(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicePage(BuildContext context, String deviceId, bool isDark) {
    return RefreshIndicator(
      color: AppColors.cyan,
      onRefresh: () async {
        try {
          // Refresh user profile quietly and device data on swipe down
          await ref.read(userProvider.notifier).refreshProfileQuietly();
          await ref.read(deviceProvider(deviceId).notifier).fetchDeviceData(showLoading: false);
          ref.invalidate(historyProvider(deviceId));
        } catch (e) {
          debugPrint('Error refreshing device $deviceId: $e');
        }
      },
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: _buildDeviceCard(context, deviceId, isDark),
        ),
      ),
    );
  }

  void _showEditDeviceNameDialog(BuildContext context, DeviceModel device, String? currentCustomName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: currentCustomName ?? device.name ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.getSurface(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: AppColors.getGlassBorder(isDark),
                  width: 1.0,
                ),
              ),
              title: Text(
                'Device Friendly Name',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set a custom name for this device (visible on your dashboard).',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.getTextMuted(isDark),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    style: GoogleFonts.outfit(
                      color: AppColors.getTextPrimary(isDark),
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Pond 1 Aerator',
                      hintStyle: GoogleFonts.outfit(
                        color: isDark ? Colors.white30 : Colors.black38,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.getGlassBorder(isDark),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.cyan,
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.getBackground(isDark),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(
                      color: AppColors.getTextMuted(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newName = controller.text.trim();
                          setDialogState(() => isSaving = true);
                          final success = await ref
                              .read(userProvider.notifier)
                              .updateDeviceCustomName(device.deviceId, newName);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Device name updated successfully'
                                      : 'Failed to update device name',
                                  style: GoogleFonts.outfit(),
                                ),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyan,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _header(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Synergies',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.getTextPrimary(isDark),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .scale(
                       duration: 1200.ms,
                       begin: const Offset(0.75, 0.75),
                       end: const Offset(1.3, 1.3),
                       curve: Curves.easeInOut,
                     ),
                    const SizedBox(width: 8),
                    Text(
                      'System monitoring active',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: AppColors.getTextMuted(isDark),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AlertsHistoryScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.getBackground(isDark),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.getGlassBorder(isDark),
                  width: 1.0,
                ),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                color: AppColors.getTextPrimary(isDark),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Small Logo in Header with premium gradient ring
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.cyan, AppColors.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.getSurface(isDark),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo.png',
                  height: 24,
                  width: 24,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0, duration: 400.ms);
  }

  Widget _buildDeviceCard(BuildContext context, String deviceId, bool isDark) {
    final deviceState = ref.watch(deviceProvider(deviceId));
    final historyState = ref.watch(historyProvider(deviceId));
    final userState = ref.watch(userProvider).value;
    final customDeviceNames = userState?['customDeviceNames'] as Map<String, dynamic>?;
    final customName = customDeviceNames?[deviceId];

    return deviceState.when(
      data: (device) {
        final totalCurrent = device.line3;
        final displayName = (customName != null && customName.isNotEmpty)
            ? customName
            : (device.name != null && device.name!.isNotEmpty
                ? device.name!
                : 'Device $deviceId');

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.getGlassBorder(isDark),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.02),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.getTextPrimary(isDark),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showEditDeviceNameDialog(context, device, customName),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: AppColors.cyan,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: $deviceId',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextMuted(isDark),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${device.totalAerators} Units Connected',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppColors.getTextMuted(isDark),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: device.isActive ? AppColors.green : AppColors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              device.isActive ? 'Online' : 'Offline',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: device.isActive ? AppColors.green : AppColors.red,
                              ),
                            ),
                            if (!device.isActive && device.inactiveSince != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '(since ${DateFormat('MMM d, h:mm a').format(device.inactiveSince!.toUtc().add(const Duration(hours: 5, minutes: 30)))})',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppColors.red.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ] else if (device.lastSeen != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '(last active ${DateFormat('dd MMM yyyy, hh:mm a').format(device.lastSeen!.toUtc().add(const Duration(hours: 5, minutes: 30)))})',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppColors.getTextMuted(isDark),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'LOAD',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppColors.getTextMuted(isDark),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '${totalCurrent.toStringAsFixed(1)}A',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cyan,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Phase Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _phaseItem('R-Phase', device.line1, AppColors.blue, isDark),
                  _phaseItem('Y-Phase', device.line2, AppColors.blue, isDark),
                  _phaseItem('B-Phase', device.line3, AppColors.blue, isDark),
                ],
              ),
              const SizedBox(height: 24),
              // Aerator Status & Calibration Section (Grid/Boxes Layout)
              Column(
                children: [
                  Row(
                    children: [
                      // Box 1: Aerators Working
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          height: 88,
                          decoration: BoxDecoration(
                            color: AppColors.getBackground(isDark),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.getGlassBorder(isDark),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'AERATORS WORKING',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.getTextMuted(isDark),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _getAeratorStatusColor(device),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${device.workingAerators} / ${device.totalAerators}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.getTextPrimary(isDark),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Box 2: Current per Aerator
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          height: 88,
                          decoration: BoxDecoration(
                            color: AppColors.getBackground(isDark),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.getGlassBorder(isDark),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'CURRENT PER AERATOR',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.getTextMuted(isDark),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: device.isCalibrated 
                                      ? AppColors.cyan.withValues(alpha: 0.06) 
                                      : AppColors.orange.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: (device.isCalibrated ? AppColors.cyan : AppColors.orange).withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  device.isCalibrated 
                                      ? '${device.fixedCurrentPerAerator.toStringAsFixed(2)}A'
                                      : 'Not Calibrated',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: device.isCalibrated ? AppColors.cyan : AppColors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Box 3: Calibration Button Box
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(isDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.getGlassBorder(isDark),
                        width: 1.0,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showCalibrationInputDialog(context, ref, device, isDark),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 16,
                              color: AppColors.getTextPrimary(isDark).withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Fix Aerators',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.getTextPrimary(isDark).withValues(alpha: 0.8),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
              const SizedBox(height: 24),
              Divider(
                color: AppColors.getGlassBorder(isDark),
                height: 1,
              ),
              const SizedBox(height: 16),
              Text(
                'LATEST ALERTS',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.getTextMuted(isDark),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              historyState.when(
                data: (history) {
                  final alerts = history
                      .where((item) => item['type'] == 'Alert')
                      .toList();
                  
                  alerts.sort((a, b) => DateTime.parse(b['timestamp'])
                      .compareTo(DateTime.parse(a['timestamp'])));
                  
                  final latestAlerts = alerts.take(3).toList();

                  if (latestAlerts.isEmpty) {
                    return Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'System nominal, No recent alerts',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: latestAlerts.map((item) {
                      final message = item['message'] ?? 'Unknown alert';
                      final date = DateTime.parse(item['timestamp']).toLocal();
                      final timeStr = DateFormat('hh:mm a').format(date);
                      final isAlert = item['type'] == 'Alert';
                      final indicatorColor = isAlert ? AppColors.red : AppColors.green;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: indicatorColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                message,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.getTextPrimary(isDark),
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              timeStr,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.getTextMuted(isDark),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.cyan,
                      ),
                    ),
                  ),
                ),
                error: (e, _) => Text(
                  'Failed to load alerts',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.red,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.getSurface(isDark),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.getGlassBorder(isDark),
            width: 1.0,
          ),
        ),
        child: const CircularProgressIndicator(color: AppColors.cyan),
      ),
      error: (e, _) => Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.getSurface(isDark),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.getGlassBorder(isDark),
            width: 1.0,
          ),
        ),
        child: Text(
          'Error: $e',
          style: GoogleFonts.outfit(color: AppColors.red),
        ),
      ),
    );
  }

  Widget _buildAlertPin({required bool isAlert, required bool isDark}) {
    final baseColor = isAlert ? AppColors.red : AppColors.green;
    
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isAlert)
            // Pulsing glow ring for critical alerts
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: baseColor.withValues(alpha: 0.2),
              ),
            )
            .animate(onPlay: (controller) => controller.repeat())
            .scale(
              duration: 1800.ms,
              begin: const Offset(0.7, 0.7),
              end: const Offset(1.4, 1.4),
              curve: Curves.easeOut,
            )
            .fadeOut(duration: 1800.ms)
          else
            // Subtle static glow for recovered state
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: baseColor.withValues(alpha: 0.1),
              ),
            ),
            
          // Middle ring with border
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: baseColor.withValues(alpha: 0.15),
              border: Border.all(
                color: baseColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          
          // Inner solid badge containing icon
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: baseColor,
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.3),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              isAlert ? Icons.warning_rounded : Icons.check_rounded,
              size: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _phaseItem(String label, double val, Color color, bool isDark) {
    return SizedBox(
      width: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextMuted(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${val.toStringAsFixed(1)}A',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 6),
          // Clean progress bar
          Container(
            height: 3.5,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: AppColors.getGlassBorder(isDark).withValues(alpha: 0.15),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (val / 15.0).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAeratorStatusColor(DeviceModel device) {
    if (device.totalAerators == 0) return AppColors.orange;
    final notWorking = device.totalAerators - device.workingAerators;
    if (notWorking == 0) {
      return AppColors.green;
    } else if (notWorking >= 1) {
      return AppColors.red;
    } else {
      return AppColors.yellow;
    }
  }

  void _showCalibrationInputDialog(
      BuildContext context, WidgetRef ref, DeviceModel device, bool isDark) {
    final totalController = TextEditingController(
        text: device.totalAerators > 0 ? device.totalAerators.toString() : '1');
    final runningController = TextEditingController(
        text: device.workingAerators > 0
            ? device.workingAerators.toString()
            : (device.totalAerators > 0 ? device.totalAerators.toString() : '1'));

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getBackground(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Calibrate Device ${device.deviceId}',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.getTextPrimary(isDark),
          ),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verify the current aerator configuration to start calibration.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Total connected aerators
                Text(
                  'Total Aerators Connected',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: totalController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.outfit(color: AppColors.getTextPrimary(isDark)),
                  decoration: InputDecoration(
                    hintText: 'Enter connected aerators',
                    hintStyle: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.getGlassBorder(isDark).withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.red, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.red, width: 1.5),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'This field is required';
                    }
                    final parsed = int.tryParse(val.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Must be greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Running aerators during calibration
                Text(
                  'Aerators Running Currently',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: runningController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.outfit(color: AppColors.getTextPrimary(isDark)),
                  decoration: InputDecoration(
                    hintText: 'Enter running aerators',
                    hintStyle: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.getGlassBorder(isDark).withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.red, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.red, width: 1.5),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'This field is required';
                    }
                    final parsed = int.tryParse(val.trim());
                    if (parsed == null || parsed < 0) {
                      return 'Must be a valid positive number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                
                // Show Current Telemetry Information
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.cyan.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.cyan, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Line 3 Current: ${device.line3.toStringAsFixed(2)}A',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.cyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.getTextSecondary(isDark)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyan,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final total = int.parse(totalController.text.trim());
                final running = int.parse(runningController.text.trim());

                // Client-side Validation:
                // 1. When all aerators are stopped (running == 0)
                if (running == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Calibration stopped: All aerators are stopped. You must run at least one aerator to calibrate.',
                        style: GoogleFonts.outfit(color: Colors.white),
                      ),
                      backgroundColor: AppColors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                // 2. When line three value is less than 2A
                if (device.line3 < 2.0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Calibration stopped: Line 3 current is less than 2A (${device.line3.toStringAsFixed(2)}A). Ensure aerators are ON.',
                        style: GoogleFonts.outfit(color: Colors.white),
                      ),
                      backgroundColor: AppColors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                // 3. Stop calibrating if calculated per-aerator current is less than 1A
                final calculatedCurrentPerAerator = device.line3 / running;
                if (calculatedCurrentPerAerator < 1.0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Calibration stopped: Calculated per-aerator current is less than 1A (${calculatedCurrentPerAerator.toStringAsFixed(2)}A).',
                        style: GoogleFonts.outfit(color: Colors.white),
                      ),
                      backgroundColor: AppColors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                Navigator.pop(context); // Close inputs dialog
                _showCalibrationProgress(context, ref, device, isDark, running, total);
              }
            },
            child: Text(
              'Calibrate',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCalibrationProgress(BuildContext context, WidgetRef ref, DeviceModel device, bool isDark, int runningAerators, int totalAerators) {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.getBackground(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Calibrating Device ${device.deviceId}',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                color: AppColors.getTextPrimary(isDark))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          SizedBox(
            width: 100,
            height: 100,
            child: const CircularProgressIndicator(
                    color: AppColors.cyan, strokeWidth: 8)
                .animate(onPlay: (c) => c.repeat())
                .rotate(duration: 2.seconds),
          ),
          const SizedBox(height: 24),
          Text('Analyzing phase currents...',
              style: GoogleFonts.outfit(
                  fontSize: 14, color: AppColors.getTextSecondary(isDark))),
        ]),
      ),
    );

    // Call API
    ref.read(deviceProvider(device.deviceId).notifier).calibrate(
      runningAerators: runningAerators,
      totalAerators: totalAerators,
    ).then((errorMessage) {
      // Pop the dialog using the captured navigator instance safely
      navigator.pop();

      final bool success = errorMessage == null;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Calibration successful' : errorMessage,
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          backgroundColor: success ? AppColors.green : AppColors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }
}

// ──────────────────────────────────────────────────────────
// Pending Invitation Banner (shown on Dashboard)
// ──────────────────────────────────────────────────────────
class _InvitationBanner extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> invitations;
  final bool isDark;

  const _InvitationBanner({
    required this.invitations,
    required this.isDark,
  });

  @override
  ConsumerState<_InvitationBanner> createState() => _InvitationBannerState();
}

class _InvitationBannerState extends ConsumerState<_InvitationBanner> {
  bool _isProcessing = false;
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.invitations.isEmpty) return const SizedBox.shrink();
    if (_currentIndex >= widget.invitations.length) return const SizedBox.shrink();

    final invite = widget.invitations[_currentIndex];
    final ownerEmail = invite['ownerEmail'] as String? ?? '';
    final ownerName = invite['ownerName'] as String? ?? 'Someone';
    final devices = (invite['devices'] as List<dynamic>? ?? []).cast<String>();
    final total = widget.invitations.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.cyan.withValues(alpha: 0.12),
              AppColors.blue.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.cyan.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.share_rounded,
                      color: AppColors.cyan,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      total > 1
                          ? 'Access Request (${_currentIndex + 1}/$total)'
                          : 'Access Request',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cyan,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  // Dismiss / next if multiple
                  if (total > 1)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentIndex = (_currentIndex + 1) % total;
                        });
                      },
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.getTextMuted(widget.isDark),
                        size: 20,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Invite body
              RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.getTextSecondary(widget.isDark),
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: ownerName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(widget.isDark),
                      ),
                    ),
                    const TextSpan(text: ' wants to share access to '),
                    TextSpan(
                      text: devices.isEmpty
                          ? 'their devices'
                          : devices.join(', '),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        color: AppColors.cyan,
                      ),
                    ),
                    const TextSpan(text: ' with you.'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            final confirm = await ConfirmationDialog.show(
                              context: context,
                              title: 'Decline Request',
                              message: 'Are you sure you want to decline the access request from $ownerName ($ownerEmail)?',
                              confirmLabel: 'Decline',
                              icon: Icons.close_rounded,
                              isDestructive: true,
                            );
                            if (confirm != true) return;

                            setState(() => _isProcessing = true);
                            try {
                              await ref
                                  .read(userProvider.notifier)
                                  .declineInvitation(ownerEmail);
                            } finally {
                              if (mounted) setState(() => _isProcessing = false);
                            }
                          },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Decline',
                      style: GoogleFonts.outfit(
                        color: AppColors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            final confirm = await ConfirmationDialog.show(
                              context: context,
                              title: 'Accept Request',
                              message: 'Are you sure you want to accept the access request from $ownerName ($ownerEmail)?',
                              confirmLabel: 'Accept',
                              icon: Icons.check_rounded,
                              iconColor: AppColors.green,
                            );
                            if (confirm != true) return;

                            setState(() => _isProcessing = true);
                            try {
                              await ref
                                  .read(userProvider.notifier)
                                  .acceptInvitation(ownerEmail);
                            } finally {
                              if (mounted) setState(() => _isProcessing = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Accept',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 400.ms)
          .slideY(begin: -0.05, end: 0, curve: Curves.easeOut),
    );
  }
}
