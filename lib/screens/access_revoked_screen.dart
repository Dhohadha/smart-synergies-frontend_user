import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/confirmation_dialog.dart';

final revInvitesLoadingProvider = StateProvider<bool>((ref) => false);
final revSignoutLoadingProvider = StateProvider<bool>((ref) => false);

class AccessRevokedScreen extends ConsumerStatefulWidget {
  final String? revokedBy;

  const AccessRevokedScreen({super.key, this.revokedBy});

  @override
  ConsumerState<AccessRevokedScreen> createState() => _AccessRevokedScreenState();
}

class _AccessRevokedScreenState extends ConsumerState<AccessRevokedScreen> {
  final Set<String> _processingInvites = {};

  Future<void> _signOut() async {
    final confirm = await ConfirmationDialog.show(
      context: context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
      icon: Icons.logout_rounded,
      isDestructive: true,
    );
    if (confirm != true) return;

    ref.read(revSignoutLoadingProvider.notifier).state = true;
    try {
      await ref.read(authProvider.notifier).signOut();
    } finally {
      if (mounted) ref.read(revSignoutLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoggingOut = ref.watch(revSignoutLoadingProvider);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: SafeArea(
        child: userProfileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.cyan)),
          error: (err, _) => Center(child: Text('Error loading details: $err', style: GoogleFonts.outfit(color: AppColors.red))),
          data: (profile) {
            final invitations = (profile?['pendingInvitations'] as List<dynamic>? ?? [])
                .where((i) => (i['status'] ?? 'pending') != 'declined')
                .toList();

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.red.withValues(alpha: 0.15), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.red.withValues(alpha: 0.05),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.no_accounts_rounded,
                        size: 80,
                        color: AppColors.red,
                      ),
                    ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 32),
                    Text(
                      'Access Removed',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.getTextPrimary(isDark),
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                    const SizedBox(height: 16),
                    Text(
                      widget.revokedBy != null
                          ? 'Your access to this dashboard has been removed by ${widget.revokedBy}.'
                          : 'Your access to this dashboard has been removed by the owner.',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: AppColors.getTextMuted(isDark),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
                    const SizedBox(height: 48),
                    
                    if (invitations.isNotEmpty) ...[
                      const Divider(height: 32),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'New Access Requests',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.cyan,
                          ),
                        ),
                      ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
                      const SizedBox(height: 16),
                      ...invitations.map((invite) => _buildInvitationItem(context, Map<String, dynamic>.from(invite), isDark)
                          .animate()
                          .fadeIn(duration: 500.ms, delay: 500.ms)),
                      const SizedBox(height: 24),
                      const Divider(height: 32),
                    ],

                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: isLoggingOut ? null : _signOut,
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
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.logout_rounded, color: AppColors.red, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Sign Out',
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.red,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 600.ms),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInvitationItem(BuildContext context, Map<String, dynamic> invite, bool isDark) {
    final ownerEmail = invite['ownerEmail'] as String;
    final isProcessing = _processingInvites.contains(ownerEmail);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.cyan.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.share, color: AppColors.cyan, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Synergies Share',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'From: $ownerEmail',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.getTextMuted(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: isProcessing ? null : () async {
                  final confirm = await ConfirmationDialog.show(
                    context: context,
                    title: 'Decline Request',
                    message: 'Are you sure you want to decline the access request from $ownerEmail?',
                    confirmLabel: 'Decline',
                    icon: Icons.close_rounded,
                    isDestructive: true,
                  );
                  if (confirm != true) return;

                  setState(() => _processingInvites.add(ownerEmail));
                  try {
                    final success = await ref.read(userProvider.notifier).declineInvitation(ownerEmail);
                    if (success) {
                      ref.read(userProvider.notifier).fetchUserProfile();
                    }
                  } finally {
                    if (mounted) setState(() => _processingInvites.remove(ownerEmail));
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
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: isProcessing ? null : () async {
                  final confirm = await ConfirmationDialog.show(
                    context: context,
                    title: 'Accept Request',
                    message: 'Are you sure you want to accept the access request from $ownerEmail?',
                    confirmLabel: 'Accept',
                    icon: Icons.check_rounded,
                    iconColor: AppColors.green,
                  );
                  if (confirm != true) return;

                  setState(() => _processingInvites.add(ownerEmail));
                  try {
                    final success = await ref.read(userProvider.notifier).acceptInvitation(ownerEmail);
                    if (success) {
                      ref.read(userProvider.notifier).fetchUserProfile();
                    }
                  } finally {
                    if (mounted) setState(() => _processingInvites.remove(ownerEmail));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: isProcessing 
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Accept', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
