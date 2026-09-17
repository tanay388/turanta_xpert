import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../../../core/utils/job_timer.dart';
import '../../data/jobs_api.dart';
import '../live_job_timer.dart';

/// Room the white sheet takes when it is pulled up over the hero.
const jobSheetOverlap = XpertRadius.sheetTop;

/// The top of a job: where it stands, in one sentence.
///
/// The screen used to open on the service name with a status pill under it,
/// so "is this now, later, or done?" was answered by a chip the size of a
/// caption. The stage is the headline now, on the same wash the customer's
/// booking screen opens on — the partner and the customer are looking at the
/// same job from two sides.
class JobHero extends ConsumerStatefulWidget {
  const JobHero({super.key, required this.job});

  final PartnerJob job;

  @override
  ConsumerState<JobHero> createState() => _JobHeroState();
}

class _JobHeroState extends ConsumerState<JobHero> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant JobHero old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// "Starts in 12m" goes stale, and at the start time the headline has to
  /// turn into "running late" without the partner pulling to refresh.
  void _syncTicker() {
    if (widget.job.isAssigned) {
      _ticker ??= Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final headline = _headline(ref, job, DateTime.now());

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [XpertColors.heroTop, XpertColors.heroBottom],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        XpertSpacing.lg,
        XpertSpacing.xs,
        XpertSpacing.lg,
        XpertSpacing.xl + jobSheetOverlap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _StageMark(job: job, headline: headline),
              const SizedBox(width: XpertSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref.t('jobs.detail.eyebrow', {
                        'id': '${job.id}',
                      }).toUpperCase(),
                      style: XpertTypography.eyebrow.copyWith(
                        color: XpertColors.muted,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      headline.title,
                      style: XpertTypography.display.copyWith(
                        fontSize: 24,
                        letterSpacing: -0.4,
                        color: headline.titleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (headline.subtitle != null) ...[
            const SizedBox(height: XpertSpacing.sm),
            Text(
              headline.subtitle!,
              style: XpertTypography.body.copyWith(
                fontSize: 14,
                height: 1.4,
                color: XpertColors.muted,
              ),
            ),
          ],
          if (job.isInProgress) ...[
            const SizedBox(height: XpertSpacing.lg),
            LiveJobTimerCard(job: job),
          ] else if (!job.isNoShow) ...[
            const SizedBox(height: XpertSpacing.xl),
            JobProgressRail(current: job.isCompleted ? 4 : 1),
          ],
        ],
      ),
    );
  }
}

class _Headline {
  const _Headline({
    required this.icon,
    required this.accent,
    required this.title,
    this.subtitle,
    this.titleColor = XpertColors.onSurface,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;
  final Color titleColor;
}

_Headline _headline(WidgetRef ref, PartnerJob job, DateTime now) {
  final start = job.scheduledStartAt.toLocal();

  if (job.isInProgress) {
    return _Headline(
      icon: Icons.timelapse_rounded,
      accent: XpertColors.heroAccent,
      title: ref.t('jobs.detail.headline.working'),
    );
  }
  if (job.isCompleted) {
    return _Headline(
      icon: Icons.check_rounded,
      accent: XpertColors.success,
      title: ref.t('jobs.detail.headline.completed'),
      subtitle: jobDayAndTime(ref, start, now),
    );
  }
  if (job.isNoShow) {
    return _Headline(
      icon: Icons.person_off_outlined,
      accent: XpertColors.danger,
      title: ref.t('jobs.detail.headline.no_show'),
      subtitle: jobDayAndTime(ref, start, now),
    );
  }

  final until = start.difference(now);
  if (until.inMinutes < 0) {
    return _Headline(
      icon: Icons.schedule_rounded,
      accent: XpertColors.warning,
      title: ref.t('jobs.detail.headline.late'),
      titleColor: XpertColors.warning,
      subtitle: ref.t('jobs.detail.headline.late_sub', {
        'when': _isSameDay(start, now)
            ? DateFormat('h:mm a').format(start)
            : jobDayAndTime(ref, start, now),
      }),
    );
  }
  return _Headline(
    icon: Icons.event_rounded,
    accent: XpertColors.heroAccent,
    title: jobDayAndTime(ref, start, now),
    subtitle: until.inMinutes < 1
        ? ref.t('jobs.detail.headline.starting_now')
        : ref.t('jobs.detail.headline.starts_in', {
            'duration': formatJobDurationShort(until),
          }),
  );
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// `Today, 3:30 PM` · `Tomorrow, 9:00 AM` · `Fri, 19 Sep, 9:00 AM`.
String jobDayAndTime(WidgetRef ref, DateTime at, DateTime now) {
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = day.difference(today).inDays;
  final label = switch (days) {
    0 => ref.t('jobs.day.today'),
    1 => ref.t('jobs.day.tomorrow'),
    -1 => ref.t('jobs.day.yesterday'),
    _ => DateFormat('EEE, d MMM').format(at),
  };
  return '$label, ${DateFormat('h:mm a').format(at)}';
}

class _StageMark extends StatelessWidget {
  const _StageMark({required this.job, required this.headline});

  final PartnerJob job;
  final _Headline headline;

  @override
  Widget build(BuildContext context) {
    // The same tick the customer saw when they booked, played once.
    if (job.isCompleted) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Lottie.asset(
          'assets/lottie/Confirmed_tick.json',
          repeat: false,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _circle(),
        ),
      );
    }
    return _circle();
  }

  Widget _circle() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: headline.accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(headline.icon, size: 24, color: headline.accent),
    );
  }
}

/// Assigned → On the way → Working → Done: the same four stops the customer's
/// screen shows, so both ends of a job describe it in the same words.
class JobProgressRail extends ConsumerWidget {
  const JobProgressRail({super.key, required this.current});

  /// The step in progress; everything before it is done. Past the last step,
  /// every step is done.
  final int current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = [
      ref.t('jobs.detail.rail.assigned'),
      ref.t('jobs.detail.rail.on_the_way'),
      ref.t('jobs.detail.rail.working'),
      ref.t('jobs.detail.rail.done'),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: _RailStep(
              label: labels[i],
              done: i < current,
              active: i == current,
              first: i == 0,
              last: i == labels.length - 1,
            ),
          ),
      ],
    );
  }
}

class _RailStep extends StatelessWidget {
  const _RailStep({
    required this.label,
    required this.done,
    required this.active,
    required this.first,
    required this.last,
  });

  final String label;
  final bool done;
  final bool active;
  final bool first;
  final bool last;

  static const _reached = XpertColors.heroAccent;

  @override
  Widget build(BuildContext context) {
    final ahead = XpertColors.border.withValues(alpha: 0.7);
    final marked = done || active;

    return Column(
      children: [
        SizedBox(
          height: 18,
          child: Row(
            children: [
              Expanded(
                child: first
                    ? const SizedBox.shrink()
                    : Container(height: 2, color: marked ? _reached : ahead),
              ),
              _node(ahead),
              Expanded(
                child: last
                    ? const SizedBox.shrink()
                    : Container(height: 2, color: done ? _reached : ahead),
              ),
            ],
          ),
        ),
        const SizedBox(height: XpertSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: XpertTypography.caption.copyWith(
            fontSize: 10.5,
            height: 1.2,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: marked ? XpertColors.onSurface : XpertColors.muted,
          ),
        ),
      ],
    );
  }

  Widget _node(Color ahead) {
    // A ring for the step you are on, a filled check for the ones behind you.
    if (active) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: XpertColors.surface,
          border: Border.all(color: _reached, width: 3),
        ),
      );
    }
    if (done) {
      return Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _reached,
        ),
        child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
      );
    }
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(shape: BoxShape.circle, color: ahead),
    );
  }
}
