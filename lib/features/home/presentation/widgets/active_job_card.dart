import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../../jobs/data/jobs_api.dart';
import '../../../jobs/presentation/live_job_timer.dart';

/// The running job, as the screen's hero.
///
/// While a job is in progress it outranks the shift: the partner's next action
/// is finishing it, not managing attendance. So it takes the top slot and the
/// full timer, and the shift card drops below it stripped of check-out and
/// break — both of which the server refuses anyway while a job is open.
class ActiveJobCard extends ConsumerWidget {
  const ActiveJobCard({super.key, required this.job});

  final PartnerJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = job.displayAddress.trim();
    final customer = (job.customerName ?? '').trim();

    return Material(
      color: XpertColors.surface,
      borderRadius: BorderRadius.circular(XpertRadius.lg),
      child: InkWell(
        onTap: () => context.push('/jobs/${job.id}'),
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(XpertSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(XpertRadius.lg),
            border: Border.all(
              color: XpertColors.primary.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.serviceName ?? ref.t('jobs.service_fallback'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: XpertTypography.label.copyWith(fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: XpertSpacing.sm),
                  const _LiveBadge(),
                ],
              ),
              const SizedBox(height: XpertSpacing.md),
              // The full timer, not the compact one: remaining, elapsed, and
              // how far through the booked window this is.
              LiveJobTimerCard(job: job),
              if (customer.isNotEmpty) ...[
                const SizedBox(height: XpertSpacing.md),
                _DetailRow(icon: Icons.person_outline, text: customer),
              ],
              if (address.isNotEmpty) ...[
                const SizedBox(height: 6),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  text: address.replaceAll('\n', ' · '),
                  maxLines: 3,
                ),
              ],
              const SizedBox(height: XpertSpacing.lg),
              FilledButton(
                onPressed: () => context.push('/jobs/${job.id}'),
                child: Text(ref.t('jobs.home.open')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveBadge extends ConsumerWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: XpertColors.primary,
        borderRadius: BorderRadius.circular(XpertRadius.pill),
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
          const SizedBox(width: 6),
          Text(
            ref.t('jobs.live.badge'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.text,
    this.maxLines = 1,
  });

  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: XpertColors.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: XpertTypography.caption,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
