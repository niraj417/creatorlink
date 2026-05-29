import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/user_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/user_model.dart';

class AdminShell extends ConsumerStatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _selectedIndex = 0;

  static const _adminRoutes = [
    '/admin/flags',
    '/admin/appeals',
    '/admin/payments',
    '/admin/campaigns',
    '/admin/users',
    '/admin/analytics',
  ];

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserDataProvider);

    // Guard: only admin can view
    return userAsync.when(
      data: (user) {
        if (!user!.isAdmin) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, size: 64, color: AppColors.accentRed),
                  const SizedBox(height: 16),
                  Text('Access Denied', style: AppTextStyles.displayMedium),
                  const SizedBox(height: 8),
                  Text('Admin only area.', style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: widget.child,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              border: Border(
                top: BorderSide(color: AppColors.glassBorder),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) {
                setState(() => _selectedIndex = i);
                context.go(_adminRoutes[i]);
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.flag_outlined),
                  selectedIcon: Icon(Icons.flag_rounded),
                  label: 'Flags',
                ),
                NavigationDestination(
                  icon: Icon(Icons.gavel_outlined),
                  selectedIcon: Icon(Icons.gavel_rounded),
                  label: 'Appeals',
                ),
                NavigationDestination(
                  icon: Icon(Icons.payments_outlined),
                  selectedIcon: Icon(Icons.payments_rounded),
                  label: 'Payments',
                ),
                NavigationDestination(
                  icon: Icon(Icons.campaign_outlined),
                  selectedIcon: Icon(Icons.campaign_rounded),
                  label: 'Campaigns',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people_rounded),
                  label: 'Users',
                ),
                NavigationDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics_rounded),
                  label: 'Analytics',
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => const Scaffold(
        body: Center(child: Text('Error')),
      ),
    );
  }
}
