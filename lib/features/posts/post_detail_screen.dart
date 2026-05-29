import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/models/post_model.dart';
import '../../shared/widgets/glowy_card.dart';
import '../../shared/widgets/stat_row.dart';

final _postByIdProvider = FutureProvider.family<PostModel?, String>((ref, pid) async {
  final firestore = ref.watch(firestoreProvider);
  final doc = await firestore.collection('posts').doc(pid).get();
  if (!doc.exists) return null;
  return PostModel.fromFirestore(doc);
});

class PostDetailScreen extends ConsumerWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(_postByIdProvider(postId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Post Details')),
      body: postAsync.when(
        data: (post) {
          if (post == null) {
            return const Center(child: Text('Post not found'));
          }
          return _PostDetailBody(post: post);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _PostDetailBody extends StatelessWidget {
  final PostModel post;
  const _PostDetailBody({required this.post});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _statusColor(post.status).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _statusColor(post.status).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(post.status),
                    color: _statusColor(post.status), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.statusLabel,
                          style: AppTextStyles.titleMedium.copyWith(
                              color: _statusColor(post.status))),
                      Text(_statusMessage(post.status),
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),

          const SizedBox(height: 20),

          // Stats
          GlowyCard(
            glowColor: AppColors.accentViolet.withOpacity(0.1),
            child: Column(
              children: [
                StatRow(
                  icon: Icons.visibility_outlined,
                  label: 'Total Views',
                  value: CurrencyFormatter.compactViews(post.views),
                  iconColor: AppColors.accentViolet,
                  valueColor: AppColors.accentViolet,
                ),
                StatRow(
                  icon: Icons.people_outline,
                  label: 'Reach',
                  value: CurrencyFormatter.compactViews(post.reach),
                ),
                StatRow(
                  icon: Icons.favorite_outline,
                  label: 'Interactions',
                  value: CurrencyFormatter.compactViews(post.interactions),
                ),
                StatRow(
                  icon: Icons.schedule_rounded,
                  label: 'Must Stay Until',
                  value: AppDateUtils.formatDate(post.mustStayUntil),
                  isLast: true,
                ),
              ],
            ),
          ).animate(delay: 100.ms).fadeIn(),

          const SizedBox(height: 16),

          // Post URL
          GlowyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Post URL', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                Text(post.postUrl.isEmpty ? 'Not submitted yet' : post.postUrl,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: post.postUrl.isEmpty
                            ? AppColors.textMuted
                            : AppColors.accentViolet)),
              ],
            ),
          ).animate(delay: 150.ms).fadeIn(),

          const SizedBox(height: 16),

          // Flagged warning
          if (post.flagged) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.accentRed.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flag_rounded,
                          color: AppColors.accentRed, size: 18),
                      const SizedBox(width: 8),
                      Text('Post Flagged',
                          style: AppTextStyles.titleMedium
                              .copyWith(color: AppColors.accentRed)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Reason: ${post.flagReason ?? 'Unknown'}',
                      style: AppTextStyles.bodySmall),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        context.push('/posts/${ post.id}/appeal'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentRed,
                      side: const BorderSide(color: AppColors.accentRed),
                    ),
                    child: const Text('Appeal This Flag'),
                  ),
                ],
              ),
            ).animate(delay: 200.ms).fadeIn(),
          ],
        ],
      ),
    );
  }

  Color _statusColor(PostStatus status) {
    switch (status) {
      case PostStatus.approved:
        return AppColors.accentGreen;
      case PostStatus.rejected:
        return AppColors.accentRed;
      case PostStatus.pendingReview:
        return AppColors.accentAmber;
      case PostStatus.mayRemove:
        return AppColors.accentAmber;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _statusIcon(PostStatus status) {
    switch (status) {
      case PostStatus.approved:
        return Icons.check_circle_rounded;
      case PostStatus.rejected:
        return Icons.cancel_rounded;
      case PostStatus.pendingReview:
        return Icons.hourglass_top_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _statusMessage(PostStatus status) {
    switch (status) {
      case PostStatus.approved:
        return 'Your post is live and earning points!';
      case PostStatus.rejected:
        return 'Post was rejected. You can appeal below.';
      case PostStatus.pendingReview:
        return 'Waiting for review. We\'ll notify you shortly.';
      case PostStatus.pendingPost:
        return 'Submit your post URL to start earning.';
      case PostStatus.mayRemove:
        return 'Campaign budget exhausted. You may now remove this post.';
      default:
        return '';
    }
  }
}
