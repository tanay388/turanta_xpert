import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(XpertRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LiveDotBadge(color: accent, label: ref.t('jobs.live.badge')),
              const Spacer(),
              Text(
                formatJobClock(overtime ? elapsed : remaining),
                style: XpertTypography.title.copyWith(
                  color: accent,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            overtime
                ? ref.t('jobs.live.overtime')
                : ref.t('jobs.live.remaining_label'),
            style: XpertTypography.caption.copyWith(color: XpertColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            ref.t('jobs.live.elapsed', {'time': formatJobClock(elapsed)}),
            style: XpertTypography.caption.copyWith(color: XpertColors.muted),
          ),
        ],
      ),
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
