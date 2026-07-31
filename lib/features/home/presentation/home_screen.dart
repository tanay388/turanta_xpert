import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/notifications/pending_deep_link.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../jobs/data/jobs_api.dart';
import '../../jobs/presentation/jobs_controller.dart';
import '../../jobs/presentation/live_job_timer.dart';
import '../data/summary_api.dart';
import 'availability_controller.dart';

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

    final session = ref.watch(authProvider).valueOrNull;
    final attendance = ref.watch(attendanceProvider);
    final jobsState = ref.watch(jobsProvider);
    final nextJob = jobsState.nextJob;
    final activeJobs = jobsState.jobs.length;
    final displayName = session?.profile?.displayName ?? 'Partner';

    final shift = attendance.currentShift?.shift;

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(
        title: Text(ref.t('home.greeting', {'name': displayName})),
        actions: [
          IconButton(
            tooltip: ref.t('home.emergency'),
            onPressed: () => _showEmergencySheet(context, ref),
            icon: const Icon(Icons.sos_rounded, color: XpertColors.danger),
          ),
          IconButton(
            tooltip: ref.t('profile.title'),
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            tooltip: ref.t('pending.sign_out'),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todaySummaryProvider);
          await ref.read(attendanceProvider.notifier).refresh();
          await ref.read(jobsProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(XpertSpacing.lg),
          children: [
            Text(
              DateFormat('EEEE, d MMM').format(DateTime.now()),
              style: XpertTypography.caption,
            ),
            if (shift != null) ...[
              const SizedBox(height: XpertSpacing.xs),
              Text(
                ref.t('home.shift_hours', {'hours': shift.displayWindow}),
                style: XpertTypography.caption,
              ),
              Text(
                shift.name,
                style: XpertTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: XpertSpacing.lg),
            const _TodayStatsRow(),
            const SizedBox(height: XpertSpacing.lg),
            _AvailabilityCard(attendance: attendance),
            const SizedBox(height: XpertSpacing.lg),
            Text(ref.t('jobs.home.next_title'), style: XpertTypography.label),
            const SizedBox(height: XpertSpacing.sm),
            _NextJobCard(
              job: nextJob,
              loading: jobsState.loading && nextJob == null,
              extraCount: activeJobs > 1 ? activeJobs - 1 : 0,
            ),
            const SizedBox(height: XpertSpacing.lg),
            const _ReferCard(),
            const SizedBox(height: XpertSpacing.sm),
            _AttendanceLink(),
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

/// Today's stats (jobs done, hours, earnings, rating) from
/// `GET /partner/summary/today`. Earnings/rating are placeholders until
/// roadmap plans 03/04 land.
class _TodayStatsRow extends ConsumerWidget {
  const _TodayStatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(todaySummaryProvider);
    final data = summary.valueOrNull;

    String earnings;
    if (data == null || data.earnings <= 0) {
      earnings = '—';
    } else {
      earnings = '₹${data.earnings.toStringAsFixed(0)}';
    }
    final rating = data?.rating;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.check_circle_outline,
            label: ref.t('home.stats.jobs'),
            value: '${data?.jobsDone ?? 0}',
          ),
        ),
        const SizedBox(width: XpertSpacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.schedule,
            label: ref.t('home.stats.hours'),
            value: (data?.hoursWorked ?? 0)
                .toStringAsFixed((data?.hoursWorked ?? 0) % 1 == 0 ? 0 : 1),
          ),
        ),
        const SizedBox(width: XpertSpacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.account_balance_wallet_outlined,
            label: ref.t('home.stats.earnings'),
            value: earnings,
          ),
        ),
        const SizedBox(width: XpertSpacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.star_outline,
            label: ref.t('home.stats.rating'),
            value: rating == null ? '—' : rating.toStringAsFixed(1),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: XpertSpacing.md,
        horizontal: XpertSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.md),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: XpertColors.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: XpertTypography.label.copyWith(fontSize: 16),
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: XpertTypography.caption.copyWith(fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Refer & earn entry point. Routes to a placeholder until roadmap plan 08.
class _ReferCard extends ConsumerWidget {
  const _ReferCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: XpertColors.secondary,
      borderRadius: BorderRadius.circular(XpertRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(XpertRadius.md),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.t('common.coming_soon'))),
        ),
        child: Padding(
          padding: const EdgeInsets.all(XpertSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.card_giftcard_rounded,
                  color: XpertColors.primary),
              const SizedBox(width: XpertSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ref.t('home.refer.title'),
                        style: XpertTypography.label),
                    const SizedBox(height: 2),
                    Text(ref.t('home.refer.subtitle'),
                        style: XpertTypography.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: XpertColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Link to attendance history (previously a quick-action chip).
class _AttendanceLink extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: XpertColors.surface,
      borderRadius: BorderRadius.circular(XpertRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(XpertRadius.md),
        onTap: () => context.push('/attendance'),
        child: Padding(
          padding: const EdgeInsets.all(XpertSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.history, color: XpertColors.onSurface),
              const SizedBox(width: XpertSpacing.md),
              Expanded(
                child: Text(ref.t('home.attendance_history'),
                    style: XpertTypography.label),
              ),
              const Icon(Icons.chevron_right, color: XpertColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextJobCard extends ConsumerWidget {
  const _NextJobCard({
    required this.job,
    required this.loading,
    required this.extraCount,
  });

  final PartnerJob? job;
  final bool loading;
  final int extraCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: XpertColors.surface,
          borderRadius: BorderRadius.circular(XpertRadius.md),
        ),
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (job == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(XpertSpacing.md),
        decoration: BoxDecoration(
          color: XpertColors.surface,
          borderRadius: BorderRadius.circular(XpertRadius.md),
          border: Border.all(color: XpertColors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: XpertColors.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.work_outline),
            ),
            const SizedBox(width: XpertSpacing.md),
            Expanded(
              child: Text(
                ref.t('jobs.home.none'),
                style: XpertTypography.caption,
              ),
            ),
          ],
        ),
      );
    }

    final when = DateFormat('EEE, d MMM · h:mm a')
        .format(job!.scheduledStartAt.toLocal());
    final statusLabel = job!.isInProgress
        ? ref.t('jobs.status.in_progress')
        : ref.t('jobs.status.assigned');
    final statusColor =
        job!.isInProgress ? XpertColors.primary : XpertColors.success;
    final address = job!.displayAddress.trim();

    return Material(
      color: XpertColors.surface,
      borderRadius: BorderRadius.circular(XpertRadius.md),
      child: InkWell(
        onTap: () => context.push('/jobs/${job!.id}'),
        borderRadius: BorderRadius.circular(XpertRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(XpertSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job!.serviceName ?? ref.t('jobs.service_fallback'),
                      style: XpertTypography.label.copyWith(fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(XpertRadius.pill),
                    ),
                    child: Text(
                      statusLabel,
                      style: XpertTypography.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: XpertSpacing.sm),
              if (job!.isInProgress) ...[
                LiveJobTimerCard(job: job!, compact: true),
                const SizedBox(height: XpertSpacing.sm),
              ] else
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 16,
                      color: XpertColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(when, style: XpertTypography.caption),
                    ),
                  ],
                ),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: XpertColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address.replaceAll('\n', ' · '),
                        style: XpertTypography.caption,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: XpertSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => context.push('/jobs/${job!.id}'),
                      child: Text(ref.t('jobs.home.open')),
                    ),
                  ),
                  if (extraCount > 0) ...[
                    const SizedBox(width: XpertSpacing.sm),
                    TextButton(
                      onPressed: () => context.go('/jobs'),
                      child: Text(
                        ref.t('jobs.home.more', {'count': '$extraCount'}),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailabilityCard extends ConsumerWidget {
  const _AvailabilityCard({required this.attendance});
  final AttendanceState attendance;

  Future<void> _checkIn(BuildContext context, WidgetRef ref) async {
    final blocked = await ref.read(attendanceProvider.notifier).checkIn();
    if (!context.mounted) return;
    if (blocked != null) {
      final msg = ref.read(attendanceProvider).error ??
          ref.t('home.check_in_outside_hours', {
            'hours': attendance.currentShift?.shift.displayWindow ?? '—',
          });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _checkOut(BuildContext context, WidgetRef ref) async {
    final scheduledEnd = attendance.snapshot?.scheduledEndAt ??
        attendance.currentShift?.scheduledEndAt;
    final isEarly =
        scheduledEnd != null && DateTime.now().isBefore(scheduledEnd);

    String? reasonCode;
    String? reasonText;
    if (isEarly) {
      final result = await showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => const _EarlyCheckoutSheet(),
      );
      if (result == null) return;
      reasonCode = result['code'];
      reasonText = result['text'];
    }

    final blocked = await ref.read(attendanceProvider.notifier).checkOut(
          reasonCode: reasonCode,
          reasonText: reasonText,
        );
    if (!context.mounted) return;
    if (blocked != null) {
      final msg = ref.read(attendanceProvider).error ?? 'Checkout failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _toggleBreak(BuildContext context, WidgetRef ref) async {
    final err = attendance.isOnBreak
        ? await ref.read(attendanceProvider.notifier).endBreak()
        : await ref.read(attendanceProvider.notifier).startBreak();
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = attendance.isCheckedIn && !attendance.isOnBreak;
    final isOnBreak = attendance.isOnBreak;
    final shiftMissed = attendance.isShiftMissed;
    final onLeave = attendance.isOnLeaveToday;
    final blocked = attendance.isCheckInBlocked;

    final statusColor = isOnBreak
        ? const Color(0xFFE65100)
        : isOnline
            ? XpertColors.online
            : shiftMissed
                ? XpertColors.danger
                : onLeave
                    ? const Color(0xFF1565C0)
                    : XpertColors.offline;
    final statusLabel = isOnBreak
        ? ref.t('home.break_on_title')
        : isOnline
            ? ref.t('home.checked_in')
            : shiftMissed
                ? ref.t('home.status_shift_missed')
                : onLeave
                    ? ref.t('home.status_on_leave')
                    : ref.t('home.checked_out');

    String subtitle;
    final hours = attendance.currentShift?.shift.displayWindow ?? '—';
    if (isOnBreak) {
      subtitle = ref.t('home.break_in_progress_hint');
    } else if (isOnline) {
      subtitle = ref.t('home.online_hint');
    } else if (shiftMissed) {
      subtitle = ref.t('home.shift_missed_body', {'hours': hours});
    } else if (onLeave) {
      subtitle = ref.t('home.on_leave_body');
    } else {
      subtitle = ref.t('home.offline_hint');
    }

    return Container(
      padding: const EdgeInsets.all(XpertSpacing.lg),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: XpertSpacing.sm),
              Text(
                statusLabel,
                style: XpertTypography.label.copyWith(
                  color: statusColor,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (attendance.loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: XpertSpacing.sm),
          Text(subtitle, style: XpertTypography.caption),
          const SizedBox(height: XpertSpacing.lg),
          if (!attendance.isCheckedIn)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    blocked ? XpertColors.border : XpertColors.online,
                foregroundColor:
                    blocked ? XpertColors.onSurface.withValues(alpha: 0.5) : Colors.white,
                disabledBackgroundColor: XpertColors.border,
                disabledForegroundColor:
                    XpertColors.onSurface.withValues(alpha: 0.5),
              ),
              onPressed: (attendance.loading || blocked)
                  ? null
                  : () => _checkIn(context, ref),
              child: Text(
                blocked
                    ? (shiftMissed
                        ? ref.t('home.check_in_blocked_missed')
                        : onLeave
                            ? ref.t('home.check_in_blocked_leave')
                            : ref.t('home.check_in_blocked'))
                    : ref.t('home.check_in'),
              ),
            )
          else ...[
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: XpertColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: attendance.loading
                  ? null
                  : () => _checkOut(context, ref),
              child: Text(ref.t('home.check_out')),
            ),
            const SizedBox(height: XpertSpacing.md),
            _BreakControl(
              isOnBreak: isOnBreak,
              breakUsed: attendance.breakUsed,
              breakStartedAt: attendance.snapshot?.breakStartedAt ??
                  DateTime.tryParse(
                    ((attendance.breakSummary?['break']
                                as Map<String, dynamic>?)?['startedAt'])
                            ?.toString() ??
                        '',
                  ),
              capMinutes:
                  (attendance.breakSummary?['capMinutes'] as num?)?.toInt() ??
                      45,
              fallbackRemainingSeconds:
                  (attendance.breakSummary?['remainingSeconds'] as num?)
                      ?.toInt(),
              loading: attendance.loading,
              onToggle: () => _toggleBreak(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakControl extends ConsumerStatefulWidget {
  const _BreakControl({
    required this.isOnBreak,
    required this.breakUsed,
    required this.breakStartedAt,
    required this.capMinutes,
    required this.fallbackRemainingSeconds,
    required this.loading,
    required this.onToggle,
  });

  final bool isOnBreak;
  final bool breakUsed;
  final DateTime? breakStartedAt;
  final int capMinutes;
  final int? fallbackRemainingSeconds;
  final bool loading;
  final VoidCallback onToggle;

  @override
  ConsumerState<_BreakControl> createState() => _BreakControlState();
}

class _BreakControlState extends ConsumerState<_BreakControl> {
  static const _breakColor = Color(0xFFE65100);
  static const _breakBg = Color(0xFFFFF3E0);
  static const _breakBorder = Color(0xFFFFB74D);

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _BreakControl old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    if (widget.isOnBreak) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  /// Resolves the moment the break should end, so we can tick down locally.
  DateTime? get _endsAt {
    if (widget.breakStartedAt != null) {
      return widget.breakStartedAt!.add(Duration(minutes: widget.capMinutes));
    }
    if (widget.fallbackRemainingSeconds != null) {
      // No start time available: count down from first build.
      _fallbackEnd ??= DateTime.now()
          .add(Duration(seconds: widget.fallbackRemainingSeconds!));
      return _fallbackEnd;
    }
    return null;
  }

  DateTime? _fallbackEnd;

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isOnBreak = widget.isOnBreak;
    final breakUsed = widget.breakUsed;
    final loading = widget.loading;
    final onToggle = widget.onToggle;

    // Active break: prominent card with live countdown + End break button.
    if (isOnBreak) {
      final endsAt = _endsAt;
      final remaining = endsAt == null
          ? null
          : endsAt.difference(DateTime.now());
      final overrun = remaining != null && remaining.isNegative;
      final remainingText = remaining == null
          ? ref.t('home.break_running')
          : overrun
              ? ref.t('home.break_overrun',
                  {'time': _format(remaining.abs())})
              : ref.t('home.break_remaining', {
                  'time': _format(remaining),
                  'cap': '${widget.capMinutes}',
                });
      final accent = overrun ? XpertColors.danger : _breakColor;
      return Container(
        padding: const EdgeInsets.all(XpertSpacing.md),
        decoration: BoxDecoration(
          color: overrun
              ? XpertColors.danger.withValues(alpha: 0.08)
              : _breakBg,
          borderRadius: BorderRadius.circular(XpertRadius.md),
          border: Border.all(
              color: overrun
                  ? XpertColors.danger.withValues(alpha: 0.5)
                  : _breakBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.free_breakfast_rounded, color: accent),
                const SizedBox(width: XpertSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overrun
                            ? ref.t('home.break_over_title')
                            : ref.t('home.break_on_title'),
                        style: XpertTypography.label.copyWith(
                          color: accent,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        remainingText,
                        style: XpertTypography.caption.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: XpertSpacing.md),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
              ),
              onPressed: loading ? null : onToggle,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(ref.t('home.break_end')),
            ),
          ],
        ),
      );
    }

    // Already used today: subtle disabled note.
    if (breakUsed) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: XpertSpacing.md,
          vertical: XpertSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: XpertColors.background,
          borderRadius: BorderRadius.circular(XpertRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 18, color: XpertColors.muted),
            const SizedBox(width: XpertSpacing.sm),
            Expanded(
              child: Text(
                ref.t('home.break_used'),
                style: XpertTypography.caption.copyWith(color: XpertColors.muted),
              ),
            ),
          ],
        ),
      );
    }

    // Available: clear call to action with icon + hint.
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: _breakColor,
        side: const BorderSide(color: _breakBorder),
        padding: const EdgeInsets.symmetric(vertical: XpertSpacing.sm + 2),
      ),
      onPressed: loading ? null : onToggle,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.free_breakfast_rounded, size: 20),
          const SizedBox(width: XpertSpacing.sm),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ref.t('home.break_take_title'),
                style: XpertTypography.label.copyWith(
                  color: _breakColor,
                  fontSize: 15,
                ),
              ),
              Text(
                ref.t('home.break_take_hint'),
                style: XpertTypography.caption.copyWith(
                  color: _breakColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EarlyCheckoutSheet extends StatefulWidget {
  const _EarlyCheckoutSheet();

  @override
  State<_EarlyCheckoutSheet> createState() => _EarlyCheckoutSheetState();
}

class _EarlyCheckoutSheetState extends State<_EarlyCheckoutSheet> {
  String _code = 'PERSONAL_EMERGENCY';
  final _text = TextEditingController();

  static const _reasons = {
    'MEDICAL': 'Medical',
    'FAMILY_EMERGENCY': 'Family emergency',
    'FEELING_UNWELL': 'Feeling unwell',
    'PERSONAL_EMERGENCY': 'Personal emergency',
    'OTHER': 'Other',
  };

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: XpertSpacing.lg,
        right: XpertSpacing.lg,
        top: XpertSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + XpertSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Early checkout reason', style: XpertTypography.title.copyWith(fontSize: 20)),
          const SizedBox(height: XpertSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _code,
            items: _reasons.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _code = v ?? _code),
          ),
          if (_code == 'OTHER') ...[
            const SizedBox(height: XpertSpacing.sm),
            TextField(
              controller: _text,
              decoration: const InputDecoration(hintText: 'Please describe'),
              maxLines: 2,
            ),
          ],
          const SizedBox(height: XpertSpacing.lg),
          FilledButton(
            onPressed: () {
              if (_code == 'OTHER' && _text.text.trim().isEmpty) return;
              Navigator.pop(context, {
                'code': _code,
                'text': _text.text.trim(),
              });
            },
            child: const Text('Confirm checkout'),
          ),
        ],
      ),
    );
  }
}

