import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../data/earning_models.dart';

/// This fortnight's money, on the canvas.
///
/// It used to sit inside a white card in the middle of the list, at the same
/// weight as everything else, with a chevron tucked beside the status chip so
/// the one tappable thing on the screen read as decoration.
///
/// A cycle is a window, so it is drawn as one: how far through the fortnight
/// you are, which is the honest answer to "why is this number smaller than
/// last time" on day three.
class CycleHero extends ConsumerWidget {
  const CycleHero({super.key, required this.summary, this.onTap});

  final EarningSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = summary.periodStart;
    final end = summary.periodEnd;
    final progress = _cycleProgress(start, end);

    return Semantics(
      button: onTap != null,
      child: Material(
        color: XpertColors.canvasSoft,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(XpertSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(XpertRadius.lg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ref.t('paisa.current_cycle').toUpperCase(),
                        style: XpertTypography.eyebrow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _CanvasStatus(status: summary.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${summary.totalAmount.toStringAsFixed(0)}',
                  style: XpertTypography.metric.copyWith(
                    fontSize: 38,
                    color: XpertColors.onCanvas,
                  ),
                ),
                if (start != null && end != null) ...[
                  const SizedBox(height: XpertSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(XpertRadius.pill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        XpertColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${DateFormat('d MMM').format(start)} – '
                          '${DateFormat('d MMM').format(end)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: XpertColors.onCanvasMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onTap != null)
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: XpertColors.onCanvasMuted,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 0 at the start of the fortnight, 1 at its end. Null dates mean no window to
/// draw, and a same-day window would divide by zero.
double _cycleProgress(DateTime? start, DateTime? end) {
  if (start == null || end == null) return 0;
  final total = end.difference(start).inSeconds;
  if (total <= 0) return 1;
  final done = DateTime.now().difference(start).inSeconds;
  return (done / total).clamp(0.0, 1.0);
}

class _CanvasStatus extends ConsumerWidget {
  const _CanvasStatus({required this.status});

  final PayoutStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, key) = switch (status) {
      PayoutStatus.accruing => (XpertColors.primary, 'paisa.status.accruing'),
      PayoutStatus.pending => (const Color(0xFFF5A623), 'paisa.status.pending'),
      PayoutStatus.paid => (const Color(0xFF4CAF50), 'paisa.status.paid'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(XpertRadius.pill),
      ),
      child: Text(
        ref.t(key),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
