import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/control_tab.dart';
import 'tabs/profile_tab.dart';
import '../widgets/confirmation_dialog.dart';

import '../../providers/user_provider.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentTab = 0;
  bool _isInviteDialogShowing = false;
  bool _hasPromptedName = false;

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

  void _onTabTap(int index) {
    setState(() => _currentTab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _showInvitationDialog(BuildContext context, Map<String, dynamic> invite, bool isDark) {
    if (_isInviteDialogShowing) return;
    _isInviteDialogShowing = true;

    final ownerEmail = invite['ownerEmail'] as String? ?? '';
    final ownerName = invite['ownerName'] as String? ?? 'An owner';
    final invitedDevices = (invite['devices'] as List<dynamic>? ?? []).cast<String>();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.getBackground(isDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.share_rounded, color: AppColors.cyan, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Access Request',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$ownerName wants to share access to their devices with you.',
                    style: GoogleFonts.outfit(
                      color: AppColors.getTextSecondary(isDark),
                      fontSize: 14,
                    ),
                  ),
                  if (invitedDevices.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Devices:',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...invitedDevices.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.developer_board_rounded, color: AppColors.cyan, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              d,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppColors.getTextSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Owner email: $ownerEmail',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.getTextMuted(isDark),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing
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

                          setDialogState(() => isProcessing = true);
                          try {
                            final success = await ref
                                .read(userProvider.notifier)
                                .declineInvitation(ownerEmail);
                            if (success && context.mounted) {
                              Navigator.pop(context);
                            }
                          } finally {
                            setDialogState(() => isProcessing = false);
                          }
                        },
                  child: Text(
                    'Decline',
                    style: GoogleFonts.outfit(
                      color: AppColors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isProcessing
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

                          setDialogState(() => isProcessing = true);
                          try {
                            final success = await ref
                                .read(userProvider.notifier)
                                .acceptInvitation(ownerEmail);
                            if (success && context.mounted) {
                              Navigator.pop(context);
                            }
                          } finally {
                            setDialogState(() => isProcessing = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyan,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: isProcessing
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
            );
          },
        );
      },
    ).then((_) {
      _isInviteDialogShowing = false;
    });
  }

  void _showNamePromptDialog(BuildContext context, String currentName, bool isDark) {
    // Clear field if default splits/placeholders are currentName
    final controller = TextEditingController(
      text: (currentName == 'Shared User' || currentName.contains('@') || currentName == 'User' || currentName == 'N/A')
          ? ''
          : currentName,
    );
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PopScope(
              canPop: false,
              child: AlertDialog(
                backgroundColor: AppColors.getSurface(isDark),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Row(
                  children: [
                    const Icon(Icons.badge_outlined, color: AppColors.cyan, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'What is your name?',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Please enter your display name to complete your profile setup.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.getTextMuted(isDark),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: GoogleFonts.outfit(color: AppColors.getTextPrimary(isDark)),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Your Name',
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
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final enteredName = controller.text.trim();
                            if (enteredName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please enter a valid name.', style: GoogleFonts.outfit()),
                                  backgroundColor: AppColors.red,
                                ),
                              );
                              return;
                            }
                            
                            setDialogState(() => isSaving = true);
                            final success = await ref.read(userProvider.notifier).updateProfileName(enteredName);
                            setDialogState(() => isSaving = false);
                            
                            if (success && context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Profile setup complete! Welcome, $enteredName.', style: GoogleFonts.outfit()),
                                  backgroundColor: AppColors.cyan,
                                ),
                              );
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update name. Please try again.', style: GoogleFonts.outfit()),
                                  backgroundColor: AppColors.red,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Save and Continue',
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Listen for invitations and name setup
    ref.listen<AsyncValue<Map<String, dynamic>?>>(userProvider, (previous, next) {
      next.whenData((profile) {
        if (profile != null) {
          // 1. Invitations Check
          final invitations = (profile['pendingInvitations'] as List<dynamic>? ?? [])
              .where((i) => (i['status'] ?? 'pending') != 'declined')
              .toList();
          if (invitations.isNotEmpty) {
            _showInvitationDialog(context, Map<String, dynamic>.from(invitations.first), isDark);
          }

          // 2. Name Setup Check
          final name = profile['name'] as String? ?? '';
          final email = profile['email'] as String? ?? '';
          final defaultName = email.split('@')[0];

          if (!_hasPromptedName && (name.isEmpty || name == defaultName || name == 'Shared User' || name == 'User' || name == 'N/A' || name == email)) {
            _hasPromptedName = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showNamePromptDialog(context, name, isDark);
            });
          }
        }
      });
    });
    
    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [DashboardTab(), ControlTab(), ProfileTab()],
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1426) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.dashboard_rounded, 'Dashboard', isDark),
              _navItem(1, Icons.power_settings_new_rounded, 'Control', isDark),
              _navItem(2, Icons.person_rounded, 'Profile', isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, bool isDark) {
    final isActive = _currentTab == index;
    final targetColor = isActive ? AppColors.cyan : AppColors.getTextMuted(isDark);

    return GestureDetector(
      onTap: () => _onTabTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: targetColor),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          builder: (context, color, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: color,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  width: isActive ? 16 : 0,
                  height: 2.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1.2),
                    color: isActive ? AppColors.cyan : Colors.transparent,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
