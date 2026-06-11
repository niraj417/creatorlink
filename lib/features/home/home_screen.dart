import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/user_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../shared/models/campaign_model.dart';
import '../../shared/models/post_model.dart';
import '../../shared/widgets/budget_pill.dart';
import '../../shared/widgets/glowy_card.dart';
import '../../shared/widgets/shimmer_list.dart';
import '../campaigns/campaign_providers.dart';


class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserDataProvider);

    return userAsync.when(
      data: (user) {
        if (user?.isBrand == true) return const _BrandHome();
        return const _CreatorHome();
      },
      loading: () => const _CreatorHome(),
      error: (e, s) => const _CreatorHome(),
    );
  }
}

// ─── Creator Home ─────────────────────────────────────────────────────────────
class _CreatorHome extends ConsumerWidget {
  const _CreatorHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserDataProvider);
    final campaignsAsync = ref.watch(activeCampaignsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentViolet,
          backgroundColor: AppColors.surfaceElevated,
          onRefresh: () => ref.refresh(activeCampaignsProvider.future),
          child: CustomScrollView(
            slivers: [
              // ─── Header ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            userAsync.when(
                              data: (user) => Text(
                                'Hey ${user?.displayName.split(' ').first ?? 'Creator'} 👋',
                                style: AppTextStyles.titleLarge,
                              ),
                              loading: () => const ShimmerLine(width: 160, height: 20),
                              error: (e, s) => const SizedBox(),
                            ),
                            const SizedBox(height: 4),
                            Text('Find your next campaign', style: AppTextStyles.bodyMedium),
                          ],
                        ),
                      ),
                      // Wallet points
                      userAsync.when(
                        data: (user) => GlowyCard(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          glowColor: AppColors.accentGreen.withValues(alpha: 0.2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars_rounded,
                                  size: 16, color: AppColors.accentGreen),
                              const SizedBox(width: 6),
                              Text(
                                CurrencyFormatter.fromPoints(user?.walletPoints ?? 0),
                                style: AppTextStyles.labelLarge
                                    .copyWith(color: AppColors.accentGreen),
                              ),
                            ],
                          ),
                        ),
                        loading: () => const ShimmerCard(width: 80, height: 36),
                        error: (e, s) => const SizedBox(),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ─── Featured Campaigns Carousel ───────────────────────
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Active Campaigns', style: AppTextStyles.titleMedium),
                          TextButton(
                            onPressed: () => context.go('/campaigns'),
                            child: const Text('See all'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    campaignsAsync.when(
                      data: (campaigns) => SizedBox(
                        height: 190,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: campaigns.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (ctx, i) => CampaignCard(
                            campaign: campaigns[i],
                            index: i,
                          ),
                        ),
                      ),
                      loading: () => const ShimmerCarousel(),
                      error: (e, s) => Center(
                        child: Text('Error loading campaigns', style: AppTextStyles.bodyMedium),
                      ),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ─── Quick Stats ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Activity', style: AppTextStyles.titleMedium),
                      const SizedBox(height: 12),
                      Builder(builder: (context) {
                        final postsAsync = ref.watch(creatorPostsProvider);
                        return postsAsync.when(
                          data: (posts) {
                            final active = posts
                                .where((p) =>
                                    p.status == PostStatus.approved ||
                                    p.status == PostStatus.pendingReview)
                                .length;
                            final totalViews = posts.fold<int>(
                                0, (sum, p) => sum + p.views);
                            return Row(
                              children: [
                                Expanded(
                                  child: _QuickStatCard(
                                    icon: Icons.article_outlined,
                                    label: 'Active Posts',
                                    value: '$active',
                                    color: AppColors.accentViolet,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _QuickStatCard(
                                    icon: Icons.visibility_outlined,
                                    label: 'Total Views',
                                    value: CurrencyFormatter.compactViews(totalViews),
                                    color: AppColors.accentGreen,
                                  ),
                                ),
                              ],
                            );
                          },
                          loading: () => const ShimmerList(itemCount: 1, itemHeight: 72),
                          error: (_, __) => const Row(
                            children: [
                              Expanded(
                                child: _QuickStatCard(
                                  icon: Icons.article_outlined,
                                  label: 'Active Posts',
                                  value: '—',
                                  color: AppColors.accentViolet,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _QuickStatCard(
                                  icon: Icons.visibility_outlined,
                                  label: 'Total Views',
                                  value: '—',
                                  color: AppColors.accentGreen,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ).animate(delay: 200.ms).fadeIn(),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),

            ],
          ),
        ),
      ),
    );
  }
}

// ─── Brand Home ───────────────────────────────────────────────────────────────
class _BrandHome extends ConsumerWidget {
  const _BrandHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserDataProvider);
    final brandCampaignsAsync = ref.watch(brandCampaignsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentViolet,
          backgroundColor: AppColors.surfaceElevated,
          onRefresh: () => ref.refresh(brandCampaignsProvider.future),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      userAsync.when(
                        data: (user) => Text(
                          'Welcome, ${user?.onboarding?.companyName ?? user?.displayName ?? 'Brand'} 🏢',
                          style: AppTextStyles.titleLarge,
                        ),
                        loading: () => const ShimmerLine(width: 200, height: 22),
                        error: (e, s) => const SizedBox(),
                      ),
                      const SizedBox(height: 4),
                      Text('Manage your campaigns', style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Campaign carousel + New campaign card
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 190,
                  child: brandCampaignsAsync.when(
                    data: (campaigns) => ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: campaigns.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (ctx, i) {
                        if (i == campaigns.length) {
                          return _NewCampaignCard(
                            onTap: () => context.push('/campaigns/create'),
                          );
                        }
                        return CampaignCard(campaign: campaigns[i], index: i);
                      },
                    ),
                    loading: () => const ShimmerCarousel(),
                    error: (e, s) => const Center(child: Text('Error')),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Campaign Card (horizontal carousel item) ─────────────────────────────────
class CampaignCard extends StatelessWidget {
  final CampaignModel campaign;
  final int index;

  const CampaignCard({super.key, required this.campaign, required this.index});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'campaign_${campaign.id}',
      child: GestureDetector(
        onTap: () => context.push('/campaigns/${campaign.id}'),
        child: Container(
          width: 270,
          decoration: AppDecorations.glassCard(
            glowColor: AppColors.accentViolet.withValues(alpha: 0.15),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: avatar + name + status
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: campaign.brandLogoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: campaign.brandLogoUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 40,
                              height: 40,
                              color: AppColors.accentViolet.withValues(alpha: 0.2),
                              child: const Icon(Icons.business, size: 20,
                                  color: AppColors.accentViolet),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 40,
                              height: 40,
                              color: AppColors.accentViolet.withValues(alpha: 0.2),
                              child: const Icon(Icons.business, size: 20,
                                  color: AppColors.accentViolet),
                            ),
                          )
                        : Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.accentViolet.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.business_rounded,
                                size: 20, color: AppColors.accentViolet),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.name,
                          style: AppTextStyles.labelLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (campaign.brandName != null)
                          Text(
                            campaign.brandName!,
                            style: AppTextStyles.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  StatusPill(status: campaign.status.name),
                ],
              ),

              const Spacer(),

              // Niche tags
              if (campaign.nicheTags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: campaign.nicheTags.take(2).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentViolet.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.accentViolet,
                        ),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 12),

              // Budget + payout
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Budget left', style: AppTextStyles.bodySmall),
                        const SizedBox(height: 2),
                        BudgetPill(
                          remainingPercent: campaign.budgetRemainingPercent,
                          walletBalance: campaign.walletBalance,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Per 1K views', style: AppTextStyles.bodySmall),
                      const SizedBox(height: 2),
                      Text(
                        '₹${campaign.payoutRatePer1000}',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Days remaining
              Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${campaign.daysActive}d active',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: 100 * index)).fadeIn().slideX(begin: 0.1, end: 0);
  }
}

// ─── New Campaign CTA Card ─────────────────────────────────────────────────────
class _NewCampaignCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NewCampaignCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.accentViolet.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accentViolet.withValues(alpha: 0.4),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.accentViolet.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded,
                  color: AppColors.accentViolet, size: 28),
            ),
            const SizedBox(height: 12),
            Text('New Campaign', style: AppTextStyles.titleMedium),
            const SizedBox(height: 4),
            Text('Launch your next\ncampaign',
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.glassCard(glowColor: color.withValues(alpha: 0.1)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodySmall),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}
