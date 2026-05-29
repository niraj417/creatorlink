import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/models/transaction_model.dart';
import '../../shared/widgets/glowy_card.dart';
import '../../shared/widgets/shimmer_list.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────
final _txHistoryProvider =
    FutureProvider.family<List<TransactionModel>, String>((ref, uid) async {
  if (uid.isEmpty) return [];
  final firestore = ref.watch(firestoreProvider);
  final snap = await firestore
      .collection('transactions')
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .get();
  return snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList();
});

// ─── Screen ───────────────────────────────────────────────────────────────────
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  String? _filterType; // null = All

  static const _filterOptions = [
    null,
    'credit',
    'debit',
    'topup',
    'withdrawal',
  ];

  static const _filterLabels = ['All', 'Credits', 'Debits', 'Top-ups', 'Withdrawals'];

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserDataProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          // Summary badge
          if (userAsync.value != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.accentGreen.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded,
                        color: AppColors.accentGreen, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      CurrencyFormatter.fromPoints(
                          userAsync.value!.walletPoints),
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.accentGreen),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not logged in'));
          }
          return Column(
            children: [
              // Filter chips
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filterOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final selected = _filterType == _filterOptions[i];
                    return FilterChip(
                      label: Text(_filterLabels[i]),
                      selected: selected,
                      onSelected: (_) => setState(
                          () => _filterType = _filterOptions[i]),
                      selectedColor: AppColors.accentViolet.withOpacity(0.2),
                      checkmarkColor: AppColors.accentViolet,
                      side: BorderSide(
                        color: selected
                            ? AppColors.accentViolet
                            : AppColors.glassBorder,
                      ),
                      labelStyle: AppTextStyles.labelSmall.copyWith(
                        color: selected
                            ? AppColors.accentViolet
                            : AppColors.textSecondary,
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _TxList(uid: user.uid, filterType: _filterType),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => const SizedBox(),
      ),
    );
  }
}

// ─── Transaction List ─────────────────────────────────────────────────────────
class _TxList extends ConsumerWidget {
  final String uid;
  final String? filterType;

  const _TxList({required this.uid, required this.filterType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(_txHistoryProvider(uid));

    return txAsync.when(
      data: (all) {
        // Apply filter
        final txs = filterType == null
            ? all
            : all
                .where((t) => t.type.name == filterType)
                .toList();

        if (txs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 56, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text(
                  filterType == null
                      ? 'No transactions yet'
                      : 'No ${filterType}s found',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 6),
                Text('Earnings will appear here once credited.',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ).animate().fadeIn();
        }

        // Group by month
        final grouped = <String, List<TransactionModel>>{};
        for (final tx in txs) {
          final key = _monthKey(tx.createdAt);
          grouped.putIfAbsent(key, () => []).add(tx);
        }

        final keys = grouped.keys.toList();

        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(_txHistoryProvider(uid).future),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: keys.length,
            itemBuilder: (ctx, gi) {
              final key = keys[gi];
              final items = grouped[key]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month header
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 10),
                    child: Text(
                      key,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  GlowyCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: List.generate(items.length, (i) {
                        final tx = items[i];
                        return Column(
                          children: [
                            _TxTile(tx: tx)
                                .animate(delay: (i * 30).ms)
                                .fadeIn()
                                .slideX(begin: 0.05),
                            if (i < items.length - 1)
                              const Divider(
                                  height: 1, color: AppColors.glassBorder),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: ShimmerList(itemCount: 6, itemHeight: 64),
      ),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  static String _monthKey(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1].toUpperCase()} ${dt.year}';
  }
}

// ─── Single Tile ──────────────────────────────────────────────────────────────
class _TxTile extends StatelessWidget {
  final TransactionModel tx;
  const _TxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    final color = isCredit ? AppColors.accentGreen : AppColors.accentRed;
    final icon = _iconFor(tx.type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Icon bubble
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          // Label + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.typeLabel, style: AppTextStyles.labelLarge),
                if (tx.note != null && tx.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(tx.note!,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ] else ...[
                  const SizedBox(height: 2),
                  Text(AppDateUtils.formatDateTime(tx.createdAt),
                      style: AppTextStyles.bodySmall),
                ],
              ],
            ),
          ),
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}${CurrencyFormatter.fromRupees(tx.amount.toDouble())}',
                style: AppTextStyles.labelLarge.copyWith(color: color),
              ),
              Text(AppDateUtils.timeAgo(tx.createdAt),
                  style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(TransactionType type) {
    switch (type) {
      case TransactionType.credit:
        return Icons.arrow_downward_rounded;
      case TransactionType.debit:
        return Icons.arrow_upward_rounded;
      case TransactionType.topup:
        return Icons.add_card_rounded;
      case TransactionType.withdrawal:
        return Icons.account_balance_rounded;
    }
  }
}
