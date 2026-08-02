import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../app/shell/xpert_screen_scaffold.dart';
import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
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
              const SizedBox(height: XpertSpacing.sm),
              // Four independent readings of the same cycle — a grid reads
              // them at a glance, where a stack asks you to go down the list.
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // A fixed height, not an aspect ratio: the tile's content is
                // the same four lines on every device, so tying its height to
                // the screen width just clipped it on narrow phones.
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
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

/// What an hour earns right now, with the rating that bought it underneath —
/// and, when there is one, the exact step to the next rate.
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.canvasSoft,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ref.t('target.rate_band.current').toUpperCase(),
            style: XpertTypography.eyebrow,
          ),
          const SizedBox(height: 6),
          // Wrap, not Row: two flex children split the width evenly, and on a
          // 320pt screen half of it is narrower than the rate itself. Letting
          // the rating drop to a second line beats squeezing both.
          Wrap(
            spacing: XpertSpacing.md,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rate != null && rate > 0
                        ? '₹${rate.toStringAsFixed(0)}'
                        : '—',
                    style: XpertTypography.metric.copyWith(
                      fontSize: 34,
                      color: XpertColors.onCanvas,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Flexible inside the wrapped row too: the rating can move
                  // to its own line, but this label still has to fit beside
                  // the number on the line it shares.
                  Flexible(
                    child: Text(
                      ref.t('paisa.per_hour'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: XpertColors.onCanvasMuted,
                      ),
                    ),
                  ),
                ],
              ),
              if (rating != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: Color(0xFFF5A623),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      rating.toStringAsFixed(1),
                      style: XpertTypography.metric.copyWith(
                        fontSize: 20,
                        color: XpertColors.onCanvas,
                      ),
                    ),
                    if (perf.ratingCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${perf.ratingCount})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: XpertColors.onCanvasMuted,
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          // The one line on the screen that says what to do next, rather than
          // how things stand.
          if (next != null && gap != null && gap > 0) ...[
            const SizedBox(height: XpertSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: XpertSpacing.sm,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: XpertColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(XpertRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    size: 15,
                    color: XpertColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ref.t('target.next_step', {
                        'gap': gap.toStringAsFixed(1),
                        'rate': next.ratePerHour.toStringAsFixed(0),
                      }),
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: XpertColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
