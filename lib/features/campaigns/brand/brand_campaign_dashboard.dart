import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/models/campaign_model.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/widgets/glowy_card.dart';
import '../../../shared/widgets/shimmer_list.dart';
import '../../../shared/widgets/stat_row.dart';
import '../campaign_providers.dart';

class BrandCampaignDashboard extends ConsumerWidget {
  final String campaignId;
  const BrandCampaignDashboard({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignAsync = ref.watch(campaignStreamProvider(campaignId));
    final postsAsync = ref.watch(campaignPostsProvider(campaignId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: campaignAsync.when(
          data: (c) => Text(c?.name ?? 'Dashboard'),
          loading: () => const Text('Dashboard'),
          error: (e, s) => const Text('Dashboard'),
        ),
        actions: [
          campaignAsync.when(
            data: (c) => c != null
                ? _CampaignStatusMenu(campaign: c, campaignId: campaignId)
                : const SizedBox(),
            loading: () => const SizedBox(),
            error: (e, s) => const SizedBox(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Campaign Metrics Cards ────────────────────────────
            campaignAsync.when(
              data: (c) => c != null ? _MetricsSection(campaign: c) : const SizedBox(),
              loading: () => const ShimmerList(itemCount: 2, itemHeight: 80),
              error: (e, s) => const SizedBox(),
            ).animate().fadeIn(),

            const SizedBox(height: 24),

            // ─── Views Per Day Chart ───────────────────────────────
            Text('Views Over Time', style: AppTextStyles.titleMedium),
            const SizedBox(height: 12),
            GlowyCard(
              height: 200,
              glowColor: AppColors.accentViolet.withValues(alpha: 0.1),
              child: postsAsync.when(
                data: (docs) => _ViewsChart(postDocs: docs),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => const Center(child: Text('Chart unavailable')),
              ),
            ).animate(delay: 100.ms).fadeIn(),

            const SizedBox(height: 24),

            // ─── Posts Table ───────────────────────────────────────
            Text('Post Submissions', style: AppTextStyles.titleMedium),
            const SizedBox(height: 12),
            postsAsync.when(
              data: (docs) {
                if (docs.isEmpty) {
                  return GlowyCard(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(Icons.article_outlined,
                                size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text('No posts yet', style: AppTextStyles.bodyMedium),
                            Text('Creators will submit posts here.',
                                style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final post = PostModel.fromFirestore(doc);
                    return _PostRow(post: post);
                  }).toList(),
                );
              },
              loading: () => const ShimmerList(itemCount: 4, itemHeight: 70),
              error: (e, s) => const SizedBox(),
            ).animate(delay: 200.ms).fadeIn(),
          ],
        ),
      ),
    );
  }
}

class _MetricsSection extends StatelessWidget {
  final CampaignModel campaign;
  const _MetricsSection({required this.campaign});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Total Views',
                value: CurrencyFormatter.compactViews(campaign.metrics.totalViews),
                icon: Icons.visibility_outlined,
                accentColor: AppColors.accentViolet,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: 'Reach',
                value: CurrencyFormatter.compactViews(campaign.metrics.totalReach),
                icon: Icons.people_outline,
                accentColor: AppColors.accentGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Interactions',
                value: CurrencyFormatter.compactViews(campaign.metrics.totalInteractions),
                icon: Icons.favorite_outline,
                accentColor: AppColors.accentAmber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: 'Budget Left',
                value: CurrencyFormatter.fromRupees(campaign.walletBalance.toDouble()),
                icon: Icons.account_balance_wallet_outlined,
                accentColor: campaign.budgetRemainingPercent > 0.3
                    ? AppColors.accentGreen
                    : AppColors.accentRed,
                subtitle: '${(campaign.budgetRemainingPercent * 100).toInt()}% remaining',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ViewsChart extends StatelessWidget {
  final List<dynamic> postDocs;
  const _ViewsChart({required this.postDocs});

  @override
  Widget build(BuildContext context) {
    // Aggregate views per day from all posts
    final Map<int, double> dayViews = {};
    for (int i = 0; i < 7; i++) {
      dayViews[i] = 0;
    }

    // This is a placeholder — in production, aggregate from dailyViewHistory
    for (var doc in postDocs) {
      final post = PostModel.fromFirestore(doc);
      final dayIndex = DateTime.now().difference(post.submittedAt).inDays.clamp(0, 6);
      dayViews[dayIndex] = (dayViews[dayIndex] ?? 0) + post.views;
    }

    final bars = dayViews.entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value,
            color: AppColors.accentViolet,
            width: 20,
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: (dayViews.values.isEmpty ? 100 : dayViews.values.reduce((a, b) => a > b ? a : b) * 1.2),
              color: AppColors.accentViolet.withValues(alpha: 0.06),
            ),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        barGroups: bars,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.glassBorder,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text(
                CurrencyFormatter.compactViews(v.toInt()),
                style: AppTextStyles.labelSmall,
              ),
              reservedSize: 36,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                const days = ['6d', '5d', '4d', '3d', '2d', 'Y\'day', 'Today'];
                final idx = v.toInt().clamp(0, 6);
                return Text(days[idx], style: AppTextStyles.labelSmall);
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceElevated,
          ),
        ),
      ),
    );
  }
}

class _PostRow extends StatelessWidget {
  final PostModel post;
  const _PostRow({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.surfaceCard(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.creatorName ?? 'Creator',
                  style: AppTextStyles.labelLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  post.postUrl.isEmpty ? 'No link yet' : post.postUrl,
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.compactViews(post.views),
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.accentViolet,
                ),
              ),
              const SizedBox(height: 2),
              if (post.flagged)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag_rounded,
                          size: 10, color: AppColors.accentRed),
                      const SizedBox(width: 3),
                      Text('Flagged',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.accentRed)),
                    ],
                  ),
                )
              else
                Text(post.statusLabel, style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _CampaignStatusMenu extends ConsumerWidget {
  final CampaignModel campaign;
  final String campaignId;

  const _CampaignStatusMenu({
    required this.campaign,
    required this.campaignId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      color: AppColors.surfaceElevated,
      onSelected: (action) async {
        final firestore = ref.read(firestoreProvider);
        switch (action) {
          case 'pause':
            await firestore
                .collection('campaigns')
                .doc(campaignId)
                .update({'status': 'paused'});
            break;
          case 'resume':
            await firestore
                .collection('campaigns')
                .doc(campaignId)
                .update({'status': 'active'});
            break;
          case 'end':
            await firestore
                .collection('campaigns')
                .doc(campaignId)
                .update({'status': 'ended'});
            break;
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Campaign status updated')),
          );
        }
      },
      itemBuilder: (ctx) => [
        if (campaign.status == CampaignStatus.active)
          const PopupMenuItem(value: 'pause', child: Text('Pause Campaign')),
        if (campaign.status == CampaignStatus.paused)
          const PopupMenuItem(value: 'resume', child: Text('Resume Campaign')),
        const PopupMenuItem(
          value: 'end',
          child: Text('End Campaign', style: TextStyle(color: AppColors.accentRed)),
        ),
      ],
    );
  }
}
