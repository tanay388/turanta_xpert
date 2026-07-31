import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/i18n/context_t.dart';
import '../../core/theme/xpert_tokens.dart';

/// Persistent bottom-nav shell matching the competitor's 5 tabs:
/// Check-in / Jobs / Leaves / Paisa / Target. Each tab keeps its own stack via
/// [StatefulNavigationShell] branches.
class XpertShellScaffold extends ConsumerWidget {
  const XpertShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      // Re-tapping the current tab pops back to its root.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        backgroundColor: XpertColors.surface,
        indicatorColor: XpertColors.secondary,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: ref.t('nav.checkin'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.work_outline),
            selectedIcon: const Icon(Icons.work_rounded),
            label: ref.t('nav.jobs'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.event_busy_outlined),
            selectedIcon: const Icon(Icons.event_busy_rounded),
            label: ref.t('nav.leaves'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
            label: ref.t('nav.paisa'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.emoji_events_outlined),
            selectedIcon: const Icon(Icons.emoji_events_rounded),
            label: ref.t('nav.target'),
          ),
        ],
      ),
    );
  }
}
