import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/models/transaction_model.dart';
import '../../shared/widgets/glowy_card.dart';
import '../../shared/widgets/shimmer_list.dart';

class CreatorWalletScreen extends ConsumerWidget {
  const CreatorWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserDataProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Wallet')),
      body: userAsync.when(
        data: (user) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Balance card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accentViolet, Color(0xFF5240D9)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentViolet.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 6),
                        const Text('Points Balance',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.fromPoints(user?.walletPoints ?? 0),
                      style: AppTextStyles.displayLarge
                          .copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '1 Point = ₹1.00',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white60),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.push('/wallet/history'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                  color: Colors.white30, width: 1),
                            ),
                            child: const Text('History'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (user?.walletPoints ?? 0) >= 100
                                ? () => context.push('/wallet/withdraw')
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.accentViolet,
                            ),
                            child: const Text('Withdraw'),
                          ),
                        ),
                      ],
                    ),
                    if ((user?.walletPoints ?? 0) < 100) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Minimum ₹100 needed to withdraw',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: Colors.white60),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),

              const SizedBox(height: 24),

              // Recent transactions
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Recent Activity', style: AppTextStyles.titleMedium),
              ),
              const SizedBox(height: 12),
              _RecentTransactions(uid: user?.uid ?? ''),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => const SizedBox(),
      ),
    );
  }
}

class _RecentTransactions extends ConsumerWidget {
  final String uid;
  const _RecentTransactions({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(_recentTransactionsProvider(uid));
    return txAsync.when(
      data: (txs) {
        if (txs.isEmpty) {
          return GlowyCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long_outlined,
                        size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text('No transactions yet', style: AppTextStyles.bodyMedium),
                  ],
                ),
              ),
            ),
          );
        }
        return GlowyCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: txs.asMap().entries.map((entry) {
              final tx = entry.value;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: tx.isCredit
                                ? AppColors.accentGreen.withOpacity(0.1)
                                : AppColors.accentRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            tx.isCredit
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: tx.isCredit
                                ? AppColors.accentGreen
                                : AppColors.accentRed,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tx.typeLabel,
                                  style: AppTextStyles.labelLarge),
                              Text(AppDateUtils.timeAgo(tx.createdAt),
                                  style: AppTextStyles.bodySmall),
                            ],
                          ),
                        ),
                        Text(
                          '${tx.isCredit ? '+' : '-'}${CurrencyFormatter.fromRupees(tx.amount.toDouble())}',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: tx.isCredit
                                ? AppColors.accentGreen
                                : AppColors.accentRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (entry.key < txs.length - 1)
                    const Divider(height: 1, color: AppColors.glassBorder),
                ],
              );
            }).toList(),
          ),
        );
      },
      loading: () => const ShimmerList(itemCount: 4, itemHeight: 64),
      error: (e, s) => const SizedBox(),
    );
  }
}

final _recentTransactionsProvider =
    FutureProvider.family<List<TransactionModel>, String>((ref, uid) async {
  if (uid.isEmpty) return [];
  final firestore = ref.watch(firestoreProvider);
  final snap = await firestore
      .collection('transactions')
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(10)
      .get();
  return snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList();
});
