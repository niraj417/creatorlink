import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _routes = ['/home', '/campaigns', '/wallet', '/profile'];

  int _indexFromLocation(String location) {
    for (var i = _routes.length - 1; i >= 0; i--) {
      if (location.startsWith(_routes[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _indexFromLocation(location);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          border: Border(
            top: BorderSide(color: AppColors.glassBorder, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: NavigationBar(
            selectedIndex: selectedIndex,
            elevation: 0,
            backgroundColor: Colors.transparent,
            indicatorColor: AppColors.accentViolet.withValues(alpha: 0.15),
            onDestinationSelected: (i) {
              context.go(_routes[i]);
            },
            labelBehavior:
                NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.campaign_outlined),
                selectedIcon: Icon(Icons.campaign_rounded),
                label: 'Campaigns',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Wallet',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
