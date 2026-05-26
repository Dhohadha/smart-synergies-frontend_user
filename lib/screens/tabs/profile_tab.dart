import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glass_card.dart';
import '../share_access_screen.dart';
import '../../core/app_config.dart';
import '../../widgets/confirmation_dialog.dart';

final logoutLoadingProvider = StateProvider<bool>((ref) => false);

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

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
          final sharedWith =
              (user['sharedWith'] as List<dynamic>?)?.cast<String>() ?? [];
          final bool alertSoundEnabled = user['settings']?['alertSoundEnabled'] ?? true;
          final userName = user['name'] ?? 'User';
          final userEmail = user['email'] ?? '';
          final userRole = user['isSharedUser'] == true ? 'Shared User' : 'Owner';

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 30),
            children: [
              _profileHero(context, ref, userName, userEmail, userRole, assignedDevices.length, isDark)
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.05, end: 0),
              const SizedBox(height: 12),
              _sectionLabel(
                Icons.devices_rounded,
                'Assigned Devices',
                isDark,
                trailing: assignedDevices.length > 1
                    ? IconButton(
                        icon: const Icon(Icons.reorder_rounded, color: AppColors.cyan, size: 20),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        tooltip: 'Prioritize / Reorder',
                        onPressed: () => _showReorderDevicesDialog(context, ref, assignedDevices, isDark),
                      )
                    : null,
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 150.ms),
              _assignedDevicesList(ref, assignedDevices, isDark)
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 200.ms),
              const SizedBox(height: 12),
              
              // Invitations Section (only show pending, not declined)
              if ((user['pendingInvitations'] as List<dynamic>? ?? [])
                  .where((i) => (i['status'] ?? 'pending') != 'declined')
                  .isNotEmpty) ...[
                _sectionLabel(Icons.mark_email_unread_rounded, 'Access Requests', isDark)
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 220.ms),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: (user['pendingInvitations'] as List<dynamic>)
                        .where((i) => (i['status'] ?? 'pending') != 'declined')
                        .map((invite) => _ProfileInvitationItem(
                              invite: Map<String, dynamic>.from(invite),
                              ref: ref,
                              isDark: isDark,
                            ))
                        .toList(),
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 240.ms),
                const SizedBox(height: 12),
              ],

              if (userRole == 'Owner') ...[
                _sectionLabel(Icons.share_rounded, 'Device Management', isDark)
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 250.ms),
                _managementSection(context, ref, sharedWith, isDark)
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 300.ms),
              ],
              _sectionLabel(Icons.settings_rounded, 'Settings', isDark)
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 450.ms),
              _settingsSection(context, ref, alertSoundEnabled, isDark)
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 500.ms),
              const SizedBox(height: 12),
              _logoutBtn(context, ref, isDark).animate().fadeIn(duration: 500.ms, delay: 600.ms),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _profileHero(BuildContext context, WidgetRef ref, String name, String email, String role, int totalDevices, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.blue.withValues(alpha: 0.25),
            AppColors.cyan.withValues(alpha: 0.08)
          ],
        ),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
              color: isDark
                  ? AppColors.blue.withValues(alpha: 0.1)
                  : Colors.blueGrey.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(children: [
        Row(children: [
          Stack(children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [AppColors.cyan, AppColors.blue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.cyan.withValues(alpha: 0.3),
                      blurRadius: 16)
                ],
              ),
              child: Center(
                  child: Text(name.isNotEmpty ? name[0] : 'U',
                      style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white))),
            ),
            Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.getBackground(isDark), width: 2.5),
                  ),
                )),
          ]),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.getTextPrimary(isDark)),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: AppColors.cyan, size: 18),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      tooltip: 'Edit Name',
                      onPressed: () => _showEditNameDialog(context, ref, name, isDark),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(role,
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.cyan,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(email,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.getTextMuted(isDark))),
              ])),
        ]),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: AppColors.getGlassBg(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getGlassBorder(isDark))),
          child: Row(children: [
            _pStat(context, totalDevices.toString(), 'Devices', isDark),
          ]),
        ),
      ]),
    );
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref, String currentName, bool isDark) {
    final controller = TextEditingController(text: currentName);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.getSurface(isDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'Edit Name',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update your display name:',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.getTextMuted(isDark),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    style: GoogleFonts.outfit(color: AppColors.getTextPrimary(isDark)),
                    decoration: InputDecoration(
                      labelText: 'Display Name',
                      labelStyle: GoogleFonts.outfit(color: AppColors.cyan),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.getGlassBorder(isDark)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.cyan, width: 2),
                      ),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.cyan),
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
                          if (newName.isNotEmpty) {
                            setDialogState(() => isSaving = true);
                            final success = await ref.read(userProvider.notifier).updateProfileName(newName);
                            setDialogState(() => isSaving = false);
                            if (success && context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Name updated successfully!', style: GoogleFonts.outfit()),
                                  backgroundColor: AppColors.cyan,
                                ),
                              );
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update name.', style: GoogleFonts.outfit()),
                                  backgroundColor: AppColors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyan,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Save',
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _pStat(BuildContext context, String v, String l, bool isDark) {
    return Expanded(
        child: Column(children: [
      Text(v,
          style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.getTextPrimary(isDark))),
      const SizedBox(height: 2),
      Text(l,
          style: GoogleFonts.outfit(
              fontSize: 11, color: AppColors.getTextMuted(isDark))),
    ]));
  }


  Widget _sectionLabel(IconData icon, String label, bool isDark, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(icon, color: AppColors.cyan, size: 16),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cyan,
                      letterSpacing: 0.3)),
            ]),
            ?trailing,
          ],
        ),
      );

  Widget _assignedDevicesList(WidgetRef ref, List<String> assignedDevices, bool isDark) {
    if (assignedDevices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text('No devices assigned.', style: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark))),
      );
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getGlassBorder(isDark), width: 1.5),
      ),
      child: Column(
        children: assignedDevices.map((id) {
          final deviceState = ref.watch(deviceProvider(id)).value;
          final displayName = deviceState?.name != null && deviceState!.name!.isNotEmpty
              ? deviceState.name!
              : 'Device $id';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                const Icon(Icons.developer_board_rounded, color: AppColors.cyan, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.outfit(
                          color: AppColors.getTextPrimary(isDark),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (deviceState?.name != null && deviceState!.name!.isNotEmpty)
                        Text(
                          'ID: $id',
                          style: GoogleFonts.outfit(
                            color: AppColors.getTextMuted(isDark),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _managementSection(BuildContext context, WidgetRef ref, List<String> sharedWith, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        _actionRow(
          context,
          Icons.person_add_alt_1_rounded,
          AppColors.cyan,
          'Share Device Access',
          'Manage shared user permissions',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShareAccessScreen()),
            );
          },
          isDark
        ),
      ]),
    );
  }

  Widget _actionRow(BuildContext context, IconData icon, Color c, String title,
      String sub, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: c.withValues(alpha: 0.12)),
              child: Icon(icon, color: c, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(isDark))),
                Text(sub,
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.getTextMuted(isDark))),
              ])),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.getTextMuted(isDark).withValues(alpha: 0.5)),
        ]),
      ),
    );
  }

  Widget _settingsSection(BuildContext context, WidgetRef ref, bool alertSoundEnabled, bool isDark) {
    final themeMode = ref.watch(themeProvider);
    final isDarkModeEnabled = themeMode == ThemeMode.dark;

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        _settingRow(context, Icons.dark_mode_rounded, AppColors.blue,
            'Dark Mode', isDarkModeEnabled, (val) {
          ref.read(themeProvider.notifier).state =
              val ? ThemeMode.dark : ThemeMode.light;
        }, isDark),
        Divider(
            height: 1,
            color: AppColors.getGlassBorder(isDark),
            indent: 16,
            endIndent: 16),
        _settingRow(context, Icons.volume_up_rounded, AppColors.teal,
            'Sound Alerts', alertSoundEnabled, (val) {
          ref.read(userProvider.notifier).updateAlertSound(val);
        }, isDark),
        Divider(
            height: 1,
            color: AppColors.getGlassBorder(isDark),
            indent: 16,
            endIndent: 16),
        _serverConnectionRow(context, ref, isDark),
      ]),
    );
  }

  Widget _serverConnectionRow(BuildContext context, WidgetRef ref, bool isDark) {
    return InkWell(
      onTap: () => _showServerIPDialog(context, ref, isDark),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.cyan.withValues(alpha: 0.12)),
              child: const Icon(Icons.wifi_tethering_rounded, color: AppColors.cyan, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Server Connection',
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(isDark))),
                Text('Active IP: ${AppConfig.serverIP}',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.getTextMuted(isDark))),
              ])),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.getTextMuted(isDark).withValues(alpha: 0.5)),
        ]),
      ),
    );
  }

  void _showServerIPDialog(BuildContext context, WidgetRef ref, bool isDark) {
    final ipController = TextEditingController(text: AppConfig.serverIP);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.getSurface(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Server IP Settings',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the IP address of your local Node.js server. For Android Emulator, use 10.0.2.2.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.getTextMuted(isDark),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ipController,
                style: GoogleFonts.outfit(color: AppColors.getTextPrimary(isDark)),
                decoration: InputDecoration(
                  labelText: 'Server IP Address',
                  labelStyle: GoogleFonts.outfit(color: AppColors.cyan),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.getGlassBorder(isDark)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cyan, width: 2),
                  ),
                  prefixIcon: const Icon(Icons.computer_rounded, color: AppColors.cyan),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark), fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newIP = ipController.text.trim();
                if (newIP.isNotEmpty) {
                  await AppConfig.saveIP(newIP);
                  // Refresh user provider to force recreation of HTTP clients and re-connection
                  ref.invalidate(userProvider);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Server IP updated to $newIP. Reconnecting...',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: AppColors.cyan,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                'Save & Connect',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showReorderDevicesDialog(
      BuildContext context, WidgetRef ref, List<String> devices, bool isDark) {
    final List<String> localDevices = List.from(devices);
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
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
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prioritize Devices',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Drag and drop items to reorder them. The order matches the sequence of dashboards.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.getTextMuted(isDark),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: localDevices.length,
                  onReorder: (oldIndex, newIndex) {
                    setDialogState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = localDevices.removeAt(oldIndex);
                      localDevices.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final deviceId = localDevices[index];
                    final deviceState = ref.read(deviceProvider(deviceId)).value;
                    final displayName = deviceState?.name != null && deviceState!.name!.isNotEmpty
                        ? deviceState.name!
                        : 'Device $deviceId';

                    return Material(
                      key: ValueKey(deviceId),
                      color: Colors.transparent,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A2438) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.drag_indicator_rounded,
                              color: AppColors.cyan,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.getTextPrimary(isDark),
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (deviceState?.name != null && deviceState!.name!.isNotEmpty)
                                    Text(
                                      'ID: $deviceId',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: AppColors.getTextMuted(isDark),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
                          setDialogState(() => isSaving = true);
                          final success = await ref
                              .read(userProvider.notifier)
                              .updateDevicesOrder(localDevices);
                          setDialogState(() => isSaving = false);
                          if (success && context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Device priority updated successfully!',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: AppColors.cyan,
                              ),
                            );
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to update device priority.',
                                  style: GoogleFonts.outfit(),
                                ),
                                backgroundColor: AppColors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyan,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Save',
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _settingRow(BuildContext context, IconData icon, Color c, String label,
      bool v, ValueChanged<bool> onChanged, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: c.withValues(alpha: 0.12)),
            child: Icon(icon, color: c, size: 18)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(isDark)))),
        Switch(
          value: v,
          onChanged: onChanged,
          activeThumbColor: c,
        )
      ]),
    );
  }

  Widget _logoutBtn(BuildContext context, WidgetRef ref, bool isDark) {
    final isLoggingOut = ref.watch(logoutLoadingProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: isLoggingOut 
          ? null 
          : () async {
              final confirm = await ConfirmationDialog.show(
                context: context,
                title: 'Sign Out',
                message: 'Are you sure you want to sign out?',
                confirmLabel: 'Sign Out',
                icon: Icons.logout_rounded,
                isDestructive: true,
              );
              if (confirm != true) return;

              ref.read(logoutLoadingProvider.notifier).state = true;
              try {
                await ref.read(authProvider.notifier).signOut();
              } finally {
                // state is usually reset by main.dart switching screens, 
                // but we reset it just in case.
                ref.read(logoutLoadingProvider.notifier).state = false;
              }
            },
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
            color: AppColors.red.withValues(alpha: 0.08),
          ),
          child: Center(
            child: isLoggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: AppColors.red, strokeWidth: 2),
                  )
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.logout_rounded, color: AppColors.red, size: 20),
                    const SizedBox(width: 10),
                    Text('Sign Out',
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.red)),
                  ]),
          ),
        ),
      ),
    );
  }
}

class _ProfileInvitationItem extends StatefulWidget {
  final Map<String, dynamic> invite;
  final WidgetRef ref;
  final bool isDark;

  const _ProfileInvitationItem({
    required this.invite,
    required this.ref,
    required this.isDark,
  });

  @override
  State<_ProfileInvitationItem> createState() => _ProfileInvitationItemState();
}

class _ProfileInvitationItemState extends State<_ProfileInvitationItem> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final ownerEmail = widget.invite['ownerEmail'] as String? ?? '';
    final ownerName = widget.invite['ownerName'] as String? ?? 'An Owner';
    final devices = (widget.invite['devices'] as List<dynamic>? ?? []).cast<String>();

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.cyan.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.share_rounded, color: AppColors.cyan, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Access Request',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.getTextPrimary(widget.isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'From: $ownerName ($ownerEmail)',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.getTextMuted(widget.isDark),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (devices.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Invited to monitor: ${devices.join(', ')}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.getTextSecondary(widget.isDark),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
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
                          await widget.ref
                              .read(userProvider.notifier)
                              .declineInvitation(ownerEmail);
                          // fetchUserProfile() is already called internally by declineInvitation
                        } finally {
                          if (mounted) setState(() => _isProcessing = false);
                        }
                      },
                child: Text(
                  'Decline',
                  style: GoogleFonts.outfit(
                    color: AppColors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                          await widget.ref
                              .read(userProvider.notifier)
                              .acceptInvitation(ownerEmail);
                          // fetchUserProfile() is already called internally by acceptInvitation
                        } finally {
                          if (mounted) setState(() => _isProcessing = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Accept',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
