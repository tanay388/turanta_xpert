import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/i18n/context_t.dart';
import '../../core/theme/xpert_tokens.dart';
import '../../features/jobs/presentation/jobs_controller.dart';

/// Persistent bottom-nav shell: Check-in / Jobs / Leaves / Paisa / Target.
/// Each tab keeps its own stack via [StatefulNavigationShell] branches.
class XpertShellScaffold extends ConsumerWidget {
  const XpertShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    // The bar is used with a thumb, often with gloves on and without looking;
    // a click confirms the tap landed before the screen has redrawn.
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
      // Re-tapping the current tab pops back to its root.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(jobsProvider).jobs;
    final live = jobs.where((j) => j.isAssigned || j.isInProgress).length;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        // The tabs sit on white screens as often as on the grey wash, so the
        // bar carries its own edge rather than relying on what is above it.
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE8EDF1))),
          boxShadow: [
            BoxShadow(
              color: Color(0x0F0B1720),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        // The bar has five fixed slots, so a large system font wraps "Check-in"
        // onto two lines and squeezes the row. Everything else still scales.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onTap,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: ref.t('nav.checkin'),
              ),
              NavigationDestination(
                // A partner's jobs are the thing they are waiting on, so the tab
                // says how many are theirs right now without being opened.
                icon: _JobsIcon(count: live, icon: Icons.work_outline),
                selectedIcon: _JobsIcon(count: live, icon: Icons.work_rounded),
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
        ),
      ),
    );
  }
}

class _JobsIcon extends StatelessWidget {
  const _JobsIcon({required this.count, required this.icon});

  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return Icon(icon);
    return Badge.count(
      count: count,
      backgroundColor: XpertColors.danger,
      textColor: Colors.white,
      child: Icon(icon),
    );
  }
}
