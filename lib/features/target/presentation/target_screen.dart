import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/performance_api.dart';

/// Target (rating / performance) tab.
///
/// Shows the partner's rating, the rating → rate/hour ladder (their incentive
/// to keep rating high), and the four performance metrics vs their targets.
class TargetScreen extends ConsumerWidget {
  const TargetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perf = ref.watch(performanceProvider);

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(title: Text(ref.t('nav.target'))),
      body: perf.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _ErrorState(message: ref.t('target.error')),
        data: (p) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(performanceProvider);
            await ref.read(performanceProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(XpertSpacing.lg),
            children: [
              _RatingHeader(perf: p),
              const SizedBox(height: XpertSpacing.lg),
              Text(ref.t('target.ladder.title'), style: XpertTypography.label),
              const SizedBox(height: XpertSpacing.sm),
              _RateLadder(ladder: p.ladder, nextBand: p.nextBand),
              const SizedBox(height: XpertSpacing.lg),
              Text(ref.t('target.metrics.title'),
                  style: XpertTypography.label),
              const SizedBox(height: XpertSpacing.sm),
              _MetricsGrid(perf: p),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingHeader extends ConsumerWidget {
  const _RatingHeader({required this.perf});
  final PartnerPerformance perf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = perf.currentRatePerHour;
    return Container(
      padding: const EdgeInsets.all(XpertSpacing.lg),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ref.t('target.rating'), style: XpertTypography.caption),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFF5A623), size: 26),
                    const SizedBox(width: 4),
                    Text(
                      perf.rating != null
                          ? perf.rating!.toStringAsFixed(1)
                          : '—',
                      style: XpertTypography.title.copyWith(fontSize: 28),
                    ),
                    const SizedBox(width: 6),
                    if (perf.ratingCount > 0)
                      Text(
                        '(${perf.ratingCount})',
                        style: XpertTypography.caption,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(width: 1, height: 44, color: XpertColors.border),
          const SizedBox(width: XpertSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(ref.t('target.rate_band.current'),
                  style: XpertTypography.caption),
              const SizedBox(height: 2),
              Text(
                rate != null && rate > 0
                    ? ref.t('target.rate_per_hour',
                        {'rate': rate.toStringAsFixed(0)})
                    : '—',
                style: XpertTypography.title.copyWith(
                  fontSize: 22,
                  color: XpertColors.primary,
                ),
              ),
              if (perf.currentBandLabel != null)
                Text(
                  perf.currentBandLabel!,
                  style: XpertTypography.caption.copyWith(fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RateLadder extends ConsumerWidget {
  const _RateLadder({required this.ladder, this.nextBand});
  final List<RateLadderBand> ladder;
  final RateLadderBand? nextBand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ladder.isEmpty) {
      return _EmptyCard(message: ref.t('target.ladder.empty'));
    }
    return Container(
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.md),
      ),
      child: Column(
        children: [
          for (var i = 0; i < ladder.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: XpertColors.background),
            _LadderRow(
              band: ladder[i],
              isNext: identical(ladder[i], nextBand),
            ),
          ],
        ],
      ),
    );
  }
}

class _LadderRow extends ConsumerWidget {
  const _LadderRow({required this.band, this.isNext = false});
  final RateLadderBand band;
  final bool isNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlight = band.current;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: XpertSpacing.md,
        vertical: XpertSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? XpertColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(XpertRadius.md),
        border: isNext
            ? Border.all(color: XpertColors.primary.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        children: [
          Icon(
            highlight
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: highlight ? XpertColors.primary : XpertColors.muted,
          ),
          const SizedBox(width: XpertSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  band.label,
                  style: XpertTypography.label.copyWith(
                    fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                Text(
                  '${band.minRating.toStringAsFixed(1)}–${band.maxRating.toStringAsFixed(1)} ★',
                  style: XpertTypography.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            ref.t('target.rate_per_hour',
                {'rate': band.ratePerHour.toStringAsFixed(0)}),
            style: XpertTypography.label.copyWith(
              fontSize: 15,
              color: highlight ? XpertColors.primary : XpertColors.onSurface,
            ),
          ),
          if (highlight) ...[
            const SizedBox(width: XpertSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: XpertColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(XpertRadius.pill),
              ),
              child: Text(
                ref.t('target.rate_band.you'),
                style: XpertTypography.caption.copyWith(
                  color: XpertColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ] else if (isNext) ...[
            const SizedBox(width: XpertSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(XpertRadius.pill),
                border: Border.all(
                  color: XpertColors.primary.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                ref.t('target.rate_band.next'),
                style: XpertTypography.caption.copyWith(
                  color: XpertColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricsGrid extends ConsumerWidget {
  const _MetricsGrid({required this.perf});
  final PartnerPerformance perf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = [
      _MetricTile(
        label: ref.t('target.metric.rating'),
        metric: perf.ratingMetric,
        decimals: 1,
      ),
      _MetricTile(
        label: ref.t('target.metric.unavailable'),
        metric: perf.unavailableMetric,
        lowerIsBetter: true,
      ),
      _MetricTile(
        label: ref.t('target.metric.cancellations'),
        metric: perf.cancellationsMetric,
        lowerIsBetter: true,
      ),
      _MetricTile(
        label: ref.t('target.metric.late_show'),
        metric: perf.lateShowMetric,
        lowerIsBetter: true,
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: XpertSpacing.sm,
      crossAxisSpacing: XpertSpacing.sm,
      childAspectRatio: 1.55,
      children: tiles,
    );
  }
}

class _MetricTile extends ConsumerWidget {
  const _MetricTile({
    required this.label,
    required this.metric,
    this.decimals = 0,
    this.lowerIsBetter = false,
  });

  final String label;
  final PerformanceMetric metric;
  final int decimals;
  final bool lowerIsBetter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ok = metric.ok;
    final color = ok ? XpertColors.success : XpertColors.danger;
    final valueStr =
        metric.value != null ? metric.value!.toStringAsFixed(decimals) : '—';
    final targetStr = ref.t('target.metric.target', {
      'value':
          '${lowerIsBetter ? '≤ ' : '≥ '}${metric.threshold.toStringAsFixed(decimals)}',
    });

    return Container(
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: XpertTypography.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                valueStr,
                style: XpertTypography.title.copyWith(fontSize: 26),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  targetStr,
                  style: XpertTypography.caption.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(XpertRadius.pill),
                ),
                child: Text(
                  ok
                      ? ref.t('target.metric.ok')
                      : ref.t('target.metric.attention'),
                  style: XpertTypography.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(XpertSpacing.xl),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.md),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: XpertTypography.caption,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(XpertSpacing.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: XpertTypography.caption.copyWith(color: XpertColors.danger),
        ),
      ),
    );
  }
}
