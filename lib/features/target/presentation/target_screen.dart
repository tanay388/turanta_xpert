import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../app/shell/xpert_screen_scaffold.dart';
import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../../core/utils/rupees.dart';
import '../data/performance_api.dart';
import 'widgets/metric_tile.dart';
import 'widgets/rate_ladder.dart';

/// Target — rating, the rate it buys, and the four metrics behind it.
///
/// The rate per hour leads rather than the rating, because the rate is the
/// outcome and the rating is the input. The screen used to set them side by
/// side either side of a divider, two values of equal size, neither leading.
class TargetScreen extends ConsumerWidget {
  const TargetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perf = ref.watch(performanceProvider);
    final data = perf.valueOrNull;

    return XpertScreenScaffold(
      title: ref.t('nav.target'),
      header: data == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: XpertSpacing.lg),
              child: _RateHero(perf: data),
            ),
      child: perf.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: Icons.signal_cellular_alt_rounded,
              title: ref.t('target.error.title'),
              body: ref.t('target.error'),
            ),
          ],
        ),
        data: (p) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(performanceProvider);
            await ref.read(performanceProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              XpertSpacing.lg,
              XpertSpacing.lg,
              XpertSpacing.lg,
              XpertSpacing.xxl,
            ),
            children: [
              SectionLabel(ref.t('target.ladder.title')),
              const SizedBox(height: XpertSpacing.sm),
              RateLadder(
                ladder: p.ladder,
                rating: p.rating,
                nextBand: p.nextBand,
              ),
              const SizedBox(height: XpertSpacing.xl),
              SectionLabel(ref.t('target.metrics.title')),
              const SizedBox(height: 3),
              // Which of these moves the money, and which are simply the job.
              Text(
                ref.t('target.metrics.hint'),
                style: XpertTypography.caption.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: XpertSpacing.sm),
              // Four independent readings of the same cycle — a grid reads
              // them at a glance, where a stack asks you to go down the list.
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // A fixed height, not an aspect ratio: the tile's content is
                // the same four lines on every device, so tying its height to
                // the screen width just clipped it on narrow phones.
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: XpertSpacing.sm,
                  crossAxisSpacing: XpertSpacing.sm,
                  mainAxisExtent: 124,
                ),
                children: [
                  MetricTile(
                    label: ref.t('target.metric.rating'),
                    metric: p.ratingMetric,
                    decimals: 1,
                  ),
                  MetricTile(
                    label: ref.t('target.metric.unavailable'),
                    metric: p.unavailableMetric,
                    lowerIsBetter: true,
                  ),
                  MetricTile(
                    label: ref.t('target.metric.cancellations'),
                    metric: p.cancellationsMetric,
                    lowerIsBetter: true,
                  ),
                  MetricTile(
                    label: ref.t('target.metric.late_show'),
                    metric: p.lateShowMetric,
                    lowerIsBetter: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What an hour earns right now, the rating that bought it, and the one step
/// to the next rate.
class _RateHero extends ConsumerWidget {
  const _RateHero({required this.perf});

  final PartnerPerformance perf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = perf.currentRatePerHour;
    final next = perf.nextBand;
    final rating = perf.rating;
    final gap = (next != null && rating != null)
        ? (next.minRating - rating).clamp(0.0, 5.0)
        : null;
    final band = perf.currentBandLabel ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0B1720),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ref.t('target.rate_band.current').toUpperCase(),
                  style: XpertTypography.eyebrow.copyWith(
                    color: XpertColors.muted,
                    letterSpacing: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (band.isNotEmpty) ...[
                const SizedBox(width: XpertSpacing.sm),
                _BandChip(label: band),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                rate != null && rate > 0 ? rupees(rate) : '—',
                style: XpertTypography.metric.copyWith(fontSize: 34),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  ref.t('paisa.per_hour'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: XpertColors.muted,
                  ),
                ),
              ),
            ],
          ),
          // On its own line, not beside the rate: the rating and its count
          // together are wider than half a 320pt screen once translated.
          if (rating != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: Color(0xFFF2A81D),
                ),
                const SizedBox(width: 3),
                Text(
                  rating.toStringAsFixed(1),
                  style: XpertTypography.metric.copyWith(fontSize: 20),
                ),
                if (perf.ratingCount > 0) ...[
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      ref.t('target.rating_from', {
                        'count': '${perf.ratingCount}',
                      }),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: XpertColors.muted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          // The one line on the screen that says what to do next, rather than
          // how things stand.
          if (next != null && gap != null && gap > 0) ...[
            const SizedBox(height: XpertSpacing.md),
            _Note(
              icon: Icons.trending_up_rounded,
              color: XpertColors.heroAccent,
              text: ref.t('target.next_step', {
                'gap': gap.toStringAsFixed(1),
                'rate': next.ratePerHour.toStringAsFixed(0),
              }),
            ),
          ] else if (next == null && rate != null && rate > 0) ...[
            const SizedBox(height: XpertSpacing.md),
            _Note(
              icon: Icons.workspace_premium_rounded,
              color: XpertColors.success,
              text: ref.t('target.top_band'),
            ),
          ],
        ],
      ),
    );
  }
}

class _BandChip extends StatelessWidget {
  const _BandChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: XpertColors.heroCard,
        borderRadius: BorderRadius.circular(XpertRadius.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: XpertColors.heroAccent,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: XpertSpacing.sm,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(XpertRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
