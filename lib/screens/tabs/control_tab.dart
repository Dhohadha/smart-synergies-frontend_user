import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../providers/device_provider.dart';
import '../../models/device_model.dart';
import '../../widgets/error_screen.dart';
import '../../providers/server_status_provider.dart';
import '../../widgets/confirmation_dialog.dart';

class ControlTab extends ConsumerWidget {
  const ControlTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.green.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blue.withValues(alpha: 0.06),
                ),
              ),
            ),
          ] else ...[
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.green.withValues(alpha: 0.03),
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
                    (user['assignedDevices'] as List<dynamic>?)?.cast<String>() ?? [];

                int totalDevices = assignedDevices.length;

                return Consumer(
                  builder: (context, innerRef, _) {
                    int onlineCount = 0;
                    for (final did in assignedDevices) {
                      final dState = innerRef.watch(deviceProvider(did)).value;
                      if (dState != null && dState.isActive) onlineCount++;
                    }
                    return Column(
                      children: [
                        _buildHeader(context, isDark, onlineCount, totalDevices),
                    
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

                    const SizedBox(height: 12),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.cyan,
                        onRefresh: () async {
                          try {
                            // 1. Refresh User Profile quietly
                            await ref.read(userProvider.notifier).refreshProfileQuietly();
                            
                            // 2. Fetch fresh device status for each assigned device
                            final updatedUser = ref.read(userProvider).value;
                            if (updatedUser != null) {
                              final devices = (updatedUser['assignedDevices'] as List<dynamic>?)?.cast<String>() ?? [];
                              await Future.wait(devices.map((deviceId) async {
                                await ref.read(deviceProvider(deviceId).notifier).fetchDeviceData(showLoading: false);
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
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorScreen(
                error: e,
                onRefresh: () => ref.read(userProvider.notifier).fetchUserProfile(),
              ),
            ),
          ),
        ],
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
    final userState = ref.watch(userProvider).value;
    final customDeviceNames = userState?['customDeviceNames'] as Map<String, dynamic>?;
    final customName = customDeviceNames?[deviceId];

    return deviceState.when(
      data: (device) {
        final isAnyRelayOn = device.relays.any((r) => r.status);
        final displayName = (customName != null && customName.isNotEmpty)
            ? customName
            : (device.name != null && device.name!.isNotEmpty
                ? device.name!
                : 'Device $deviceId');
        final cardContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceHeader(device, displayName, isDark),
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
                      onToggle: () async {
                        final bool targetState = !device.relays[0].status;
                        final bool? confirm = await ConfirmationDialog.show(
                          context: context,
                          title: targetState ? 'Start Relay 1?' : 'Stop Relay 1?',
                          message: targetState 
                              ? 'Are you sure you want to start this aerator?'
                              : 'Warning: Stopping the aerator may reduce oxygen levels. Are you sure?',
                          confirmLabel: targetState ? 'Start' : 'Stop',
                          isDestructive: !targetState,
                          icon: Icons.power_settings_new_rounded,
                          iconColor: targetState ? AppColors.green : AppColors.red,
                        );
                        if (confirm == true) {
                          ref.read(deviceProvider(deviceId).notifier).toggleRelay(
                            r1: targetState,
                          );
                        }
                      },
                    ),
                  if (device.relays.length > 1)
                    _RelayControlRow(
                      deviceId: deviceId,
                      relayName: 'Relay 2',
                      isOn: device.relays[1].status,
                      isDark: isDark,
                      onToggle: () async {
                        final bool targetState = !device.relays[1].status;
                        final bool? confirm = await ConfirmationDialog.show(
                          context: context,
                          title: targetState ? 'Start Relay 2?' : 'Stop Relay 2?',
                          message: targetState 
                              ? 'Are you sure you want to start this aerator?'
                              : 'Warning: Stopping the aerator may reduce oxygen levels. Are you sure?',
                          confirmLabel: targetState ? 'Start' : 'Stop',
                          isDestructive: !targetState,
                          icon: Icons.power_settings_new_rounded,
                          iconColor: targetState ? AppColors.green : AppColors.red,
                        );
                        if (confirm == true) {
                          ref.read(deviceProvider(deviceId).notifier).toggleRelay(
                            r2: targetState,
                          );
                        }
                      },
                    ),
                ],
              ),
            )
          ],
        );

        if (isAnyRelayOn) {
          return cardContent
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .custom(
                duration: 2000.ms,
                builder: (context, value, child) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(isDark).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.green.withValues(alpha: 0.15 + (value * 0.25)),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withValues(alpha: 0.03 + (value * 0.05)),
                          blurRadius: 16 + (value * 8),
                          spreadRadius: value * 1.5,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
              );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.getGlassBorder(isDark),
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
          child: cardContent,
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

  Widget _buildDeviceHeader(DeviceModel device, String displayName, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.getBackground(isDark),
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
                Text(
                  displayName,
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.getTextPrimary(isDark))),
                const SizedBox(height: 2),
                Text(
                  'ID: ${device.deviceId}',
                  style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextMuted(isDark))),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: device.isActive ? AppColors.green : AppColors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      device.isActive ? 'Online' : 'Offline',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: device.isActive ? AppColors.green : AppColors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${device.workingAerators}/${device.totalAerators} Aerators Working',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.getTextMuted(isDark),
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
        color: isOn
            ? (isDark ? AppColors.green.withValues(alpha: 0.06) : AppColors.green.withValues(alpha: 0.03))
            : AppColors.getBackground(isDark).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOn
              ? AppColors.green.withValues(alpha: 0.4)
              : AppColors.getGlassBorder(isDark),
          width: isOn ? 1.2 : 1.0,
        ),
        boxShadow: isOn
            ? [
                BoxShadow(
                  color: AppColors.green.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.getGlassBorder(isDark).withValues(alpha: 0.3),
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
        curve: Curves.easeInOutCubic,
        width: 50,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: value
              ? const LinearGradient(
                  colors: [AppColors.green, Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: value
              ? null
              : (isDark ? AppColors.getBackground(isDark) : const Color(0xFFE2E8F0)),
          border: Border.all(
            color: value
                ? Colors.transparent
                : AppColors.getGlassBorder(isDark),
            width: 1.0,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: AppColors.green.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value 
                      ? Colors.white 
                      : (isDark ? AppColors.textSecondary : const Color(0xFF94A3B8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
