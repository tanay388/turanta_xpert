import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../../core/utils/job_timer.dart';
import '../data/jobs_api.dart';

/// Live badge + remaining / elapsed clocks for an in-progress partner job.
class LiveJobTimerCard extends ConsumerStatefulWidget {
  const LiveJobTimerCard({
    super.key,
    required this.job,
    this.compact = false,
  });

  final PartnerJob job;
  final bool compact;

  @override
  ConsumerState<LiveJobTimerCard> createState() => _LiveJobTimerCardState();
}

class _LiveJobTimerCardState extends ConsumerState<LiveJobTimerCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    if (!job.isInProgress) return const SizedBox.shrink();

    final now = DateTime.now();
    final duration = Duration(minutes: job.durationMinutes);
    // Early start supported: countdown from OTP start, not the booked slot.
    final started = jobLiveStart(
      startedAt: job.startedAt?.toLocal(),
      scheduledEnd: job.scheduledEndAt.toLocal(),
      duration: duration,
      now: now,
    );
    final end = jobLiveEnd(
      start: started,
      duration: duration,
      scheduledEnd: job.scheduledEndAt.toLocal(),
    );
    final remaining = jobTimeRemaining(end, now);
    final elapsed = jobTimeElapsed(started, now);
    final overtime = jobIsOvertime(end, now);
    final accent = overtime ? XpertColors.danger : XpertColors.primary;
    // The fill can be brand cyan; the clock printed on a tint of that same
    // cyan cannot — it lands at about 1.9:1.
    final inkAccent = overtime ? XpertColors.danger : XpertColors.primaryDeep;
    final progress = overtime
        ? 1.0
        : (duration.inSeconds > 0
            ? (elapsed.inSeconds / duration.inSeconds).clamp(0.0, 1.0)
            : 0.0);
    final timeFmt = DateFormat('h:mm a');

    if (widget.compact) {
      return Row(
        children: [
          _LiveDotBadge(color: accent, label: ref.t('jobs.live.badge')),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              overtime
                  ? ref.t('jobs.live.overtime')
                  : ref.t('jobs.live.remaining', {
                      'time': formatJobClock(remaining),
                    }),
              style: XpertTypography.caption.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    // The label used to sit at the far left of the same line as the clock, and
    // the two endpoint times in a row of their own further down — three
    // separate readings of one thing. They are one block now: the label over
    // its number, elapsed beside it as the counterweight, and the start and
    // end times pinned to the ends of the bar they belong to.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(XpertRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overtime
                          ? ref.t('jobs.live.overtime').toUpperCase()
                          : ref.t('jobs.live.remaining_label').toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: XpertTypography.eyebrow.copyWith(
                        color: XpertColors.muted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // A clock is unreadable truncated, so it scales down
                    // instead — at 30pt it does not fit a 320pt screen beside
                    // a translated label.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatJobClock(
                          overtime ? now.difference(end) : remaining,
                        ),
                        style: XpertTypography.display.copyWith(
                          fontSize: 32,
                          color: inkAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: XpertSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatJobDurationShort(elapsed),
                    style: XpertTypography.label.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    ref.t('jobs.live.elapsed'),
                    style: XpertTypography.caption.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: XpertSpacing.md),
          JobProgressBar(
            progress: progress,
            accent: accent,
            track: accent.withValues(alpha: 0.18),
            knobRing: XpertColors.surface,
          ),
          const SizedBox(height: XpertSpacing.xs),
          // Expanded, not Flexible: Flexible sizes to its content, so both
          // times bunched up on the left instead of marking the ends of the
          // bar they describe.
          Row(
            children: [
              Expanded(
                child: Text(
                  '${ref.t('jobs.live.started')} ${timeFmt.format(started)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: XpertTypography.caption.copyWith(
                    color: XpertColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const SizedBox(width: XpertSpacing.sm),
              Expanded(
                child: Text(
                  '${ref.t('jobs.live.ends')} ${timeFmt.format(end)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: XpertTypography.caption.copyWith(
                    color: XpertColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Track, fill, and a knob at "now".
///
/// A bare [LinearProgressIndicator] shows how much of the bar is coloured but
/// gives the eye nothing to land on, so the two times printed underneath read
/// as a separate fact rather than as the ends of this bar.
class JobProgressBar extends StatelessWidget {
  const JobProgressBar({
    super.key,
    required this.progress,
    required this.accent,
    required this.track,
    required this.knobRing,
  });

  final double progress;
  final Color accent;
  final Color track;

  /// Drawn as a ring around the knob so it reads as sitting on top of the bar
  /// rather than being part of the fill.
  final Color knobRing;

  static const _height = 8.0;
  static const _knob = 16.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final filled = (width * progress).clamp(0.0, width);

        return SizedBox(
          height: _knob,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: _height,
                decoration: BoxDecoration(
                  color: track,
                  borderRadius: BorderRadius.circular(XpertRadius.pill),
                ),
              ),
              Container(
                width: filled,
                height: _height,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(XpertRadius.pill),
                ),
              ),
              Positioned(
                left: (filled - _knob / 2).clamp(0.0, width - _knob),
                child: Container(
                  width: _knob,
                  height: _knob,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: knobRing, width: 3),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LiveDotBadge extends StatelessWidget {
  const _LiveDotBadge({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
