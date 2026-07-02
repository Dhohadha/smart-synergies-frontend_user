import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../widgets/glass_card.dart';

class ShareAccessScreen extends ConsumerStatefulWidget {
  const ShareAccessScreen({super.key});

  @override
  ConsumerState<ShareAccessScreen> createState() => _ShareAccessScreenState();
}

class _ShareAccessScreenState extends ConsumerState<ShareAccessScreen> {
  final _emailController = TextEditingController();
  bool _isSharing = false;
  final Set<String> _selectedDevices = {};

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.outfit()),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.cyan,
    ));
  }

  void _showLoadingDialog(String message, bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppColors.getBackground(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Row(
            children: [
              const CircularProgressIndicator(color: AppColors.cyan),
              const SizedBox(width: 20),
              Text(
                message,
                style: GoogleFonts.outfit(
                  color: AppColors.getTextPrimary(isDark),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBlockedDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required bool isDark,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.getBackground(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.outfit(
            color: AppColors.getTextSecondary(isDark),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.outfit(
                color: AppColors.cyan,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog({
    required String email,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget bodyContent,
    required bool isDark,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.getBackground(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
            ),
          ],
        ),
        content: bodyContent,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: GoogleFonts.outfit(
                color: AppColors.getTextMuted(isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _doShare(email);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              'YES, SEND INVITE',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleShare() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      _showSnack('Please enter a valid email address.');
      return;
    }

    if (_selectedDevices.isEmpty) {
      _showSnack('Please select at least one device to share.');
      return;
    }

    _showLoadingDialog('Verifying email...', isDark);

    final result = await ref.read(userProvider.notifier).verifyEmailToShare(email);

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    final status = result['status'] as String? ?? 'error';

    switch (status) {
      case 'no_permission':
        _showBlockedDialog(
          icon: Icons.block,
          iconColor: AppColors.red,
          title: 'Not Allowed',
          message: result['message'] ?? 'Shared users cannot share access with others.',
          isDark: isDark,
        );
        break;

      case 'self':
        _showBlockedDialog(
          icon: Icons.person_off,
          iconColor: AppColors.red,
          title: 'Cannot Share',
          message: result['message'] ?? 'You cannot share access with your own account.',
          isDark: isDark,
        );
        break;

      case 'already_shared':
        _showBlockedDialog(
          icon: Icons.check_circle_outline,
          iconColor: Colors.orange,
          title: 'Already Shared',
          message: result['message'] ?? 'You have already shared access with this email.',
          isDark: isDark,
        );
        break;

      case 'declined_can_reshare':
        _showConfirmDialog(
          email: email,
          title: 'Reshare Access?',
          icon: Icons.replay_rounded,
          iconColor: Colors.orange,
          isDark: isDark,
          bodyContent: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_outlined, color: AppColors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result['message'] ?? 'This user declined your previous invite.',
                        style: GoogleFonts.outfit(fontSize: 12, color: AppColors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Resend ${_selectedDevices.length} device(s) invite to $email?',
                style: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark), fontSize: 13),
              ),
            ],
          ),
        );
        break;

      case 'is_owner':
        _showBlockedDialog(
          icon: Icons.block,
          iconColor: AppColors.red,
          title: 'Cannot Share',
          message: result['message'] ?? 'You cannot share access with another owner.',
          isDark: isDark,
        );
        break;

      case 'error':
        _showSnack(result['message'] ?? 'An error occurred. Please try again.');
        break;

      case 'new_user':
        _showConfirmDialog(
          email: email,
          title: 'Send Invite?',
          icon: Icons.person_add,
          iconColor: AppColors.cyan,
          isDark: isDark,
          bodyContent: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result['message'] ?? '',
                style: GoogleFonts.outfit(color: AppColors.getTextSecondary(isDark)),
              ),
              const SizedBox(height: 12),
              Text(
                'An invite will be created for this email. They will see it when they sign into the app.',
                style: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark), fontSize: 13),
              ),
            ],
          ),
        );
        break;

      case 'ok':
        final name = result['name'] as String? ?? email;
        final sharedByOther = result['sharedByOtherOwner'] == true;
        final otherOwner = result['otherOwnerEmail'] as String? ?? '';

        _showConfirmDialog(
          email: email,
          title: 'Confirm Sharing',
          icon: Icons.person,
          iconColor: AppColors.cyan,
          isDark: isDark,
          bodyContent: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user, color: AppColors.green, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'User found: $name',
                      style: GoogleFonts.outfit(
                        color: AppColors.getTextPrimary(isDark),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (sharedByOther) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Already managed by $otherOwner. They can still receive your invite.',
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Share ${_selectedDevices.length} device(s) with $email?',
                style: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark), fontSize: 13),
              ),
            ],
          ),
        );
        break;
    }
  }

  Future<void> _doShare(String email) async {
    setState(() => _isSharing = true);
    final success = await ref.read(userProvider.notifier).shareAccess(email, _selectedDevices.toList());
    setState(() => _isSharing = false);

    if (!mounted) return;

    if (success) {
      _showSnack('Invite sent successfully to $email!');
      _emailController.clear();
      setState(() => _selectedDevices.clear());
      ref.read(userProvider.notifier).fetchUserProfile();
    } else {
      _showSnack('Failed to send invite. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: Text('Share Access', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.getTextPrimary(isDark),
      ),
      body: userProfile.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.cyan)),
        error: (err, _) => Center(child: Text('Error loading devices: $err', style: GoogleFonts.outfit(color: AppColors.red))),
        data: (profile) {
          if (profile == null) {
            return Center(child: Text('No profile found.', style: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark))));
          }

          final allDevices = List<String>.from(profile['assignedDevices'] ?? []);

          if (allDevices.length == 1 && _selectedDevices.isEmpty) {
            Future.microtask(() {
              if (mounted) setState(() => _selectedDevices.add(allDevices.first));
            });
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.15)),
                      ),
                      child: const Icon(Icons.share_rounded, size: 64, color: AppColors.cyan),
                    ),
                  ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 24),
                  Text(
                    'Share Device Access',
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.getTextPrimary(isDark)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select the devices and enter the email of the person you want to give access to.',
                    style: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  if (allDevices.isNotEmpty) ...[
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Select Devices:',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.getTextPrimary(isDark)),
                              ),
                              Row(
                                children: [
                                  Text('Select All', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.getTextMuted(isDark))),
                                  Checkbox(
                                    value: _selectedDevices.length == allDevices.length && allDevices.isNotEmpty,
                                    activeColor: AppColors.cyan,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedDevices.addAll(allDevices);
                                        } else {
                                          _selectedDevices.clear();
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(),
                          ...allDevices.map(
                            (deviceId) => CheckboxListTile(
                              title: Text(deviceId, style: GoogleFonts.outfit(color: AppColors.getTextPrimary(isDark), fontSize: 13)),
                              value: _selectedDevices.contains(deviceId),
                              activeColor: AppColors.cyan,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedDevices.add(deviceId);
                                  } else {
                                    _selectedDevices.remove(deviceId);
                                  }
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Recipient Gmail',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                      ),
                    ),
                  ),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.outfit(color: AppColors.getTextPrimary(isDark), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'example@gmail.com',
                      hintStyle: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark)),
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.cyan),
                      filled: true,
                      fillColor: AppColors.getSurface(isDark),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.cyan.withValues(alpha: 0.15)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.cyan.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.cyan, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSharing ? null : _handleShare,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyan,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSharing
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Share Access', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'People with Access',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
                  ),
                  const Divider(height: 24),
                  _SharedUsersList(
                    ownerEmail: profile['email'] as String,
                    onRevoke: () => ref.read(userProvider.notifier).refreshProfileQuietly(),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SharedUsersList extends StatefulWidget {
  final String ownerEmail;
  final VoidCallback onRevoke;
  final bool isDark;

  const _SharedUsersList({
    required this.ownerEmail,
    required this.onRevoke,
    required this.isDark,
  });

  @override
  State<_SharedUsersList> createState() => _SharedUsersListState();
}

class _SharedUsersListState extends State<_SharedUsersList> {
  final Set<String> _revoking = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
  }

  Future<void> _revoke(WidgetRef ref, String email) async {
    setState(() => _revoking.add(email));
    final success = await ref.read(userProvider.notifier).revokeAccess(email);
    if (!mounted) return;
    if (success) {
      setState(() {
        _revoking.remove(email);
      });
      widget.onRevoke();
    } else {
      setState(() => _revoking.remove(email));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to revoke access.', style: GoogleFonts.outfit()),
        backgroundColor: AppColors.red,
      ));
    }
  }

  void _showEditDevicesDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> user,
    List<String> ownerDevices,
  ) {
    final email = user['email'] as String;
    final currentlyShared = List<String>.from(user['devices'] ?? []);
    final selected = Set<String>.from(currentlyShared);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.getBackground(widget.isDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.edit_outlined, color: AppColors.cyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Edit Shared Devices',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(widget.isDark),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select devices for $email:',
                      style: GoogleFonts.outfit(
                        color: AppColors.getTextSecondary(widget.isDark),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (ownerDevices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'You have no assigned devices to share.',
                          style: GoogleFonts.outfit(
                            color: AppColors.getTextMuted(widget.isDark),
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: ownerDevices.map((deviceId) {
                            final isChecked = selected.contains(deviceId);
                            return CheckboxListTile(
                              title: Text(
                                deviceId,
                                style: GoogleFonts.outfit(
                                  color: AppColors.getTextPrimary(widget.isDark),
                                  fontSize: 13,
                                ),
                              ),
                              value: isChecked,
                              activeColor: AppColors.cyan,
                              onChanged: isSaving
                                  ? null
                                  : (val) {
                                      setDialogState(() {
                                        if (val == true) {
                                          selected.add(deviceId);
                                        } else {
                                          selected.remove(deviceId);
                                        }
                                      });
                                    },
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.outfit(
                      color: AppColors.getTextMuted(widget.isDark),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final success = await ref
                              .read(userProvider.notifier)
                              .updateSharedDevices(email, selected.toList());
                          if (!context.mounted) return;
                          setDialogState(() => isSaving = false);
                          
                          if (success) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Devices updated successfully for $email!', style: GoogleFonts.outfit()),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.cyan,
                            ));
                            widget.onRevoke();
                            setState(() {});
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Failed to update devices.', style: GoogleFonts.outfit()),
                              backgroundColor: AppColors.red,
                            ));
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
                        )
                      : Text(
                          'SAVE',
                          style: GoogleFonts.outfit(
                            color: AppColors.cyan,
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

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final userProfile = ref.watch(userProvider);
        final ownerDevices = userProfile.maybeWhen(
          data: (profile) => List<String>.from(profile?['assignedDevices'] ?? []),
          orElse: () => <String>[],
        );

        // Fetch shared details asynchronously
        return FutureBuilder<List<dynamic>>(
          future: ref.read(userProvider.notifier).getSharedDetails(widget.ownerEmail),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(color: AppColors.cyan)),
              );
            }
            if (snapshot.data!.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('No users shared yet.', style: GoogleFonts.outfit(color: AppColors.getTextMuted(widget.isDark), fontSize: 13)),
              );
            }
            return Column(
              children: snapshot.data!.map((user) {
                final status = user['status'] as String;
                final isPending = status == 'Pending';
                final isDeclined = status == 'Declined';

                final email = user['email'] as String;
                final isRevoking = _revoking.contains(email);
                final uDevices = List<String>.from(user['devices'] ?? []);

                Color statusColor = AppColors.green;
                if (isPending) statusColor = Colors.orange;
                if (isDeclined) statusColor = AppColors.red;

                Color avatarBg = AppColors.cyan.withValues(alpha: 0.12);
                Color avatarIcon = AppColors.cyan;
                if (isPending) {
                  avatarBg = AppColors.cyan.withValues(alpha: 0.05);
                  avatarIcon = AppColors.getTextMuted(widget.isDark);
                }
                if (isDeclined) {
                  avatarBg = AppColors.red.withValues(alpha: 0.08);
                  avatarIcon = AppColors.red;
                }

                return GlassCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: avatarBg,
                        child: Icon(
                          isDeclined ? Icons.person_off : Icons.person,
                          size: 20,
                          color: avatarIcon,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              email,
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.getTextPrimary(widget.isDark)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${user['role']} • $status',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Devices: ${uDevices.isEmpty ? 'None' : uDevices.join(', ')}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.getTextSecondary(widget.isDark),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isRevoking)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.red))
                      else if (isDeclined) ...[
                        _ReshareButton(
                          ownerEmail: widget.ownerEmail,
                          sharedEmail: email,
                          ownerDevices: ownerDevices,
                          isDark: widget.isDark,
                          onReshared: () {
                            widget.onRevoke();
                            setState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_remove_outlined, color: AppColors.red, size: 20),
                          tooltip: 'Remove access',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: AppColors.getBackground(widget.isDark),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text(
                                  'Remove Access',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(widget.isDark), fontSize: 16),
                                ),
                                content: Text(
                                  'Remove $email\'s access to your devices?',
                                  style: GoogleFonts.outfit(color: AppColors.getTextSecondary(widget.isDark), fontSize: 14),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: Text('CANCEL', style: GoogleFonts.outfit(color: AppColors.getTextMuted(widget.isDark))),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: Text(
                                      'REMOVE',
                                      style: GoogleFonts.outfit(color: AppColors.red, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ) ?? false;
                            if (confirmed) _revoke(ref, email);
                          },
                        ),
                      ]
                      else ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: AppColors.cyan, size: 20),
                          tooltip: 'Edit shared devices',
                          onPressed: () => _showEditDevicesDialog(context, ref, user, ownerDevices),
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_remove_outlined, color: AppColors.red, size: 20),
                          tooltip: 'Remove access',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: AppColors.getBackground(widget.isDark),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text(
                                  'Remove Access',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(widget.isDark), fontSize: 16),
                                ),
                                content: Text(
                                  'Remove $email\'s access to your devices?',
                                  style: GoogleFonts.outfit(color: AppColors.getTextSecondary(widget.isDark), fontSize: 14),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: Text('CANCEL', style: GoogleFonts.outfit(color: AppColors.getTextMuted(widget.isDark))),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: Text(
                                      'REMOVE',
                                      style: GoogleFonts.outfit(color: AppColors.red, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ) ?? false;
                            if (confirmed) _revoke(ref, email);
                          },
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _ReshareButton extends ConsumerStatefulWidget {
  final String ownerEmail;
  final String sharedEmail;
  final List<String> ownerDevices;
  final bool isDark;
  final VoidCallback onReshared;

  const _ReshareButton({
    required this.ownerEmail,
    required this.sharedEmail,
    required this.ownerDevices,
    required this.isDark,
    required this.onReshared,
  });

  @override
  ConsumerState<_ReshareButton> createState() => _ReshareButtonState();
}

class _ReshareButtonState extends ConsumerState<_ReshareButton> {
  bool _isLoading = false;

  Future<void> _reshare() async {
    setState(() => _isLoading = true);
    try {
      final success = await ref
          .read(userProvider.notifier)
          .shareAccess(widget.sharedEmail, widget.ownerDevices);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Invite resent to ${widget.sharedEmail}!', style: GoogleFonts.outfit()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.cyan,
        ));
        widget.onReshared();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to reshare. Please try again.', style: GoogleFonts.outfit()),
          backgroundColor: AppColors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
            ),
          )
        : IconButton(
            icon: const Icon(Icons.replay_rounded, color: Colors.orange, size: 20),
            tooltip: 'Reshare access',
            onPressed: _reshare,
          );
  }
}
