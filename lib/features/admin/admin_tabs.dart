import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/models/campaign_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/widgets/budget_pill.dart';
import '../../shared/widgets/glowy_card.dart';
import '../../shared/widgets/shimmer_list.dart';
import '../campaigns/campaign_providers.dart';

class CampaignsAdminTab extends ConsumerWidget {
  const CampaignsAdminTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(allCampaignsAdminProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('📋 All Campaigns')),
      body: campaignsAsync.when(
        data: (campaigns) {
          if (campaigns.isEmpty) {
            return Center(
              child: Text('No campaigns yet', style: AppTextStyles.bodyMedium),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(allCampaignsAdminProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: campaigns.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _AdminCampaignTile(campaign: campaigns[i]),
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: ShimmerList(itemCount: 8),
        ),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _AdminCampaignTile extends StatelessWidget {
  final CampaignModel campaign;
  const _AdminCampaignTile({required this.campaign});

  @override
  Widget build(BuildContext context) {
    return GlowyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(campaign.name, style: AppTextStyles.labelLarge),
              ),
              StatusPill(status: campaign.status.name),
            ],
          ),
          const SizedBox(height: 4),
          Text(campaign.brandName ?? 'Unknown Brand',
              style: AppTextStyles.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              BudgetPill(
                remainingPercent: campaign.budgetRemainingPercent,
                walletBalance: campaign.walletBalance,
                compact: true,
              ),
              const Spacer(),
              Text(
                '₹${campaign.payoutRatePer1000}/1K',
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.accentGreen),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Views: ${CurrencyFormatter.compactViews(campaign.metrics.totalViews)}',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final _allUsersProvider =
    FutureProvider<List<UserModel>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final snap = await firestore
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .get();
  return snap.docs.map((d) => UserModel.fromFirestore(d)).toList();
});

final _platformStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final firestore = ref.watch(firestoreProvider);

  // Run all count queries concurrently
  final (
    totalUsersSnap,
    creatorsSnap,
    brandsSnap,
    totalCampaignsSnap,
    activeCampaignsSnap,
    totalPostsSnap,
    pendingWithdrawalsSnap,
  ) = await (
    firestore.collection('users').count().get(),
    firestore
        .collection('users')
        .where('role', isEqualTo: 'creator')
        .count()
        .get(),
    firestore
        .collection('users')
        .where('role', isEqualTo: 'brand')
        .count()
        .get(),
    firestore.collection('campaigns').count().get(),
    firestore
        .collection('campaigns')
        .where('status', isEqualTo: 'active')
        .count()
        .get(),
    firestore.collection('posts').count().get(),
    firestore
        .collection('withdrawal_requests')
        .where('status', isEqualTo: 'pending')
        .count()
        .get(),
  ).wait;

  // Sum views & GMV from campaigns (best effort, limit 500)
  final campaigns = await firestore
      .collection('campaigns')
      .orderBy('createdAt', descending: true)
      .limit(500)
      .get();

  int totalViews = 0;
  int totalGmv = 0;
  for (final doc in campaigns.docs) {
    final d = doc.data();
    totalViews += ((d['metrics']?['totalViews'] ?? 0) as num).toInt();
    totalGmv += ((d['totalSpend'] ?? 0) as num).toInt();
  }

  return {
    'totalUsers': totalUsersSnap.count ?? 0,
    'creators': creatorsSnap.count ?? 0,
    'brands': brandsSnap.count ?? 0,
    'totalCampaigns': totalCampaignsSnap.count ?? 0,
    'activeCampaigns': activeCampaignsSnap.count ?? 0,
    'totalPosts': totalPostsSnap.count ?? 0,
    'pendingWithdrawals': pendingWithdrawalsSnap.count ?? 0,
    'totalViews': totalViews,
    'totalGmv': totalGmv,
  };
});

// ─── Admin Users Tab ──────────────────────────────────────────────────────────
class UsersAdminTab extends ConsumerStatefulWidget {
  const UsersAdminTab({super.key});

  @override
  ConsumerState<UsersAdminTab> createState() => _UsersAdminTabState();
}

class _UsersAdminTabState extends ConsumerState<UsersAdminTab> {
  String _query = '';
  String? _roleFilter; // null = all

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_allUsersProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('👥 Users'),
        actions: [
          usersAsync.when(
            data: (u) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${u.length} users',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textMuted),
                ),
              ),
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or email…',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textMuted),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textMuted),
                        onPressed: () => setState(() => _query = ''),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          // Role filter chips
          SizedBox(
            height: 42,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _roleChip(null, 'All'),
                const SizedBox(width: 8),
                _roleChip('creator', 'Creators'),
                const SizedBox(width: 8),
                _roleChip('brand', 'Brands'),
                const SizedBox(width: 8),
                _roleChip('admin', 'Admins'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: usersAsync.when(
              data: (users) {
                // Apply search + role filter
                final filtered = users.where((u) {
                  final matchesQuery = _query.isEmpty ||
                      u.displayName.toLowerCase().contains(_query) ||
                      u.email.toLowerCase().contains(_query);
                  final matchesRole = _roleFilter == null ||
                      u.role.name == _roleFilter;
                  return matchesQuery && matchesRole;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_search_rounded,
                            size: 56, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text('No users found',
                            style: AppTextStyles.titleMedium),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(_allUsersProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _UserCard(
                      user: filtered[i],
                      onToggleBan: () =>
                          _toggleBan(filtered[i]),
                    ).animate(delay: (i * 20).ms).fadeIn(),
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: ShimmerList(itemCount: 8),
              ),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String? role, String label) {
    final selected = _roleFilter == role;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _roleFilter = role),
      selectedColor: AppColors.accentViolet.withOpacity(0.2),
      checkmarkColor: AppColors.accentViolet,
      side: BorderSide(
        color: selected ? AppColors.accentViolet : AppColors.glassBorder,
      ),
      labelStyle: AppTextStyles.labelSmall.copyWith(
        color:
            selected ? AppColors.accentViolet : AppColors.textSecondary,
      ),
    );
  }

  Future<void> _toggleBan(UserModel user) async {
    final action = user.banned ? 'Unban' : 'Ban';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text('$action ${user.displayName}?'),
        content: Text(
          user.banned
              ? 'Restore access for this user?'
              : 'This will block the user from accessing the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: user.banned
                ? null
                : ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentRed),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final firestore = ref.read(firestoreProvider);
    await firestore
        .collection('users')
        .doc(user.uid)
        .update({'banned': !user.banned});
    unawaited(ref.refresh(_allUsersProvider.future));
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onToggleBan;
  const _UserCard({required this.user, required this.onToggleBan});

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(user.role);
    return GlowyCard(
      glowColor: user.banned
          ? AppColors.accentRed.withOpacity(0.05)
          : roleColor.withOpacity(0.05),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: roleColor.withOpacity(0.15),
            backgroundImage: user.photoURL.isNotEmpty
                ? NetworkImage(user.photoURL)
                : null,
            child: user.photoURL.isEmpty
                ? Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: AppTextStyles.titleMedium
                        .copyWith(color: roleColor),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.displayName.isNotEmpty
                            ? user.displayName
                            : user.email,
                        style: AppTextStyles.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.banned)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accentRed.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('BANNED',
                            style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.accentRed)),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          user.roleLabel.toUpperCase(),
                          style: AppTextStyles.labelSmall
                              .copyWith(color: roleColor),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(user.email,
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  'Joined ${AppDateUtils.timeAgo(user.createdAt)}  •  ₹${user.walletPoints} pts',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          // Ban button
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              user.banned
                  ? Icons.lock_open_rounded
                  : Icons.block_rounded,
              color: user.banned
                  ? AppColors.accentGreen
                  : AppColors.accentRed,
              size: 20,
            ),
            tooltip: user.banned ? 'Unban' : 'Ban',
            onPressed: onToggleBan,
          ),
        ],
      ),
    );
  }

  static Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.creator:
        return AppColors.accentGreen;
      case UserRole.brand:
        return AppColors.accentViolet;
      case UserRole.admin:
        return AppColors.accentAmber;
      default:
        return AppColors.textMuted;
    }
  }
}

// ─── Admin Analytics Tab ──────────────────────────────────────────────────────
class AnalyticsAdminTab extends ConsumerWidget {
  const AnalyticsAdminTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_platformStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('📊 Platform Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refresh(_platformStatsProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: statsAsync.when(
        data: (stats) => RefreshIndicator(
          onRefresh: () => ref.refresh(_platformStatsProvider.future),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Users', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Total Users',
                        value: stats['totalUsers'].toString(),
                        icon: Icons.people_outline,
                        accentColor: AppColors.accentViolet,
                        subtitle:
                            '${stats['creators']} creators · ${stats['brands']} brands',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        label: 'Creators',
                        value: stats['creators'].toString(),
                        icon: Icons.person_outline_rounded,
                        accentColor: AppColors.accentGreen,
                      ),
                    ),
                  ],
                ).animate().fadeIn(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Brands',
                        value: stats['brands'].toString(),
                        icon: Icons.business_center_outlined,
                        accentColor: AppColors.accentAmber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        label: 'Pending Payouts',
                        value: stats['pendingWithdrawals'].toString(),
                        icon: Icons.payments_outlined,
                        accentColor: AppColors.accentRed,
                      ),
                    ),
                  ],
                ).animate(delay: 60.ms).fadeIn(),
                const SizedBox(height: 24),
                Text('Campaigns', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Total Campaigns',
                        value: stats['totalCampaigns'].toString(),
                        icon: Icons.campaign_outlined,
                        accentColor: AppColors.accentViolet,
                        subtitle:
                            '${stats['activeCampaigns']} active',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        label: 'Total Posts',
                        value: CurrencyFormatter.compactViews(
                            stats['totalPosts'] as int),
                        icon: Icons.article_outlined,
                        accentColor: AppColors.accentGreen,
                      ),
                    ),
                  ],
                ).animate(delay: 120.ms).fadeIn(),
                const SizedBox(height: 24),
                Text('Performance', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Total Views',
                        value: CurrencyFormatter.compactViews(
                            stats['totalViews'] as int),
                        icon: Icons.visibility_outlined,
                        accentColor: AppColors.accentAmber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        label: 'Platform GMV',
                        value: CurrencyFormatter.compact(
                            (stats['totalGmv'] as int).toDouble()),
                        icon: Icons.currency_rupee,
                        accentColor: AppColors.accentGreen,
                      ),
                    ),
                  ],
                ).animate(delay: 180.ms).fadeIn(),
                const SizedBox(height: 24),
                GlowyCard(
                  glowColor: AppColors.accentViolet.withOpacity(0.05),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.textMuted, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Views & GMV are summed from the latest 500 campaigns. '  
                          'Refresh to update.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 240.ms).fadeIn(),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.accentRed),
              const SizedBox(height: 12),
              Text('Failed to load analytics', style: AppTextStyles.titleMedium),
              const SizedBox(height: 6),
              Text('$e', style: AppTextStyles.bodySmall),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(_platformStatsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String? subtitle;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.glassCard(
          glowColor: accentColor.withOpacity(0.08)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: AppTextStyles.displayMedium
                  .copyWith(color: accentColor)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }
}
