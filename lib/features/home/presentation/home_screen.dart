import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/notifications/pending_deep_link.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../jobs/presentation/jobs_controller.dart';
import '../data/summary_api.dart';
import 'availability_controller.dart';
import 'widgets/home_header.dart';
import 'widgets/home_nav_rows.dart';
import 'widgets/next_job_card.dart';
import 'widgets/shift_card.dart';
import 'widgets/today_card.dart';

/// The Check-in tab.
///
/// Reads top to bottom in the order a partner needs it: who and when (header),
/// am I on shift (hero), what did today give me, what is next, everything
/// else. Each of those is its own widget under `widgets/` — this file is the
/// running order and the plumbing, nothing more.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final jobs = ref.read(jobsProvider.notifier);
      jobs.refresh();
      jobs.startPolling();
      _consumeDeepLink();
    });
  }

  void _consumeDeepLink() {
    final link = ref.read(pendingDeepLinkProvider);
    if (link == null || link.isEmpty) return;
    ref.read(pendingDeepLinkProvider.notifier).state = null;
    if (!mounted) return;
    context.push(link);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(pendingDeepLinkProvider, (_, next) {
      if (next == null || next.isEmpty) return;
      ref.read(pendingDeepLinkProvider.notifier).state = null;
      unawaited(ref.read(jobsProvider.notifier).refresh(silent: true));
      context.push(next);
    });

    final attendance = ref.watch(attendanceProvider);
    final jobsState = ref.watch(jobsProvider);
    final nextJob = jobsState.nextJob;
    final activeJobs = jobsState.jobs.length;

    // The app's AppBarTheme asks for dark status-bar icons, which is right for
    // every other screen and invisible against this one's dark header. With no
    // AppBar here, nothing would otherwise say so.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: XpertColors.canvas,
        body: Column(
          children: [
            HomeHeader(onEmergency: () => _showEmergencySheet(context, ref)),
            // The sheet rises over the header's dark field, the same join the
            // sign-in screen makes. It also owns the scroll, so the header stays
            // put while the day's content moves under it.
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: XpertColors.background,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(XpertRadius.sheetTop),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(todaySummaryProvider);
                    await ref.read(attendanceProvider.notifier).refresh();
                    await ref.read(jobsProvider.notifier).refresh();
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      XpertSpacing.lg,
                      XpertSpacing.lg,
                      XpertSpacing.lg,
                      XpertSpacing.xxl,
                    ),
                    children: [
                      ShiftCard(attendance: attendance),
                      const SizedBox(height: XpertSpacing.xl),
                      _SectionLabel(text: ref.t('home.today.title')),
                      const SizedBox(height: XpertSpacing.sm),
                      const TodayCard(),
                      const SizedBox(height: XpertSpacing.xl),
                      _SectionLabel(text: ref.t('jobs.home.next_title')),
                      const SizedBox(height: XpertSpacing.sm),
                      NextJobCard(
                        job: nextJob,
                        loading: jobsState.loading && nextJob == null,
                        extraCount: activeJobs > 1 ? activeJobs - 1 : 0,
                      ),
                      const SizedBox(height: XpertSpacing.xl),
                      const HomeNavRows(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEmergencySheet(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.sos_rounded, color: XpertColors.danger),
        title: Text(ref.t('home.emergency')),
        content: Text(ref.t('home.emergency_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.t('home.emergency_cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: XpertColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ref.t('home.emergency_sent'))),
              );
            },
            child: Text(ref.t('home.emergency_confirm')),
          ),
        ],
      ),
    );
  }
}

/// One tracked-out line above each block. The sections used to be told apart
/// only by a gap, which is not a hierarchy.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: XpertTypography.eyebrow.copyWith(
        color: XpertColors.muted,
        letterSpacing: 1.2,
      ),
    );
  }
}
