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
import '../../widgets/confirmation_dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../widgets/alarm_permission_dialog.dart';
import '../../widgets/error_screen.dart';

class _PermissionStatusSection extends StatefulWidget {
  const _PermissionStatusSection();

  @override
  State<_PermissionStatusSection> createState() => _PermissionStatusSectionState();
}

class _PermissionStatusSectionState extends State<_PermissionStatusSection> with WidgetsBindingObserver {
  bool _hasFullScreenIntent = true;
  bool _hasNotificationPermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final hasFullScreen = await AlarmPermissionHelper.isGranted();
    
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    final androidImplementation = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    bool hasNotif = true;
    if (androidImplementation != null) {
      hasNotif = await androidImplementation.areNotificationsEnabled() ?? false;
    }

    if (mounted) {
      setState(() {
        _hasFullScreenIntent = hasFullScreen;
        _hasNotificationPermission = hasNotif;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        if (!_hasFullScreenIntent)
          _buildPermissionRow(
            context,
            Icons.screen_lock_portrait_rounded,
            AppColors.red,
            'Lock-Screen Alarm Disabled',
            'Tap to enable Full Screen Intent',
            () async {
              try {
                const platform = MethodChannel('com.smart_synergies_user.app/alarm');
                await platform.invokeMethod('openFullScreenSettings');
              } catch (_) {}
            },
            isDark,
          ),
        if (!_hasFullScreenIntent)
          Divider(height: 1, color: AppColors.getGlassBorder(isDark), indent: 16, endIndent: 16),
          
        if (!_hasNotificationPermission)
          _buildPermissionRow(
            context,
            Icons.notifications_off_rounded,
            AppColors.orange,
            'Notifications Disabled',
            'Tap to allow app notifications',
            () async {
              try {
                const platform = MethodChannel('com.smart_synergies_user.app/alarm');
                await platform.invokeMethod('openNotificationSettings');
              } catch (_) {}
            },
            isDark,
          ),
        if (!_hasNotificationPermission)
          Divider(height: 1, color: AppColors.getGlassBorder(isDark), indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildPermissionRow(BuildContext context, IconData icon, Color c, String title, String sub, VoidCallback onTap, bool isDark) {
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
                        color: c)),
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
}


final logoutLoadingProvider = StateProvider<bool>((ref) => false);

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

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
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blue.withValues(alpha: 0.06),
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
                  color: AppColors.cyan.withValues(alpha: 0.06),
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
                  color: AppColors.blue.withValues(alpha: 0.03),
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
                final sharedWith =
                    (user['sharedWith'] as List<dynamic>?)?.cast<String>() ?? [];
                final bool alertSoundEnabled = user['settings']?['alertSoundEnabled'] ?? true;
                final int aeratorFaultThreshold = user['settings']?['aeratorFaultThreshold'] ?? 2;
                final List<String> mutedDevices = List<String>.from(
                    user['settings']?['mutedDevices'] ?? [])
                    .where((d) => assignedDevices.contains(d))
                    .toList();
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
                              icon: const Icon(Icons.menu_rounded, color: AppColors.cyan, size: 20),
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
                    _settingsSection(context, ref, alertSoundEnabled, aeratorFaultThreshold, assignedDevices, mutedDevices, isDark)
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 500.ms),
                    const SizedBox(height: 12),
                    _logoutBtn(context, ref, isDark).animate().fadeIn(duration: 500.ms, delay: 600.ms),
                  ],
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

  Widget _profileHero(BuildContext context, WidgetRef ref, String name, String email, String role, int totalDevices, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.getSurface(isDark).withValues(alpha: 0.85),
                  AppColors.getBackground(isDark).withValues(alpha: 0.9),
                ]
              : [
                  AppColors.getBackground(isDark),
                  AppColors.getSurface(isDark),
                ],
        ),
        border: Border.all(
          color: isDark
              ? AppColors.cyan.withValues(alpha: 0.15)
              : AppColors.cyan.withValues(alpha: 0.1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.blueGrey.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: [
        Row(children: [
          Stack(children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyan,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0] : 'U',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
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
                    color: AppColors.getSurface(isDark),
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: AppColors.cyan, size: 18),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      tooltip: 'Edit Display Name',
                      onPressed: () => _showEditNameDialog(context, ref, name, isDark),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    role,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.cyan,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: AppColors.getTextMuted(isDark),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.getBackground(isDark).withValues(alpha: 0.4)
                : AppColors.cyan.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.getGlassBorder(isDark).withValues(alpha: 0.1)
                  : AppColors.cyan.withValues(alpha: 0.12),
            ),
          ),
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
            if (trailing != null) trailing,
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
    
    final userState = ref.watch(userProvider).value;
    final customDeviceNames = userState?['customDeviceNames'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getGlassBorder(isDark), width: 1.5),
      ),
      child: Column(
        children: assignedDevices.asMap().entries.map((entry) {
          final idx = entry.key;
          final id = entry.value;
          final deviceState = ref.watch(deviceProvider(id)).value;
          final customName = customDeviceNames?[id];
          final displayName = (customName != null && customName.isNotEmpty)
              ? customName
              : (deviceState?.name != null && deviceState!.name!.isNotEmpty
                  ? deviceState.name!
                  : 'Device $id');

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: idx < assignedDevices.length - 1
                  ? Border(bottom: BorderSide(color: AppColors.getGlassBorder(isDark).withValues(alpha: 0.1), width: 1))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_rounded, color: AppColors.cyan, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.outfit(
                          color: AppColors.getTextPrimary(isDark),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: $id',
                        style: GoogleFonts.outfit(
                          color: AppColors.getTextMuted(isDark),
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
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

  Widget _settingsSection(BuildContext context, WidgetRef ref, bool alertSoundEnabled,
      int aeratorFaultThreshold, List<String> assignedDevices, List<String> mutedDevices, bool isDark) {
    final themeMode = ref.watch(themeProvider);
    final isDarkModeEnabled = themeMode == ThemeMode.dark;
    final bool multiDevice = assignedDevices.length > 1;

    // For multi-device: master toggle reflects whether ALL devices are unmuted
    final bool allUnmuted = mutedDevices.isEmpty;

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
            color: AppColors.getGlassBorder(isDark).withValues(alpha: 0.1),
            indent: 16,
            endIndent: 16),
        // Single device: simple global toggle
        if (!multiDevice)
          _settingRow(context, Icons.volume_up_rounded, AppColors.teal,
              'Sound Alerts', alertSoundEnabled, (val) async {
            final success = await ref.read(userProvider.notifier).updateAlertSound(val);
            if (!success && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to update sound alerts.',
                    style: GoogleFonts.outfit(),
                  ),
                  backgroundColor: AppColors.red,
                ),
              );
            }
          }, isDark)
        else
          // Multi-device: tap to open per-device bottom sheet
          _soundAlertMultiRow(
              context, ref, assignedDevices, mutedDevices, allUnmuted, isDark),
        Divider(
            height: 1,
            color: AppColors.getGlassBorder(isDark).withValues(alpha: 0.1),
            indent: 16,
            endIndent: 16),
        _faultThresholdRow(context, ref, aeratorFaultThreshold, isDark),
        const _PermissionStatusSection(),
      ]),
    );
  }

  Widget _soundAlertMultiRow(BuildContext context, WidgetRef ref,
      List<String> devices, List<String> mutedDevices, bool allUnmuted, bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showDeviceSoundSheet(context, ref, devices, mutedDevices, isDark),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.teal.withValues(alpha: 0.12)),
              child: const Icon(Icons.volume_up_rounded,
                  color: AppColors.teal, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sound Alerts',
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(isDark))),
                  Text(
                    mutedDevices.isEmpty
                        ? 'All devices'
                        : mutedDevices.length == devices.length
                            ? 'All muted'
                            : '${devices.length - mutedDevices.length}/${devices.length} active',
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: mutedDevices.isEmpty
                            ? AppColors.green
                            : AppColors.getTextMuted(isDark),
                        fontWeight: FontWeight.w500),
                  ),
                ],
              )),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.getTextMuted(isDark), size: 20),
        ]),
      ),
    );
  }

  void _showDeviceSoundSheet(BuildContext context, WidgetRef ref,
      List<String> devices, List<String> currentMuted, bool isDark) {
    List<String> pendingMuted = List.from(currentMuted);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.getSurface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                top: 12,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.getTextMuted(isDark).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  Text('Sound Alerts',
                      style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.getTextPrimary(isDark))),
                  const SizedBox(height: 4),
                  Text('Choose which devices trigger alarm sounds',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.getTextMuted(isDark),
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 20),
                  // Device list
                  ...devices.map((deviceId) {
                    final bool isMuted = pendingMuted.contains(deviceId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.getBackground(isDark),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isMuted
                                ? AppColors.getGlassBorder(isDark)
                                : AppColors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(children: [
                          Icon(
                            isMuted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            color: isMuted
                                ? AppColors.getTextMuted(isDark)
                                : AppColors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(deviceId,
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.getTextPrimary(isDark))),
                          ),
                          _SettingAnimatedToggle(
                            value: !isMuted,
                            activeColor: AppColors.green,
                            onChanged: (val) {
                              if (isSaving) return;
                              setSheetState(() {
                                if (val) {
                                  pendingMuted.remove(deviceId);
                                } else {
                                  if (!pendingMuted.contains(deviceId)) {
                                    pendingMuted.add(deviceId);
                                  }
                                }
                              });
                            },
                          ),
                        ]),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyan,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              setSheetState(() => isSaving = true);
                              final success = await ref
                                  .read(userProvider.notifier)
                                  .updateMutedDevices(pendingMuted);
                              if (ctx.mounted) {
                                if (success) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Sound alerts updated successfully!',
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                                      ),
                                      backgroundColor: AppColors.cyan,
                                    ),
                                  );
                                } else {
                                  setSheetState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to update sound alerts.',
                                        style: GoogleFonts.outfit(),
                                      ),
                                      backgroundColor: AppColors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Save',
                              style: GoogleFonts.outfit(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
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
                    final userState = ref.read(userProvider).value;
                    final customDeviceNames = userState?['customDeviceNames'] as Map<String, dynamic>?;
                    final customName = customDeviceNames?[deviceId];
                    final displayName = (customName != null && customName.isNotEmpty)
                        ? customName
                        : (deviceState?.name != null && deviceState!.name!.isNotEmpty
                            ? deviceState.name!
                            : 'Device $deviceId');

                    return Material(
                      key: ValueKey(deviceId),
                      color: Colors.transparent,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.getBackground(isDark),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.getGlassBorder(isDark),
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
                                  const SizedBox(height: 2),
                                  Text(
                                    'ID: $deviceId',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: AppColors.getTextMuted(isDark),
                                      fontWeight: FontWeight.w500,
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
        _SettingAnimatedToggle(
          value: v,
          activeColor: c,
          onChanged: onChanged,
        ),
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

  Widget _faultThresholdRow(BuildContext context, WidgetRef ref, int currentThreshold, bool isDark) {
    return InkWell(
      onTap: () => _showFaultThresholdDialog(context, ref, currentThreshold, isDark),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.orange.withValues(alpha: 0.12)),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.orange, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Aerator Alert Threshold',
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(isDark))),
                Text(
                  'Alert when $currentThreshold or more aerators stop working',
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: AppColors.getTextMuted(isDark)),
                ),
              ])),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.getTextMuted(isDark).withValues(alpha: 0.5)),
        ]),
      ),
    );
  }

  void _showFaultThresholdDialog(BuildContext context, WidgetRef ref, int currentThreshold, bool isDark) {
    int selectedValue = currentThreshold;
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
                'Alert Threshold',
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
                    'Trigger alerts after how many aerators stop working:',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.getTextMuted(isDark),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.getGlassBorder(isDark)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedValue,
                          dropdownColor: AppColors.getSurface(isDark),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                          items: List.generate(10, (index) => index + 1).map((val) {
                            return DropdownMenuItem<int>(
                              value: val,
                              child: Text('$val Aerator${val > 1 ? 's' : ''}'),
                            );
                          }).toList(),
                          onChanged: isSaving
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setDialogState(() => selectedValue = val);
                                  }
                                },
                        ),
                      ),
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
                          setDialogState(() => isSaving = true);
                          final success = await ref
                              .read(userProvider.notifier)
                              .updateAeratorFaultThreshold(selectedValue);
                          setDialogState(() => isSaving = false);
                          if (success && context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Alert threshold updated successfully!',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: AppColors.cyan,
                              ),
                            );
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to update threshold.',
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
}

class _SettingAnimatedToggle extends StatelessWidget {
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;
  const _SettingAnimatedToggle({
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

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
              ? LinearGradient(
                  colors: [activeColor, activeColor.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: value
              ? null
              : AppColors.getBackground(isDark),
          border: Border.all(
            color: value
                ? Colors.transparent
                : AppColors.getGlassBorder(isDark),
            width: 1.0,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
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
                  color: Colors.white,
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
