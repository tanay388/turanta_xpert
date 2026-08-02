import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';

/// Leave balance, as a quantity you can see rather than four caption lines.
///
/// It used to be a 56pt number followed by "Paid leave you can use", "This
/// month: 10 · Waiting: 2", "Lapsed (unused): 1" and sometimes an orange
/// sentence about unpaid leave — five statements about one number, stacked, in
/// the same size. The bar carries the same facts in the shape they actually
/// have: a month's worth of days, some spent, some held, some left.
class LeaveBalance extends ConsumerWidget {
  const LeaveBalance({
    super.key,
    required this.available,
    required this.total,
    required this.pending,
    required this.lapsed,
    required this.canApplyUnpaid,
  });

  final int available;
  final int total;
  final int pending;
  final int lapsed;
  final bool canApplyUnpaid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final used = (total - available - pending).clamp(0, total);

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
          Text(ref.t('leave.balance.eyebrow'), style: XpertTypography.eyebrow),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$available',
                style: XpertTypography.metric.copyWith(
                  fontSize: 38,
                  color: XpertColors.onCanvas,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                ref.t('leave.balance.days'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: XpertColors.onCanvasMuted,
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: XpertSpacing.md),
            _Meter(available: available, pending: pending, used: used),
            const SizedBox(height: XpertSpacing.sm),
            Wrap(
              spacing: XpertSpacing.md,
              runSpacing: 4,
              children: [
                if (used > 0)
                  _Legend(
                    color: XpertColors.onCanvasMuted,
                    label: ref.t('leave.balance.used', {'count': '$used'}),
                  ),
                if (pending > 0)
                  _Legend(
                    color: const Color(0xFFF9A825),
                    label: ref.t('leave.balance.waiting', {'count': '$pending'}),
                  ),
                if (lapsed > 0)
                  _Legend(
                    color: XpertColors.onCanvasMuted,
                    label: ref.t('leave.balance.lapsed', {'count': '$lapsed'}),
                  ),
              ],
            ),
          ],
          if (canApplyUnpaid) ...[
            const SizedBox(height: XpertSpacing.sm),
            Text(
              ref.t('leave.unpaid_available_hint'),
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFB74D),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({
    required this.available,
    required this.pending,
    required this.used,
  });

  final int available;
  final int pending;
  final int used;

  @override
  Widget build(BuildContext context) {
    // `stretch` is load-bearing: a childless ColoredBox takes
    // `constraints.smallest`, and a Row's cross axis is loose, so with the
    // default alignment every segment resolved to zero height and the bar
    // rendered as nothing at all.
    return ClipRRect(
      borderRadius: BorderRadius.circular(XpertRadius.pill),
      child: SizedBox(
        height: 8,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (available > 0)
              Expanded(
                flex: available,
                child: const ColoredBox(color: XpertColors.primary),
              ),
            if (pending > 0)
              Expanded(
                flex: pending,
                child: const ColoredBox(color: Color(0xFFF9A825)),
              ),
            if (used > 0)
              Expanded(
                flex: used,
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: XpertColors.onCanvasMuted,
          ),
        ),
      ],
    );
  }
}
