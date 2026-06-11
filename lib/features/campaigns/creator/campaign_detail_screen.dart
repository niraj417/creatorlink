import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/models/campaign_model.dart';
import '../../../shared/widgets/budget_pill.dart';
import '../../../shared/widgets/glowy_card.dart';
import '../campaign_providers.dart';

class CampaignDetailScreen extends ConsumerWidget {
  final String campaignId;
  const CampaignDetailScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignAsync = ref.watch(campaignByIdProvider(campaignId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: campaignAsync.when(
        data: (campaign) {
          if (campaign == null) {
            return const Center(child: Text('Campaign not found'));
          }
          return _CampaignDetailBody(campaign: campaign);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _CampaignDetailBody extends ConsumerStatefulWidget {
  final CampaignModel campaign;
  const _CampaignDetailBody({required this.campaign});

  @override
  ConsumerState<_CampaignDetailBody> createState() =>
      _CampaignDetailBodyState();
}

class _CampaignDetailBodyState extends ConsumerState<_CampaignDetailBody> {
  bool _isJoining = false;

  Future<void> _joinCampaign() async {
    final campaign = widget.campaign;
    final user = ref.read(currentUserDataProvider).value;
    if (user == null) return;

    setState(() => _isJoining = true);
    try {
      final firestore = ref.read(firestoreProvider);

      // Check if already joined
      final existing = await firestore
          .collection('posts')
          .where('creatorUid', isEqualTo: user.uid)
          .where('campaignId', isEqualTo: campaign.id)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already joined this campaign.')),
        );
        setState(() => _isJoining = false);
        return;
      }

      // Create pending post slot
      await firestore.collection('posts').add({
        'creatorUid': user.uid,
        'campaignId': campaign.id,
        'postUrl': '',
        'screenshotUrl': null,
        'platform': '',
        'status': 'pendingPost',
        'views': 0,
        'reach': 0,
        'interactions': 0,
        'flagged': false,
        'flagReason': null,
        'submittedAt': null,
        'mustStayUntil': null,
        'creatorName': user.displayName,
        'creatorPhotoUrl': user.photoURL,
        'campaignName': campaign.name,
        'dailyViewHistory': {},
        'joinedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isJoining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Joined! Now submit your post URL to start earning.'),
          backgroundColor: AppColors.accentGreen,
        ),
      );
      // Navigate to submit post
      context.push('/posts/submit/${campaign.id}');
    } catch (e) {
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaign = widget.campaign;

    return Stack(
      children: [
        CustomScrollView(
      slivers: [
        // ─── App Bar ────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.surface,
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: AppColors.textPrimary),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Hero(
              tag: 'campaign_${campaign.id}',
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.accentViolet.withValues(alpha: 0.2),
                      AppColors.surface,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.accentViolet.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: campaign.brandLogoUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(17),
                                child: CachedNetworkImage(
                                  imageUrl: campaign.brandLogoUrl!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.business_rounded,
                                size: 36, color: AppColors.accentViolet),
                      ),
                      const SizedBox(height: 12),
                      Text(campaign.brandName ?? 'Brand',
                          style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ─── Content ────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Title + Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(campaign.name, style: AppTextStyles.displayMedium),
                  ),
                  const SizedBox(width: 12),
                  StatusPill(status: campaign.status.name),
                ],
              ).animate().fadeIn(),

              const SizedBox(height: 16),

              // Metrics row
              Row(
                children: [
                  Expanded(
                    child: _MetricChip(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Budget Left',
                      value: CurrencyFormatter.fromRupees(campaign.walletBalance.toDouble()),
                      color: AppColors.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricChip(
                      icon: Icons.visibility_outlined,
                      label: 'Per 1K Views',
                      value: '₹${campaign.payoutRatePer1000}',
                      color: AppColors.accentViolet,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricChip(
                      icon: Icons.people_outline_rounded,
                      label: 'Min Followers',
                      value: CurrencyFormatter.compactViews(campaign.minFollowers),
                      color: AppColors.accentAmber,
                    ),
                  ),
                ],
              ).animate(delay: 100.ms).fadeIn(),

              const SizedBox(height: 20),

              // Niche tags
              if (campaign.nicheTags.isNotEmpty) ...[
                Text('Niche', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: campaign.nicheTags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accentViolet.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.accentViolet.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        tag,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.accentViolet),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],

              // Description
              Text('Campaign Brief', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              GlowyCard(
                padding: const EdgeInsets.all(16),
                child: Text(campaign.description, style: AppTextStyles.bodyMedium),
              ).animate(delay: 200.ms).fadeIn(),

              const SizedBox(height: 16),

              // Brand Guidelines
              Text('Brand Guidelines', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              GlowyCard(
                padding: const EdgeInsets.all(16),
                child: Text(campaign.guidelines, style: AppTextStyles.bodyMedium),
              ).animate(delay: 250.ms).fadeIn(),

              const SizedBox(height: 16),

              // Assets
              if (campaign.assetUrls.isNotEmpty) ...[
                Text('Reference Assets', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: campaign.assetUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) => GestureDetector(
                      onTap: () => launchUrl(Uri.parse(campaign.assetUrls[i])),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: const Icon(Icons.attachment_rounded,
                            color: AppColors.accentViolet),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 80), // space for FAB
            ]),
          ),
        ),
      ],
    ),

        // ─── Sticky Join / Submit Button ──────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.surface.withValues(alpha: 0),
                  AppColors.surface,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isJoining
                        ? null
                        : (campaign.status == CampaignStatus.active
                            ? _joinCampaign
                            : null),
                    icon: _isJoining
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.rocket_launch_rounded, size: 20),
                    label: Text(
                      campaign.status == CampaignStatus.active
                          ? 'Join Campaign & Submit Post'
                          : 'Campaign Not Active',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: campaign.status == CampaignStatus.active
                          ? AppColors.accentViolet
                          : AppColors.textMuted,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                if (campaign.status == CampaignStatus.active) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () =>
                        context.push('/posts/submit/${campaign.id}'),
                    child: Text(
                      'Already joined? Submit post URL →',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.accentViolet),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Join Campaign FAB ─────────────────────────────────────────────────────────
// Note: We inject this via a SliverFillRemaining or a Stack overlay
// For simplicity, the Join button is in a persistent bottom area

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: AppTextStyles.labelLarge.copyWith(color: color)),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
