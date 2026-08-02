import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../../../core/utils/job_timer.dart';
import '../../data/jobs_api.dart';
import '../live_job_timer.dart';
import 'job_service_icon.dart';

/// The three job cards.
///
/// They used to be one layout wearing three different pills: same icon square,
/// same title, same caption line, with only a small coloured chip on the right
/// saying which was which. So the live job — the one thing a partner has to act
/// on — looked exactly like a job booked for next Tuesday.
///
/// Each state now gets the treatment it earns: the running one is loud and
/// carries its clock, the upcoming one leads with the time it starts, and a
/// finished one is a receipt that leads with what it paid.

/// Running now. The only card in the app with a coloured field.
class OngoingJobCard extends ConsumerWidget {
  const OngoingJobCard({super.key, required this.job, required this.onTap});

  final PartnerJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final duration = Duration(minutes: job.durationMinutes);
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
    final overtime = jobIsOvertime(end, now);
    final accent = overtime ? XpertColors.danger : XpertColors.primary;

    return _CardShell(
      onTap: onTap,
      color: accent.withValues(alpha: 0.06),
      borderColor: accent.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              JobServiceIcon(job: job),
              const SizedBox(width: XpertSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      job.serviceName ?? ref.t('jobs.service_fallback'),
                      style: XpertTypography.label.copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (job.customerName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        job.customerName!,
                        style: XpertTypography.caption.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: XpertSpacing.md),
          // The full timer, not the one-line version this card used to show.
          // A running job is the most urgent thing on the screen and it was
          // rendering its clock in 13pt caption text.
          LiveJobTimerCard(job: job),
          if (job.displayAddress.isNotEmpty) ...[
            const SizedBox(height: XpertSpacing.md),
            _AddressLine(address: job.displayAddress),
          ],
        ],
      ),
    );
  }
}

/// Booked, not started. Leads with when — that is what a partner scans for.
class UpcomingJobCard extends ConsumerWidget {
  const UpcomingJobCard({super.key, required this.job, required this.onTap});

  final PartnerJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = job.scheduledStartAt.toLocal();
    final isToday = DateUtils.isSameDay(start, DateTime.now());

    return _CardShell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The time is the value here, so it is set as one: tabular, heavy,
          // with the meridiem and day reduced to labels beneath it.
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('h:mm').format(start),
                  style: XpertTypography.metric.copyWith(fontSize: 19),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('a').format(start).toUpperCase(),
                  style: XpertTypography.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!isToday) ...[
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('EEE, d MMM').format(start),
                    style: XpertTypography.caption.copyWith(fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: XpertSpacing.md),
          Container(width: 1, height: 44, color: const Color(0xFFE8EDF1)),
          const SizedBox(width: XpertSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  job.serviceName ?? ref.t('jobs.service_fallback'),
                  style: XpertTypography.label.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  ref.t('jobs.hours', {'hours': _hours(job.durationMinutes)}),
                  style: XpertTypography.caption.copyWith(fontSize: 12),
                ),
                if (job.displayAddress.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _AddressLine(address: job.displayAddress),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: XpertColors.border,
          ),
        ],
      ),
    );
  }
}

/// Done. A receipt — it leads with what the job paid.
class CompletedJobCard extends ConsumerWidget {
  const CompletedJobCard({super.key, required this.job, required this.onTap});

  final PartnerJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noShow = job.isNoShow;
    final earning = job.partnerEarning;

    return _CardShell(
      onTap: onTap,
      child: Row(
        children: [
          Opacity(
            // A no-show earned nothing and is not worth looking at twice.
            opacity: noShow ? 0.45 : 1,
            child: JobServiceIcon(job: job, size: 44),
          ),
          const SizedBox(width: XpertSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  job.serviceName ?? ref.t('jobs.service_fallback'),
                  style: XpertTypography.label.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      DateFormat('h:mm a').format(job.scheduledStartAt.toLocal()),
                      style: XpertTypography.caption.copyWith(fontSize: 12),
                    ),
                    if (noShow) ...[
                      const SizedBox(width: 6),
                      _Chip(
                        label: ref.t('jobs.status.no_show'),
                        color: XpertColors.danger,
                      ),
                    ] else if (job.hasReview) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${job.reviewStars}',
                        style: XpertTypography.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: XpertSpacing.sm),
          Text(
            (earning == null || earning <= 0)
                ? '—'
                : '₹${earning.toStringAsFixed(0)}',
            style: XpertTypography.metric.copyWith(
              fontSize: 17,
              color: noShow ? XpertColors.muted : XpertColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// One card body, so the three variants cannot drift apart on padding, radius,
/// or how they respond to a tap.
class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.child,
    required this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(XpertRadius.lg);

    return Material(
      color: color ?? XpertColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(XpertSpacing.md),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color:
                  borderColor ?? XpertColors.border.withValues(alpha: 0.45),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 14,
          color: XpertColors.muted,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            address.replaceAll('\n', ', '),
            style: XpertTypography.caption.copyWith(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(XpertRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

String _hours(int minutes) {
  final hours = minutes / 60;
  return hours % 1 == 0 ? hours.toStringAsFixed(0) : hours.toStringAsFixed(1);
}
