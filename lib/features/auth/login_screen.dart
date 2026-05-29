import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glowy_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final googleSignIn = GoogleSignIn();
      final googleAccount = await googleSignIn.signIn();
      if (googleAccount == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleAccount.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await ref
          .read(firebaseAuthProvider)
          .signInWithCredential(credential);

      final user = userCredential.user;
      if (user == null) throw Exception('Sign-in failed');

      // Create/update user document if new
      final firestore = ref.read(firestoreProvider);
      final userDoc = await firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // New user — create base document; Cloud Function will set role for admin
        await firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName': user.displayName ?? '',
          'photoURL': user.photoURL ?? '',
          'role': 'unknown',
          'createdAt': FieldValue.serverTimestamp(),
          'banned': false,
          'walletPoints': 0,
        });
        if (!mounted) return;
        context.go('/onboarding');
        return;
      }

      // Existing user
      final userData = userDoc.data() as Map<String, dynamic>;
      final role = userData['role'] as String? ?? 'unknown';
      final onboarding = userData['onboarding'];

      if (!mounted) return;
      if (role == 'unknown' || onboarding == null) {
        context.go('/onboarding');
      } else if (role == 'admin') {
        context.go('/admin/flags');
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      setState(() {
        _error = 'Sign-in failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Header
              Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.accentViolet, AppColors.accentGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentViolet.withOpacity(0.45),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.link_rounded, color: Colors.white, size: 40),
                  ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 20),
                  Text('CreatorLink', style: AppTextStyles.displayLarge)
                      .animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 8),
                  Text(
                    'India\'s creator-brand marketplace',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ).animate(delay: 350.ms).fadeIn(),
                ],
              ),
              const Spacer(flex: 2),
              // Features list
              Column(
                children: [
                  _FeatureRow(
                    icon: Icons.campaign_outlined,
                    text: 'Discover brand campaigns tailored to your niche',
                  ),
                  const SizedBox(height: 12),
                  _FeatureRow(
                    icon: Icons.currency_rupee_rounded,
                    text: 'Earn ₹ per 1,000 views — credited instantly',
                  ),
                  const SizedBox(height: 12),
                  _FeatureRow(
                    icon: Icons.verified_rounded,
                    text: 'Transparent payouts with Razorpay',
                  ),
                ],
              ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.2, end: 0),
              const Spacer(),
              // Sign-in card
              GlowyCard(
                glowColor: AppColors.accentViolet.withOpacity(0.2),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.accentRed),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1F1F1F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accentViolet,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google G logo (using text as placeholder)
                                const Text(
                                  'G',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4285F4),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Continue with Google',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: const Color(0xFF1F1F1F),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'By continuing you agree to our Terms & Privacy Policy',
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ).animate(delay: 700.ms).fadeIn().slideY(begin: 0.3, end: 0),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.accentViolet.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.accentViolet, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: AppTextStyles.bodyMedium),
        ),
      ],
    );
  }
}
