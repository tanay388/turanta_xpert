import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/config/store_links.dart';
import '../../../core/network/app_version_gate.dart';
import '../../../core/notifications/pending_deep_link.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../jobs/presentation/jobs_controller.dart';
import '../../sos/presentation/sos_controller.dart';
import '../../sos/presentation/sos_prompt.dart';
import '../../sos/presentation/widgets/sos_active_card.dart';
import '../data/summary_api.dart';
import 'availability_controller.dart';
import 'widgets/active_job_card.dart';
import 'widgets/home_header.dart';
import 'widgets/update_available_sheet.dart';
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
      unawaited(ref.read(sosProvider.notifier).refresh());
      _consumeDeepLink();
      unawaited(_offerUpdate());
    });
  }

  /// Offered here rather than at launch: a partner opening the app to start a
  /// shift should reach their jobs first, and a sheet over the splash screen
  /// reads like a failure to load.
  Future<void> _offerUpdate() async {
    // Awaited, not read: the check is still in flight on a cold start, and
    // reading it early meant a slow connection silently skipped the offer for
    // the whole session.
    final AppVersionStatus status;
    try {
      status = await ref.read(appVersionGateProvider.future);
    } catch (_) {
      return;
    }
    if (!status.updateAvailable) return;
    // Nothing to offer on a platform with no store listing — Xpert is not on
    // the App Store, so an iPhone would get a sheet whose button does nothing.
    if (StoreLinks.forThisPlatform == null) return;
    if (!await shouldOfferUpdate(status.latestBuild)) return;
    if (!mounted) return;
    await showUpdateAvailableSheet(context, ref, status.latestBuild);
  }

  void _consumeDeepLink() {
    final link = ref.read(pendingDeepLinkProvider);
    if (link == null || link.isEmpty) return;
    ref.read(pendingDeepLinkProvider.notifier).state = null;
    if (!mounted) return;
    _openDeepLink(link);
  }

  /// Notification links are hand-written on the server, which deploys on its
  /// own schedule and also serves the customer app — nothing checks them
  /// against this router. An unroutable one leaves the partner on home rather
  /// than throwing "no routes for location". Mirrors the consumer app's
  /// `_consumeDeepLink`.
  void _openDeepLink(String link) {
    bool routable;
    try {
      routable = !GoRouter.of(
        context,
      ).configuration.findMatch(Uri.parse(link)).isError;
    } catch (_) {
      routable = false;
    }
    if (!routable) {
      debugPrint('[deeplink] no route for "$link" — ignored');
      return;
    }
    context.push(link);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(pendingDeepLinkProvider, (_, next) {
      if (next == null || next.isEmpty) return;
      ref.read(pendingDeepLinkProvider.notifier).state = null;
      unawaited(ref.read(jobsProvider.notifier).refresh(silent: true));
      _openDeepLink(next);
    });

    final attendance = ref.watch(attendanceProvider);
    final jobsState = ref.watch(jobsProvider);
    final ongoingJob = jobsState.ongoingJob;
    final blockedByJob = jobsState.blocksShiftExit;
    // Once the running job is the hero, the next-job slot shows what comes
    // after it instead of printing the same job twice.
    final nextJob = ongoingJob == null
        ? jobsState.nextJob
        : jobsState.upcomingJob;
    final shown = (ongoingJob == null ? 0 : 1) + (nextJob == null ? 0 : 1);
    final extraCount = (jobsState.jobs.length - shown).clamp(0, 99);

    // No AppBar here, so nothing else would set the status-bar icons; the
    // header is the wash, so they are dark.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: XpertColors.heroTop,
        body: Column(
          children: [
            HomeHeader(
              onEmergency: () => showSosPrompt(context, ref),
              showEmergency: ref.watch(attendanceProvider).isCheckedIn,
            ),
            if (ref.watch(sosProvider).phase != SosPhase.idle)
              const SosActiveCard(),
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
                      // A job in progress outranks the shift: it leads, and
                      // the shift card drops under it.
                      if (ongoingJob != null) ...[
                        _SectionLabel(text: ref.t('jobs.home.ongoing_title')),
                        const SizedBox(height: XpertSpacing.sm),
                        ActiveJobCard(job: ongoingJob),
                        const SizedBox(height: XpertSpacing.lg),
                      ],
                      ShiftCard(
                        attendance: attendance,
                        blockedByJob: blockedByJob,
                      ),
                      // One section, not two stacked ones: a running job and
                      // the next job are never both the thing to read first,
                      // so whichever applies gets the header and the other is
                      // simply absent.
                      if (ongoingJob == null || nextJob != null) ...[
                        const SizedBox(height: XpertSpacing.lg),
                        _SectionLabel(text: ref.t('jobs.home.next_title')),
                        const SizedBox(height: XpertSpacing.sm),
                        NextJobCard(
                          job: nextJob,
                          loading: jobsState.loading && nextJob == null,
                          extraCount: extraCount,
                          checkedIn: attendance.isCheckedIn,
                        ),
                      ],
                      const SizedBox(height: XpertSpacing.lg),
                      _SectionLabel(text: ref.t('home.today.title')),
                      const SizedBox(height: XpertSpacing.sm),
                      const TodayCard(),
                      const SizedBox(height: XpertSpacing.lg),
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
