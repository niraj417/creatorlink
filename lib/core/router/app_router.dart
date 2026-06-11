import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/providers/user_provider.dart';
import '../../core/widgets/app_shell.dart';
import '../../features/admin/admin_shell.dart';
import '../../features/admin/admin_tabs.dart';
import '../../features/admin/appeals_tab.dart';
import '../../features/admin/flags_tab.dart';
import '../../features/admin/payments_tab.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/onboarding_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/campaigns/brand/brand_campaign_dashboard.dart';
import '../../features/campaigns/brand/campaign_create_wizard.dart';
import '../../features/campaigns/creator/campaign_detail_screen.dart';
import '../../features/campaigns/creator/campaign_list_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/posts/appeal_screen.dart';
import '../../features/posts/post_detail_screen.dart';
import '../../features/posts/submit_post_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/wallet/brand_wallet_screen.dart';
import '../../features/wallet/creator_wallet_screen.dart';
import '../../features/wallet/transaction_history_screen.dart';

// ─── Route Constants ──────────────────────────────────────────────────────────
abstract class AppRoutes {
  static const splash      = '/splash';
  static const login       = '/login';
  static const onboarding  = '/onboarding';
  static const home        = '/home';
  static const campaigns   = '/campaigns';
  static const wallet      = '/wallet';
  static const profile     = '/profile';
  static const adminFlags  = '/admin/flags';
}

// ─── Router Provider ─────────────────────────────────────────────────────────
class RouterTransitionNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterTransitionNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(currentUserDataProvider, (_, __) => notifyListeners());
  }
}

final routerTransitionNotifierProvider = Provider<RouterTransitionNotifier>((ref) {
  return RouterTransitionNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(routerTransitionNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final userData = ref.read(currentUserDataProvider);

      final isLoggedIn = authState.value != null;
      final isAuthLoading = authState.isLoading;
      final isUserLoading = userData.isLoading;

      // Wait for both auth and user data to resolve before making decisions
      if (isAuthLoading || isUserLoading) return null;

      final location = state.matchedLocation;
      final isSplash = location == '/splash';
      final isLogin = location == '/login';
      final isOnboarding = location == '/onboarding';
      final isAdminRoute = location.startsWith('/admin');

      // ── Not logged in ─────────────────────────────────────────────────────
      // Allow splash and login; redirect everything else to login
      if (!isLoggedIn && !isLogin && !isSplash) return '/login';

      // ── Logged in ─────────────────────────────────────────────────────────
      if (isLoggedIn) {
        final user = userData.value;

        // Banned users are always kicked back to login
        if (user != null && user.banned) {
          if (!isLogin) return '/login';
          return null;
        }

        // On login screen → decide where to send them
        if (isLogin) {
          if (user == null || user.needsOnboarding) return '/onboarding';
          if (user.isAdmin) return '/admin/flags';
          return '/home';
        }

        // Enforce onboarding gate (not on splash, not already on onboarding)
        if (!isSplash && !isOnboarding) {
          if (user != null && user.needsOnboarding) return '/onboarding';
        }

        // Onboarding complete → leave /onboarding
        if (isOnboarding) {
          if (user != null && !user.needsOnboarding) {
            return user.isAdmin ? '/admin/flags' : '/home';
          }
        }

        // Guard admin routes — only admins may access /admin/*
        if (isAdminRoute && user != null && !user.isAdmin) return '/home';

        // Redirect admins away from creator/brand shell routes
        if (!isAdminRoute && !isSplash && !isOnboarding && user != null && user.isAdmin) {
          return '/admin/flags';
        }
      }

      return null;
    },
    routes: [
      // ─── Auth Routes ─────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),

      // ─── Main Shell ───────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/campaigns',
            builder: (_, __) => const CampaignListScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (_, __) => const CampaignCreateWizard(),
              ),
              GoRoute(
                path: ':campaignId',
                builder: (_, state) => CampaignDetailScreen(
                  campaignId: state.pathParameters['campaignId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'dashboard',
                    builder: (_, state) => BrandCampaignDashboard(
                      campaignId: state.pathParameters['campaignId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/wallet',
            builder: (_, __) => const CreatorWalletScreen(),
            routes: [
              GoRoute(
                path: 'withdraw',
                builder: (_, __) => const WithdrawalRequestScreen(),
              ),
              GoRoute(
                path: 'history',
                builder: (_, __) => const TransactionHistoryScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),

      // ─── Posts ────────────────────────────────────────────────────
      GoRoute(
        path: '/posts/submit/:campaignId',
        builder: (_, state) => SubmitPostScreen(
          campaignId: state.pathParameters['campaignId']!,
        ),
      ),
      GoRoute(
        path: '/posts/:postId',
        builder: (_, state) => PostDetailScreen(
          postId: state.pathParameters['postId']!,
        ),
        routes: [
          GoRoute(
            path: 'appeal',
            builder: (_, state) => AppealScreen(
              postId: state.pathParameters['postId']!,
            ),
          ),
        ],
      ),

      // ─── Admin ────────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin/flags',
            builder: (_, __) => const FlagsTab(),
          ),
          GoRoute(
            path: '/admin/appeals',
            builder: (_, __) => const AppealsTab(),
          ),
          GoRoute(
            path: '/admin/payments',
            builder: (_, __) => const PaymentsTab(),
          ),
          GoRoute(
            path: '/admin/campaigns',
            builder: (_, __) => const CampaignsAdminTab(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (_, __) => const UsersAdminTab(),
          ),
          GoRoute(
            path: '/admin/analytics',
            builder: (_, __) => const AnalyticsAdminTab(),
          ),
        ],
      ),
    ],
  );
});
