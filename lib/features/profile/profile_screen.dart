import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/user_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../shared/widgets/glowy_card.dart';
import '../../shared/widgets/stat_row.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserDataProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Avatar + name
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accentViolet,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentViolet.withOpacity(0.3),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: user?.photoURL != null
                            ? Image.network(
                                user!.photoURL,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.person_rounded,
                                        size: 48),
                              )
                            : const Icon(Icons.person_rounded, size: 48),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.displayName ?? 'User',
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentViolet.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.accentViolet.withOpacity(0.3)),
                      ),
                      child: Text(
                        user?.roleLabel ?? 'Creator',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.accentViolet,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
              ),

              const SizedBox(height: 24),

              // Stats
              if (user?.isBrand == false) ...[
                GlowyCard(
                  glowColor: AppColors.accentGreen.withOpacity(0.08),
                  child: Column(
                    children: [
                      StatRow(
                        icon: Icons.stars_rounded,
                        label: 'Wallet Points',
                        value: CurrencyFormatter.fromPoints(
                            user?.walletPoints ?? 0),
                        iconColor: AppColors.accentGreen,
                        valueColor: AppColors.accentGreen,
                      ),
                      StatRow(
                        icon: Icons.people_outline,
                        label: 'Followers',
                        value: CurrencyFormatter.compactViews(
                            user?.onboarding?.followers ?? 0),
                      ),
                      StatRow(
                        icon: Icons.link_rounded,
                        label: 'Social Platforms',
                        value: (user?.onboarding?.socialLinks ?? {})
                            .length
                            .toString(),
                        isLast: true,
                      ),
                    ],
                  ),
                ).animate(delay: 100.ms).fadeIn(),
                const SizedBox(height: 16),
              ],

              // Quick links
              GlowyCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    _ProfileTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Wallet',
                      onTap: () => context.go('/wallet'),
                    ),
                    _ProfileTile(
                      icon: Icons.receipt_long_outlined,
                      label: 'Transaction History',
                      onTap: () => context.push('/wallet/history'),
                    ),
                    if (user?.isAdmin == true)
                      _ProfileTile(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Admin Panel',
                        iconColor: AppColors.accentAmber,
                        onTap: () => context.go('/admin/flags'),
                      ),
                    _ProfileTile(
                      icon: Icons.logout_rounded,
                      label: 'Sign Out',
                      iconColor: AppColors.accentRed,
                      onTap: () => _signOut(ref, context),
                      isLast: true,
                    ),
                  ],
                ),
              ).animate(delay: 150.ms).fadeIn(),
            ],
          ),
        ),
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, s) => const SizedBox(),
      ),
    );
  }

  Future<void> _signOut(WidgetRef ref, BuildContext context) async {
    await ref.read(authNotifierProvider.notifier).signOut();
    if (context.mounted) context.go('/login');
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool isLast;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon,
              color: iconColor ?? AppColors.textSecondary, size: 22),
          title: Text(label, style: AppTextStyles.bodyMedium),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 18),
          onTap: onTap,
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: AppColors.glassBorder),
          ),
      ],
    );
  }
}
