import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../data/performance_api.dart';

/// The rating → rate/hour ladder, drawn as a ladder.
///
/// This is the whole incentive the screen exists to communicate, and it was a
/// flat list of radio buttons: you could read which band you were in, but not
/// that there was anything above it or how close you were. It now climbs, the
/// rungs above the current one are visibly ahead of you, and the next one says
/// exactly what it costs and what it pays.
class RateLadder extends ConsumerWidget {
  const RateLadder({
    super.key,
    required this.ladder,
    required this.rating,
    this.nextBand,
  });

  final List<RateLadderBand> ladder;
  final double? rating;
  final RateLadderBand? nextBand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ladder.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(XpertSpacing.lg),
        decoration: BoxDecoration(
          color: XpertColors.surface,
          borderRadius: BorderRadius.circular(XpertRadius.lg),
          border: Border.all(color: XpertColors.border.withValues(alpha: 0.45)),
        ),
        child: Text(
          ref.t('target.ladder.empty'),
          textAlign: TextAlign.center,
          style: XpertTypography.caption,
        ),
      );
    }

    // Highest-paying band at the top, so climbing reads as going up.
    final rungs = [...ladder]
      ..sort((a, b) => b.ratePerHour.compareTo(a.ratePerHour));

    return Container(
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rungs.length; i++)
            _Rung(
              band: rungs[i],
              isNext: identical(rungs[i], nextBand),
              isFirst: i == 0,
              isLast: i == rungs.length - 1,
              rating: rating,
            ),
        ],
      ),
    );
  }
}

class _Rung extends ConsumerWidget {
  const _Rung({
    required this.band,
    required this.isNext,
    required this.isFirst,
    required this.isLast,
    required this.rating,
  });

  final RateLadderBand band;
  final bool isNext;
  final bool isFirst;
  final bool isLast;
  final double? rating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = band.current;
    final accent = current
        ? XpertColors.primary
        : isNext
        ? XpertColors.primary
        : XpertColors.border;

    // How much more rating this rung costs. Only worth saying for the one you
    // are actually reaching for.
    final gap = (rating != null && isNext)
        ? (band.minRating - rating!).clamp(0.0, 5.0)
        : null;

    return Container(
      color: current
          ? XpertColors.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(
        horizontal: XpertSpacing.md,
        vertical: XpertSpacing.sm + 2,
      ),
      // IntrinsicHeight, because the rail's connector uses Expanded and so
      // needs a bounded height. `stretch` alone cannot supply one here: the
      // ladder sits in a ListView, so the incoming cross-axis constraint is
      // infinite and gets handed straight down.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The rail: a continuous line with a node per rung, so the rungs
            // read as one ladder rather than as separate rows.
            SizedBox(
              width: 18,
              child: Column(
                children: [
                  Container(
                    width: 2,
                    height: 8,
                    color: isFirst
                        ? Colors.transparent
                        : XpertColors.border.withValues(alpha: 0.5),
                  ),
                  Container(
                    width: current ? 14 : 10,
                    height: current ? 14 : 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: current ? accent : XpertColors.surface,
                      border: Border.all(color: accent, width: 2),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isLast
                          ? Colors.transparent
                          : XpertColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: XpertSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          band.label,
                          style: XpertTypography.label.copyWith(
                            fontSize: 14,
                            fontWeight: current
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: XpertSpacing.sm),
                      Text(
                        '₹${band.ratePerHour.toStringAsFixed(0)}',
                        style: XpertTypography.metric.copyWith(
                          fontSize: 16,
                          color: current
                              ? XpertColors.primary
                              : XpertColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${band.minRating.toStringAsFixed(1)}–'
                          '${band.maxRating.toStringAsFixed(1)} ★',
                          style: XpertTypography.caption.copyWith(
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      if (current)
                        Flexible(
                          child: _Tag(
                            label: ref.t('target.rate_band.you'),
                            color: XpertColors.primary,
                            filled: true,
                          ),
                        )
                      else if (isNext)
                        Flexible(
                          child: _Tag(
                            label: gap == null || gap <= 0
                                ? ref.t('target.rate_band.next')
                                : ref.t('target.ladder.gap', {
                                    'gap': gap.toStringAsFixed(1),
                                  }),
                            color: XpertColors.primary,
                            filled: false,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color, required this.filled});

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(XpertRadius.pill),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
