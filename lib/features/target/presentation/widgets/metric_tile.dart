import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../data/performance_api.dart';

/// One performance metric against its target, sized for a 2×2 grid.
///
/// The grid is the right shape for these: four independent readings of the
/// same cycle, none more important than the others, all taken in at a glance
/// rather than read down in sequence.
///
/// What changed is inside the tile. Each used to end in a green or red
/// pass/fail pill, so red appeared on an ordinary screen as a matter of
/// routine — spending the one colour that should mean something. And pass/fail
/// answers the wrong question anyway: what a partner needs is distance. How
/// far from the line, and which side of it.
class MetricTile extends ConsumerWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.metric,
    this.decimals = 0,
    this.lowerIsBetter = false,
  });

  final String label;
  final PerformanceMetric metric;
  final int decimals;

  /// Cancellations and late shows are counts to keep down; rating is a score
  /// to keep up. The bar has to fill in the direction that means "good".
  final bool lowerIsBetter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = metric.value;
    final ok = metric.ok;

    // Off-target is the only state that earns a colour. On-target is simply
    // how things are supposed to be, so it stays quiet.
    final accent = ok ? XpertColors.primary : const Color(0xFFF57C00);

    return Container(
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The value leads, the label names it underneath — the old
                    // tiles put a caption on top and the number below it.
                    Text(
                      value == null ? '—' : value.toStringAsFixed(decimals),
                      style: XpertTypography.metric.copyWith(fontSize: 24),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: XpertTypography.caption.copyWith(fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // A mark, not a sentence: "Needs work" does not fit a half-width
              // tile once it has been translated.
              if (!ok)
                Icon(Icons.error_outline_rounded, size: 16, color: accent),
            ],
          ),
          const SizedBox(height: XpertSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(XpertRadius.pill),
            child: LinearProgressIndicator(
              value: _fill(value, metric.threshold, lowerIsBetter),
              minHeight: 6,
              backgroundColor: const Color(0xFFE8EDF1),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ok
                ? ref.t('target.metric.target', {
                    'value':
                        '${lowerIsBetter ? '≤ ' : '≥ '}'
                        '${metric.threshold.toStringAsFixed(decimals)}',
                  })
                : ref.t('target.metric.attention'),
            style: XpertTypography.caption.copyWith(
              fontSize: 11.5,
              color: ok ? XpertColors.muted : accent,
              fontWeight: ok ? null : FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// How full the bar is, always with "more filled" meaning "doing better".
///
/// For a metric you keep down, the bar shows headroom left before the limit —
/// so it empties as you use it up, rather than growing as things get worse.
double _fill(double? value, double threshold, bool lowerIsBetter) {
  if (value == null) return 0;
  if (threshold <= 0) return lowerIsBetter ? (value <= 0 ? 1 : 0) : 1;
  if (lowerIsBetter) {
    return (1 - (value / threshold)).clamp(0.0, 1.0);
  }
  return (value / threshold).clamp(0.0, 1.0);
}
