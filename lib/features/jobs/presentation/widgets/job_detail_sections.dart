import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/shell/xpert_sections.dart';
import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../data/jobs_api.dart';
import 'job_service_icon.dart';

const _rule = Color(0xFFE8EDF1);

/// A labelled block of the job sheet. Blocks are separated by hairlines, not
/// boxed — a stack of bordered cards made every fact look equally urgent.
class JobSection extends StatelessWidget {
  const JobSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(title),
        const SizedBox(height: XpertSpacing.sm),
        child,
      ],
    );
  }
}

class JobDivider extends StatelessWidget {
  const JobDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: XpertSpacing.lg),
      child: Divider(height: 1, thickness: 1, color: _rule),
    );
  }
}

/// What the job is and what it pays, in one line.
///
/// Duration and earning were two tiles of their own under the header, each as
/// big as the address. They belong beside the service they describe.
class JobSummaryRow extends ConsumerWidget {
  const JobSummaryRow({super.key, required this.job});

  final PartnerJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earning = job.partnerEarning ?? 0;
    final hours = job.durationMinutes / 60;
    final hoursLabel = ref.t('jobs.hours', {
      'hours': hours % 1 == 0
          ? hours.toStringAsFixed(0)
          : hours.toStringAsFixed(1),
    });
    final category = (job.serviceCategoryName ?? '').trim();
    // Only the estimate for a job still to be done. A finished job leads with
    // what it earned in a card of its own, and a no-show earned nothing — the
    // figure the server sends for one is the booked estimate, which would
    // promise money that is not coming.
    final showEarning = earning > 0 && (job.isAssigned || job.isInProgress);

    return Row(
      children: [
        JobServiceIcon(job: job, size: 48),
        const SizedBox(width: XpertSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.serviceName ?? ref.t('jobs.service_fallback'),
                style: XpertTypography.label.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                [hoursLabel, if (category.isNotEmpty) category].join(' · '),
                style: XpertTypography.caption.copyWith(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (showEarning) ...[
          const SizedBox(width: XpertSpacing.sm),
          // Capped so a translated label wraps under the amount instead of
          // squeezing the service name down to two truncated words.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${earning.toStringAsFixed(0)}',
                  style: XpertTypography.metric.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 3),
                Text(
                  ref.t('jobs.earning.estimated_label'),
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  style: XpertTypography.caption.copyWith(
                    fontSize: 11.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The customer, and a way to reach them. The number itself is deliberately
/// absent: calls are bridged through the Turanta line, so a partner never sees
/// (or keeps) a customer's personal number.
class JobCustomerRow extends ConsumerWidget {
  const JobCustomerRow({
    super.key,
    required this.name,
    required this.onCall,
    required this.calling,
  });

  final String name;

  /// Null once there is nothing left to call about.
  final VoidCallback? onCall;
  final bool calling;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: XpertColors.heroCard,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: XpertColors.heroAccent,
            ),
          ),
        ),
        const SizedBox(width: XpertSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: XpertTypography.label.copyWith(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (onCall != null) ...[
                const SizedBox(height: 2),
                Text(
                  ref.t('jobs.customer.number_private'),
                  style: XpertTypography.caption.copyWith(fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
        if (onCall != null) ...[
          const SizedBox(width: XpertSpacing.sm),
          _CallButton(onCall: onCall!, calling: calling),
        ],
      ],
    );
  }
}

class _CallButton extends ConsumerWidget {
  const _CallButton({required this.onCall, required this.calling});

  final VoidCallback onCall;
  final bool calling;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: ref.t('jobs.call'),
      child: Material(
        color: XpertColors.success,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: calling ? null : onCall,
          child: SizedBox(
            width: 46,
            height: 46,
            child: calling
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Icon(Icons.call_rounded, size: 21, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class JobAddressBlock extends ConsumerWidget {
  const JobAddressBlock({
    super.key,
    required this.address,
    required this.onNavigate,
  });

  final String address;

  /// Null when the job has no coordinates to navigate to.
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(XpertRadius.pill),
    );
    const textStyle = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.location_on_rounded,
                size: 20,
                color: XpertColors.heroAccent,
              ),
            ),
            const SizedBox(width: XpertSpacing.sm),
            Expanded(
              child: Text(
                address,
                style: XpertTypography.body.copyWith(
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: XpertSpacing.md),
        Row(
          children: [
            // Copyable, because half the time the destination gets pasted
            // into whichever maps app the partner actually uses.
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: address));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ref.t('jobs.address.copied'))),
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: shape,
                  side: BorderSide(
                    color: XpertColors.border.withValues(alpha: 0.7),
                  ),
                  textStyle: textStyle,
                ),
                icon: const Icon(Icons.copy_rounded, size: 17),
                // Neither label ellipsises on its own, and both grow in Hindi
                // and Marathi.
                label: Text(
                  ref.t('jobs.address.copy'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (onNavigate != null) ...[
              const SizedBox(width: XpertSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onNavigate,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: XpertColors.heroAccent,
                    foregroundColor: Colors.white,
                    shape: shape,
                    textStyle: textStyle,
                  ),
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: Text(
                    ref.t('jobs.navigate'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// A finished job answers "what did I make?" first.
class JobEarnedCard extends ConsumerWidget {
  const JobEarnedCard({super.key, required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: XpertSpacing.md,
        vertical: XpertSpacing.md,
      ),
      decoration: BoxDecoration(
        color: XpertColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(XpertRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${amount.toStringAsFixed(0)}',
                  style: XpertTypography.metric.copyWith(
                    fontSize: 30,
                    color: XpertColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ref.t('jobs.detail.earned'),
                  style: XpertTypography.caption.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          Image.asset(
            'assets/images/earning_on_the_way.png',
            height: 64,
            cacheHeight: 192,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class JobRatingBlock extends StatelessWidget {
  const JobRatingBlock({super.key, required this.job});

  final PartnerJob job;

  @override
  Widget build(BuildContext context) {
    final stars = job.reviewStars ?? 0;
    final note = (job.reviewNote ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 24,
                  color: i <= stars
                      ? const Color(0xFFF2A81D)
                      : XpertColors.border,
                ),
              ),
          ],
        ),
        if (job.reviewTags.isNotEmpty) ...[
          const SizedBox(height: XpertSpacing.sm),
          Wrap(
            spacing: XpertSpacing.xs,
            runSpacing: XpertSpacing.xs,
            children: [
              for (final tag in job.reviewTags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: XpertColors.secondary,
                    borderRadius: BorderRadius.circular(XpertRadius.pill),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: XpertColors.onSurface,
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (note.isNotEmpty) ...[
          const SizedBox(height: XpertSpacing.sm),
          Text(
            '“$note”',
            style: XpertTypography.body.copyWith(fontSize: 14.5, height: 1.45),
          ),
        ],
      ],
    );
  }
}
