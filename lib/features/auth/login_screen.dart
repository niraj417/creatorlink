import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/router/app_router.dart';
import '../../core/providers/firebase_providers.dart';
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

  // Email auth state
  bool _showEmailForm = false;
  bool _isSignUp = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Navigate user based on Firestore role/onboarding data.
  /// After sign-in the GoRouter redirect guard will fire automatically;
  /// we only call context.go() as a fallback if the guard hasn't fired yet.
  Future<void> _navigateAfterSignIn(User user) async {
    try {
      final firestore = ref.read(firestoreProvider);
      final userRef = firestore.collection('users').doc(user.uid);
      final userDoc = await userRef.get();

      if (!mounted) return;

      if (!userDoc.exists) {
        // New user — create base document (check admin by email)
        final role = user.email == 'kingniraj417@gmail.com'
            ? 'admin'
            : 'unknown';
        await userRef.set({
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'photoURL': user.photoURL ?? '',
          'role': role,
          'onboarding': null,
          'createdAt': FieldValue.serverTimestamp(),
          'banned': false,
          'walletPoints': 0,
        });
        if (!mounted) return;
        // Router guard will pick up auth state change; navigate explicitly
        // in case the guard already ran before Firestore doc was written.
        if (role == 'admin') {
          context.go('/admin/flags');
        } else {
          context.go('/onboarding');
        }
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final role = userData['role'] as String? ?? 'unknown';
      final onboarding = userData['onboarding'];

      if (!mounted) return;
      if (role == 'admin') {
        context.go('/admin/flags');
      } else if (role == 'unknown' || onboarding == null) {
        context.go('/onboarding');
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load profile: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

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

      await _navigateAfterSignIn(user);
    } catch (e) {
      setState(() {
        _error = 'Google sign-in failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }

    if (_isSignUp && password != _confirmPasswordController.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    if (_isSignUp && password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      UserCredential userCredential;
      if (_isSignUp) {
        userCredential = await ref
            .read(firebaseAuthProvider)
            .createUserWithEmailAndPassword(email: email, password: password);
      } else {
        userCredential = await ref
            .read(firebaseAuthProvider)
            .signInWithEmailAndPassword(email: email, password: password);
      }

      final user = userCredential.user;
      if (user == null) throw Exception('Authentication failed');

      await _navigateAfterSignIn(user);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _friendlyAuthError(e.code);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Sign-in failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(firebaseAuthProvider).sendPasswordResetEmail(email: email);
      setState(() {
        _isLoading = false;
        _error = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent! Check your inbox.'),
          backgroundColor: AppColors.accentGreen,
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _friendlyAuthError(e.code);
        _isLoading = false;
      });
    }
  }

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      default:
        return 'Authentication failed ($code). Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
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
                          color: AppColors.accentViolet.withValues(alpha: 0.45),
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
              const SizedBox(height: 32),
              const Column(
                children: [
                  _FeatureRow(
                    icon: Icons.campaign_outlined,
                    text: 'Discover brand campaigns tailored to your niche',
                  ),
                  SizedBox(height: 12),
                  _FeatureRow(
                    icon: Icons.currency_rupee_rounded,
                    text: 'Earn ₹ per 1,000 views — credited instantly',
                  ),
                  SizedBox(height: 12),
                  _FeatureRow(
                    icon: Icons.verified_rounded,
                    text: 'Transparent payouts with Razorpay',
                  ),
                ],
              ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.2, end: 0),
              const SizedBox(height: 28),
              // Sign-in card
              GlowyCard(
                glowColor: AppColors.accentViolet.withValues(alpha: 0.2),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Error banner
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentRed.withValues(alpha: 0.1),
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

                    // Google sign-in button
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
                      child: _isLoading && !_showEmailForm
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

                    // Divider
                    Row(
                      children: [
                        const Expanded(child: Divider(thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                        const Expanded(child: Divider(thickness: 1)),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Email toggle button / form
                    if (!_showEmailForm) ...[
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _showEmailForm = true;
                          _error = null;
                        }),
                        icon: const Icon(Icons.email_outlined, size: 18),
                        label: const Text('Sign in with Email'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.glassBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Email form
                      _buildEmailForm(),
                    ],

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

  Widget _buildEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toggle: Sign In / Sign Up
        Row(
          children: [
            _TabButton(
              label: 'Sign In',
              isSelected: !_isSignUp,
              onTap: () => setState(() {
                _isSignUp = false;
                _error = null;
              }),
            ),
            const SizedBox(width: 8),
            _TabButton(
              label: 'Create Account',
              isSelected: _isSignUp,
              onTap: () => setState(() {
                _isSignUp = true;
                _error = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Email field
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
          decoration: _inputDecoration('Email address', Icons.email_outlined),
        ),
        const SizedBox(height: 12),

        // Password field
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
          decoration: _inputDecoration(
            'Password',
            Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),

        // Confirm password (sign up only)
        if (_isSignUp) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
            decoration: _inputDecoration(
              'Confirm password',
              Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
          ),
        ],

        // Forgot password (sign in only)
        if (!_isSignUp) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _sendPasswordReset,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
              ),
              child: Text(
                'Forgot password?',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.accentViolet,
                ),
              ),
            ),
          ),
        ] else
          const SizedBox(height: 12),

        // Submit button
        ElevatedButton(
          onPressed: _isLoading ? null : _signInWithEmail,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentViolet,
            foregroundColor: Colors.white,
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
                    color: Colors.white,
                  ),
                )
              : Text(
                  _isSignUp ? 'Create Account' : 'Sign In',
                  style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                ),
        ),
        const SizedBox(height: 8),

        // Back to options
        TextButton(
          onPressed: () => setState(() {
            _showEmailForm = false;
            _error = null;
          }),
          child: Text(
            '← Back to sign-in options',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accentViolet, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    );
  }
}

// ──────────────────────────────────────────────
// Helper widgets
// ──────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentViolet.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.accentViolet : AppColors.glassBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: isSelected ? AppColors.accentViolet : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
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
            color: AppColors.accentViolet.withValues(alpha: 0.12),
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
