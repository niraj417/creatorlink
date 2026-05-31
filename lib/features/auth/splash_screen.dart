import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final auth = ref.read(authStateProvider);
    if (auth.value == null) {
      context.go('/login');
      return;
    }

    // Check user profile
    final user = ref.read(currentUserDataProvider).value;
    if (user == null || user.needsOnboarding) {
      context.go('/onboarding');
    } else if (user.isAdmin) {
      context.go('/admin/flags');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo mark
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accentViolet, AppColors.accentGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentViolet.withValues(alpha: 0.5),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.link_rounded,
                color: Colors.white,
                size: 44,
              ),
            )
                .animate()
                .scale(begin: const Offset(0.5, 0.5), duration: 600.ms, curve: Curves.elasticOut)
                .fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            Text(
              'CreatorLink',
              style: AppTextStyles.displayLarge.copyWith(
                foreground: Paint()
                  ..shader = const LinearGradient(
                    colors: [AppColors.accentViolet, AppColors.accentGreen],
                  ).createShader(const Rect.fromLTWH(0, 0, 200, 40)),
              ),
            )
                .animate(delay: 300.ms)
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.3, end: 0),

            const SizedBox(height: 8),

            Text(
              'Where creators meet brands',
              style: AppTextStyles.bodyMedium,
            )
                .animate(delay: 500.ms)
                .fadeIn(duration: 500.ms),

            const SizedBox(height: 60),

            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accentViolet.withValues(alpha: 0.6),
              ),
            ).animate(delay: 800.ms).fadeIn(),
          ],
        ),
      ),
    );
  }
}
