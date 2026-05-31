import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/campaign_model.dart';
import '../../../shared/widgets/budget_pill.dart';
import '../../../shared/widgets/glowy_card.dart';
import '../../../shared/widgets/shimmer_list.dart';
import '../campaign_providers.dart';

class CampaignListScreen extends ConsumerStatefulWidget {
  const CampaignListScreen({super.key});

  @override
  ConsumerState<CampaignListScreen> createState() => _CampaignListScreenState();
}

class _CampaignListScreenState extends ConsumerState<CampaignListScreen> {
  String _filter = 'all'; // all | active | paused

  @override
  Widget build(BuildContext context) {
    final campaignsAsync = ref.watch(activeCampaignsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Campaigns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // TODO: Search campaigns
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Active',
                    isSelected: _filter == 'active',
                    onTap: () => setState(() => _filter = 'active'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'High Payout',
                    isSelected: _filter == 'high',
                    onTap: () => setState(() => _filter = 'high'),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 12),

          // Campaign list
          Expanded(
            child: campaignsAsync.when(
              data: (campaigns) {
                final filtered = campaigns.where((c) {
                  if (_filter == 'active') return c.status == CampaignStatus.active;
                  if (_filter == 'high') return c.payoutRatePer1000 >= 50;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.campaign_outlined,
                            size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        Text('No campaigns found', style: AppTextStyles.titleMedium),
                        const SizedBox(height: 8),
                        Text('Check back later for new opportunities.',
                            style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.accentViolet,
                  backgroundColor: AppColors.surfaceElevated,
                  onRefresh: () => ref.refresh(activeCampaignsProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => _CampaignListTile(
                      campaign: filtered[i],
                      index: i,
                    ),
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ShimmerList(itemCount: 6, itemHeight: 100),
              ),
              error: (e, s) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.accentRed, size: 48),
                    const SizedBox(height: 12),
                    Text('Failed to load campaigns', style: AppTextStyles.bodyMedium),
                    TextButton(
                      onPressed: () => ref.refresh(activeCampaignsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignListTile extends StatelessWidget {
  final CampaignModel campaign;
  final int index;

  const _CampaignListTile({required this.campaign, required this.index});

  @override
  Widget build(BuildContext context) {
    return GlowyCard(
      onTap: () => context.push('/campaigns/${campaign.id}'),
      padding: const EdgeInsets.all(16),
      glowColor: AppColors.accentViolet.withValues(alpha: 0.08),
      child: Row(
        children: [
          // Brand logo
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: campaign.brandLogoUrl != null
                ? CachedNetworkImage(
                    imageUrl: campaign.brandLogoUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 52,
                      height: 52,
                      color: AppColors.accentViolet.withValues(alpha: 0.15),
                    ),
                    errorWidget: (_, __, ___) => _BrandPlaceholder(),
                  )
                : _BrandPlaceholder(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        campaign.name,
                        style: AppTextStyles.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StatusPill(status: campaign.status.name),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  campaign.brandName ?? 'Unknown Brand',
                  style: AppTextStyles.bodySmall,
                ),
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
                      '₹${campaign.payoutRatePer1000}/1K views',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.accentGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 20),
        ],
      ),
    ).animate(delay: Duration(milliseconds: 50 * index)).fadeIn().slideX(begin: 0.05, end: 0);
  }
}

class _BrandPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.accentViolet.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.business_rounded,
          color: AppColors.accentViolet, size: 24),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentViolet.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accentViolet : AppColors.glassBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: isSelected ? AppColors.accentViolet : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
