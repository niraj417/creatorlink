import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../shared/widgets/glowy_card.dart';

class BrandWalletScreen extends ConsumerWidget {
  const BrandWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Text('Brand Wallet — Use Campaign Dashboard for per-campaign wallet.'),
      ),
    );
  }
}

class WithdrawalRequestScreen extends ConsumerStatefulWidget {
  const WithdrawalRequestScreen({super.key});

  @override
  ConsumerState<WithdrawalRequestScreen> createState() =>
      _WithdrawalRequestScreenState();
}

class _WithdrawalRequestScreenState extends ConsumerState<WithdrawalRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _upiController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _holderController = TextEditingController();
  String _method = 'upi'; // 'upi' | 'bank'
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _upiController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _holderController.dispose();
    super.dispose();
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final firestore = ref.read(firestoreProvider);
      final user = ref.read(currentUserDataProvider).value;
      if (user == null) throw Exception('Not logged in');

      final amount = int.tryParse(_amountController.text) ?? 0;
      if (amount < 100) throw Exception('Minimum withdrawal is ₹100');
      if ((user.walletPoints) < amount) {
        throw Exception('Insufficient balance');
      }

      await firestore.collection('withdrawal_requests').add({
        'creatorUid': user.uid,
        'amount': amount,
        'upiId': _method == 'upi' ? _upiController.text.trim() : null,
        'bankAccount':
            _method == 'bank' ? _accountController.text.trim() : null,
        'bankIfsc': _method == 'bank' ? _ifscController.text.trim() : null,
        'bankHolderName':
            _method == 'bank' ? _holderController.text.trim() : null,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'processedAt': null,
        'creatorName': user.displayName,
      });

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Withdrawal request submitted!')),
      );
      context.pop();
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserDataProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Withdraw Earnings')),
      body: userAsync.when(
        data: (user) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Balance display
                GlowyCard(
                  glowColor: AppColors.accentGreen.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                          color: AppColors.accentGreen, size: 28),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Available Balance',
                              style: AppTextStyles.bodyMedium),
                          Text(
                            CurrencyFormatter.fromPoints(
                                user?.walletPoints ?? 0),
                            style: AppTextStyles.displayMedium.copyWith(
                                color: AppColors.accentGreen),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(),

                const SizedBox(height: 24),

                // Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount to Withdraw (₹) *',
                    prefixIcon: Icon(Icons.currency_rupee),
                    hintText: 'Minimum ₹100',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Amount required';
                    final n = int.tryParse(v);
                    if (n == null || n < 100) return 'Minimum withdrawal is ₹100';
                    if (n > (user?.walletPoints ?? 0)) {
                      return 'Insufficient balance';
                    }
                    return null;
                  },
                ).animate(delay: 100.ms).fadeIn(),

                const SizedBox(height: 24),

                // Payment method toggle
                Text('Payment Method', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _method = 'upi'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _method == 'upi'
                                ? AppColors.accentViolet.withValues(alpha: 0.12)
                                : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _method == 'upi'
                                  ? AppColors.accentViolet
                                  : AppColors.glassBorder,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.phone_android_rounded,
                                  color: _method == 'upi'
                                      ? AppColors.accentViolet
                                      : AppColors.textMuted),
                              const SizedBox(height: 4),
                              Text('UPI',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: _method == 'upi'
                                        ? AppColors.accentViolet
                                        : AppColors.textSecondary,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _method = 'bank'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _method == 'bank'
                                ? AppColors.accentViolet.withValues(alpha: 0.12)
                                : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _method == 'bank'
                                  ? AppColors.accentViolet
                                  : AppColors.glassBorder,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.account_balance_rounded,
                                  color: _method == 'bank'
                                      ? AppColors.accentViolet
                                      : AppColors.textMuted),
                              const SizedBox(height: 4),
                              Text('Bank',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: _method == 'bank'
                                        ? AppColors.accentViolet
                                        : AppColors.textSecondary,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate(delay: 150.ms).fadeIn(),

                const SizedBox(height: 20),

                if (_method == 'upi') ...[
                  TextFormField(
                    controller: _upiController,
                    decoration: const InputDecoration(
                      labelText: 'UPI ID *',
                      hintText: 'yourname@upi',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'UPI ID required';
                      if (!v.contains('@')) return 'Invalid UPI ID';
                      return null;
                    },
                  ),
                ] else ...[
                  TextFormField(
                    controller: _holderController,
                    decoration: const InputDecoration(
                      labelText: 'Account Holder Name *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        v?.isEmpty == true ? 'Name required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _accountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Account Number *',
                      prefixIcon: Icon(Icons.credit_card_rounded),
                    ),
                    validator: (v) =>
                        v?.isEmpty == true ? 'Account number required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ifscController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'IFSC Code *',
                      prefixIcon: Icon(Icons.code_rounded),
                    ),
                    validator: (v) =>
                        v?.isEmpty == true ? 'IFSC required' : null,
                  ),
                ],

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitWithdrawal,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Request Withdrawal'),
                  ),
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.accentRed),
              const SizedBox(height: 12),
              const Text('Failed to load wallet data'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(currentUserDataProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

