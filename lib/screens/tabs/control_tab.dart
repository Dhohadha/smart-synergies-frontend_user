import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../providers/device_provider.dart';
import '../../models/device_model.dart';

class ControlTab extends ConsumerWidget {
  const ControlTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: userState.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Please log in.'));
          }

          final assignedDevices =
              (user['assignedDevices'] as List<dynamic>?)?.cast<String>() ?? [];

          int totalDevices = assignedDevices.length;
          int onlineCount = assignedDevices.length; // Simplified for now

          return Column(
            children: [
              _buildHeader(context, isDark, onlineCount, totalDevices),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.cyan,
                  onRefresh: () async {
                    try {
                      // 1. Refresh User Profile
                      await ref.read(userProvider.notifier).fetchUserProfile();
                      
                      // 2. Fetch fresh device status for each assigned device
                      final updatedUser = ref.read(userProvider).value;
                      if (updatedUser != null) {
                        final devices = (updatedUser['assignedDevices'] as List<dynamic>?)?.cast<String>() ?? [];
                        await Future.wait(devices.map((deviceId) async {
                          await ref.read(deviceProvider(deviceId).notifier).fetchDeviceData();
                        }));
                      }
                    } catch (e) {
                      debugPrint('Error refreshing control: $e');
                    }
                  },
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    itemCount: assignedDevices.length,
                    itemBuilder: (context, i) {
                      final deviceId = assignedDevices[i];
                      return _DeviceControlCard(deviceId: deviceId, index: i);
                    },
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, bool isDark, int onlineCount, int totalDevices) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('System Control',
              style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 4),
          Row(children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.green.withValues(alpha: 0.5),
                          blurRadius: 4)
                    ])),
            const SizedBox(width: 12),
            Text('$onlineCount Online . $totalDevices Total',
                style: GoogleFonts.outfit(
                    fontSize: 13, color: AppColors.getTextMuted(isDark))),
          ]),
        ]),
      ]),
    ).animate().fadeIn(duration: 500.ms);
  }
}

class _DeviceControlCard extends ConsumerWidget {
  final String deviceId;
  final int index;
  
  const _DeviceControlCard({required this.deviceId, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceState = ref.watch(deviceProvider(deviceId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return deviceState.when(
      data: (device) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131C2E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDeviceHeader(device, isDark),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    if (device.relays.isNotEmpty)
                      _RelayControlRow(
                        deviceId: deviceId,
                        relayName: 'Relay 1',
                        isOn: device.relays[0].status,
                        isDark: isDark,
                        onToggle: () {
                          ref.read(deviceProvider(deviceId).notifier).toggleRelay(
                            r1: !device.relays[0].status,
                          );
                        },
                      ),
                    if (device.relays.length > 1)
                      _RelayControlRow(
                        deviceId: deviceId,
                        relayName: 'Relay 2',
                        isOn: device.relays[1].status,
                        isDark: isDark,
                        onToggle: () {
                          ref.read(deviceProvider(deviceId).notifier).toggleRelay(
                            r2: !device.relays[1].status,
                          );
                        },
                      ),
                  ],
                ),
              )
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text('Error loading device $deviceId: $e'),
      ),
    );
  }

  Widget _buildDeviceHeader(DeviceModel device, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.settings_input_component_rounded,
                color: AppColors.cyan, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Device ${device.deviceId}',
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(isDark))),
                Text('${device.workingAerators}/${device.totalAerators} Aerators Working',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.getTextMuted(isDark))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (device.isCalibrated ? AppColors.green : AppColors.orange).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: (device.isCalibrated ? AppColors.green : AppColors.orange).withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Text(
              device.isCalibrated ? 'CALIBRATED' : 'NEEDS CALIBRATION',
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: device.isCalibrated ? AppColors.green : AppColors.orange,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelayControlRow extends StatelessWidget {
  final String deviceId;
  final String relayName;
  final bool isOn;
  final bool isDark;
  final VoidCallback onToggle;

  const _RelayControlRow({
    required this.deviceId,
    required this.relayName,
    required this.isOn,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2438) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOn
              ? AppColors.green.withValues(alpha: 0.3)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2E394A).withValues(alpha: 0.3) : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.power_settings_new_rounded,
              color: isOn ? AppColors.green : AppColors.getTextMuted(isDark),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(relayName,
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.getTextPrimary(isDark))),
              const SizedBox(height: 2),
              Text(isOn ? 'RUNNING' : 'STOPPED',
                  style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: isOn ? AppColors.green : AppColors.getTextMuted(isDark),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2)),
            ]),
          ),
          _AnimatedToggle(value: isOn, onChanged: (_) => onToggle()),
        ]),
      ),
    );
  }
}

class _AnimatedToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _AnimatedToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value 
              ? AppColors.green.withValues(alpha: 0.08) 
              : (isDark ? const Color(0xFF1A2438) : const Color(0xFFF1F5F9)),
          border: Border.all(
            color: value 
                ? AppColors.green.withValues(alpha: 0.3) 
                : (isDark ? const Color(0xFF2E394A) : const Color(0xFFCBD5E1)),
            width: 1.0,
          ),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? AppColors.green : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
