import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/models/appeal_model.dart';
import '../../shared/widgets/budget_pill.dart';
import '../../shared/widgets/glowy_card.dart';
import '../../shared/widgets/shimmer_list.dart';

final _openAppealsProvider = FutureProvider<List<AppealModel>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final snap = await firestore
      .collection('appeals')
      .where('status', whereIn: ['pending', 'underReview'])
      .orderBy('createdAt', descending: true)
      .limit(50)
      .get();
  return snap.docs.map((d) => AppealModel.fromFirestore(d)).toList();
});

class AppealsTab extends ConsumerWidget {
  const AppealsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appealsAsync = ref.watch(_openAppealsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('⚖️ Appeals')),
      body: appealsAsync.when(
        data: (appeals) {
          if (appeals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 64, color: AppColors.accentGreen),
                  const SizedBox(height: 12),
                  Text('No open appeals', style: AppTextStyles.titleMedium),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_openAppealsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: appeals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _AppealCard(
                appeal: appeals[i],
                onApprove: () => _resolveAppeal(ref, appeals[i], true),
                onReject: () => _resolveAppeal(ref, appeals[i], false),
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

  Future<void> _resolveAppeal(
      WidgetRef ref, AppealModel appeal, bool approved) async {
    final firestore = ref.read(firestoreProvider);
    final newStatus =
        approved ? 'resolvedApproved' : 'resolvedRejected';

    await firestore.collection('appeals').doc(appeal.id).update({
      'status': newStatus,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolverNote': approved
          ? 'Appeal approved by admin.'
          : 'Appeal rejected by admin.',
    });

    // If approved, clear the flag on the post
    if (approved) {
      await firestore.collection('posts').doc(appeal.postId).update({
        'flagged': false,
        'flagReason': null,
      });
    }

    ref.refresh(_openAppealsProvider);
  }
}

class _AppealCard extends StatelessWidget {
  final AppealModel appeal;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _AppealCard({
    required this.appeal,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return GlowyCard(
      glowColor: AppColors.accentViolet.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel_rounded,
                  color: AppColors.accentViolet, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(appeal.creatorName ?? 'Creator',
                    style: AppTextStyles.labelLarge),
              ),
              AppealStatusPill(status: appeal.status.name),
            ],
          ),
          const SizedBox(height: 6),
          Text('Post: ${appeal.postId}', style: AppTextStyles.bodySmall),
          const SizedBox(height: 6),
          Text(appeal.reason,
              style: AppTextStyles.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(AppDateUtils.timeAgo(appeal.createdAt),
              style: AppTextStyles.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen),
                  child: const Text('Approve'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    side: const BorderSide(color: AppColors.accentRed),
                  ),
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
