import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/models/withdrawal_model.dart';
import '../../shared/widgets/glowy_card.dart';
import '../../shared/widgets/shimmer_list.dart';

final _pendingWithdrawalsProvider =
    FutureProvider<List<WithdrawalRequestModel>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final snap = await firestore
      .collection('withdrawal_requests')
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .get();
  return snap.docs
      .map((d) => WithdrawalRequestModel.fromFirestore(d))
      .toList();
});

class PaymentsTab extends ConsumerWidget {
  const PaymentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final withdrawalsAsync = ref.watch(_pendingWithdrawalsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('💸 Payments')),
      body: withdrawalsAsync.when(
        data: (withdrawals) {
          if (withdrawals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.payments_rounded,
                      size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text('No pending withdrawals', style: AppTextStyles.titleMedium),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_pendingWithdrawalsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: withdrawals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _WithdrawalCard(
                request: withdrawals[i],
                onProcess: () =>
                    _processWithdrawal(ref, context, withdrawals[i]),
                onReject: () =>
                    _rejectWithdrawal(ref, withdrawals[i]),
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

  Future<void> _processWithdrawal(WidgetRef ref, BuildContext context,
      WithdrawalRequestModel request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Confirm Payment'),
        content: Text(
          'Mark ₹${request.amount} withdrawal for ${request.creatorName} as processed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark Processed'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final firestore = ref.read(firestoreProvider);
    final batch = firestore.batch();

    // Mark withdrawal as processed
    batch.update(
      firestore.collection('withdrawal_requests').doc(request.id),
      {
        'status': 'processed',
        'processedAt': FieldValue.serverTimestamp(),
      },
    );

    // Deduct points from creator's wallet
    batch.update(
      firestore.collection('users').doc(request.creatorUid),
      {
        'walletPoints': FieldValue.increment(-request.amount),
      },
    );

    // Record transaction
    batch.set(
      firestore.collection('transactions').doc(),
      {
        'type': 'withdrawal',
        'uid': request.creatorUid,
        'amount': request.amount,
        'relatedId': request.id,
        'note': 'Withdrawal processed by admin',
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
    ref.invalidate(_pendingWithdrawalsProvider);
  }

  Future<void> _rejectWithdrawal(
      WidgetRef ref, WithdrawalRequestModel request) async {
    final firestore = ref.read(firestoreProvider);
    await firestore.collection('withdrawal_requests').doc(request.id).update({
      'status': 'rejected',
      'processedAt': FieldValue.serverTimestamp(),
    });
    ref.invalidate(_pendingWithdrawalsProvider);
  }
}

class _WithdrawalCard extends StatelessWidget {
  final WithdrawalRequestModel request;
  final VoidCallback onProcess;
  final VoidCallback onReject;

  const _WithdrawalCard({
    required this.request,
    required this.onProcess,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return GlowyCard(
      glowColor: AppColors.accentGreen.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  color: AppColors.accentGreen, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(request.creatorName ?? 'Creator',
                    style: AppTextStyles.labelLarge),
              ),
              Text(
                CurrencyFormatter.fromRupees(request.amount.toDouble()),
                style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.accentGreen),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (request.upiId != null)
            Row(
              children: [
                const Icon(Icons.phone_android_rounded,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text('UPI: ${request.upiId}',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          if (request.bankAccount != null) ...[
            Row(
              children: [
                const Icon(Icons.account_balance_rounded,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                    'IFSC: ${request.bankIfsc ?? ''} | ${request.bankAccount}',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(AppDateUtils.timeAgo(request.createdAt),
              style: AppTextStyles.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onProcess,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen),
                  child: const Text('Mark Processed'),
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
