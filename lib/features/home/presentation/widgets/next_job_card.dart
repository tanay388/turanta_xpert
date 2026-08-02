import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../../jobs/data/jobs_api.dart';
import '../../../jobs/presentation/live_job_timer.dart';

class NextJobCard extends ConsumerWidget {
  const NextJobCard({
    super.key,
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
