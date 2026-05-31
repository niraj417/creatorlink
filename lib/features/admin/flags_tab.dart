import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/models/post_model.dart';
import '../../shared/widgets/budget_pill.dart';
import '../../shared/widgets/glowy_card.dart';
import '../../shared/widgets/shimmer_list.dart';

// ─── Flags Tab ────────────────────────────────────────────────────────────────
final _flaggedPostsProvider = FutureProvider<List<PostModel>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final snap = await firestore
      .collection('posts')
      .where('flagged', isEqualTo: true)
      .orderBy('submittedAt', descending: true)
      .limit(50)
      .get();
  return snap.docs.map((d) => PostModel.fromFirestore(d)).toList();
});

class FlagsTab extends ConsumerWidget {
  const FlagsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagsAsync = ref.watch(_flaggedPostsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('🚩 Flagged Posts')),
      body: flagsAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 64, color: AppColors.accentGreen),
                  const SizedBox(height: 12),
                  Text('No flagged posts!', style: AppTextStyles.titleMedium),
                  Text('Everything looks clean.', style: AppTextStyles.bodyMedium),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_flaggedPostsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _FlagCard(
                post: posts[i],
                onClearFlag: () => _clearFlag(ref, posts[i].id),
                onRemovePost: () => _removePost(ref, posts[i].id),
                onBanCreator: () => _banCreator(ref, posts[i].creatorUid),
              ),
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: ShimmerList(itemCount: 5),
        ),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _clearFlag(WidgetRef ref, String postId) async {
    final firestore = ref.read(firestoreProvider);
    await firestore.collection('posts').doc(postId).update({
      'flagged': false,
      'flagReason': null,
    });
    ref.refresh(_flaggedPostsProvider);
  }

  Future<void> _removePost(WidgetRef ref, String postId) async {
    final firestore = ref.read(firestoreProvider);
    await firestore.collection('posts').doc(postId).update({
      'status': 'removed',
      'flagged': false,
    });
    ref.refresh(_flaggedPostsProvider);
  }

  Future<void> _banCreator(WidgetRef ref, String uid) async {
    final firestore = ref.read(firestoreProvider);
    await firestore.collection('users').doc(uid).update({'banned': true});
  }
}

class _FlagCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onClearFlag;
  final VoidCallback onRemovePost;
  final VoidCallback onBanCreator;

  const _FlagCard({
    required this.post,
    required this.onClearFlag,
    required this.onRemovePost,
    required this.onBanCreator,
  });

  @override
  Widget build(BuildContext context) {
    return GlowyCard(
      glowColor: AppColors.accentRed.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppColors.accentRed, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  post.creatorName ?? 'Creator',
                  style: AppTextStyles.labelLarge,
                ),
              ),
              Text(AppDateUtils.timeAgo(post.submittedAt),
                  style: AppTextStyles.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Text('Reason: ${post.flagReason ?? 'Unknown'}',
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.accentRed)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(post.postUrl)),
            child: Text(
              post.postUrl.isEmpty ? 'No URL' : post.postUrl,
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.accentViolet),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onClearFlag,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentGreen,
                    side: const BorderSide(color: AppColors.accentGreen),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Clear Flag', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onRemovePost,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentAmber,
                    side: const BorderSide(color: AppColors.accentAmber),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Remove Post', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onBanCreator,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    side: const BorderSide(color: AppColors.accentRed),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Ban Creator', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
