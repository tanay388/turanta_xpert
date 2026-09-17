import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';

/// The colours of a leave balance, used by the meter and its legend so a
/// segment and the words under it are never a different colour for the same
/// thing.
const leaveLeftColor = XpertColors.heroAccent;
const leaveWaitingColor = XpertColors.warning;
const leaveUsedColor = Color(0xFF94A3B8);
const _meterTrack = Color(0xFFE3EBF1);

/// Leave balance, as a quantity you can see rather than four caption lines.
///
/// The bar carries the facts in the shape they have: a cycle's worth of days,
/// some spent, some held for a request nobody has answered, some left.
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
    final spent = available == 0;

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
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  ref.t('leave.balance.eyebrow'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: XpertTypography.eyebrow.copyWith(
                    color: XpertColors.muted,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (total > 0) ...[
                const SizedBox(width: XpertSpacing.sm),
                Expanded(
                  child: Text(
                    ref.t('leave.balance.of_cycle', {'count': '$total'}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: XpertTypography.caption.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$available',
                style: XpertTypography.metric.copyWith(
                  fontSize: 38,
                  // A zero balance is not an achievement to set in ink.
                  color: spent ? XpertColors.muted : leaveLeftColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                ref.t(available == 1 ? 'leave.day' : 'leave.balance.days'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: XpertColors.muted,
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
                if (available > 0)
                  _Legend(
                    color: leaveLeftColor,
                    label: ref.t('leave.balance.left', {'count': '$available'}),
                  ),
                if (pending > 0)
                  _Legend(
                    color: leaveWaitingColor,
                    label: ref.t('leave.balance.waiting', {
                      'count': '$pending',
                    }),
                  ),
                if (used > 0)
                  _Legend(
                    color: leaveUsedColor,
                    label: ref.t('leave.balance.used', {'count': '$used'}),
                  ),
              ],
            ),
          ],
          if (lapsed > 0) ...[
            const SizedBox(height: 6),
            Text(
              ref.t('leave.balance.lapsed', {'count': '$lapsed'}),
              style: XpertTypography.caption.copyWith(fontSize: 12),
            ),
          ],
          if (canApplyUnpaid) ...[
            const SizedBox(height: XpertSpacing.sm),
            _UnpaidNotice(text: ref.t('leave.unpaid_available_hint')),
          ],
        ],
      ),
    );
  }
}

/// The cycle as one bar: left, waiting, used — in that order, because that is
/// the order a partner cares about them in.
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
        height: 10,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (available > 0)
              Expanded(
                flex: available,
                child: const ColoredBox(color: leaveLeftColor),
              ),
            if (pending > 0)
              Expanded(
                flex: pending,
                child: const ColoredBox(color: leaveWaitingColor),
              ),
            if (used > 0)
              Expanded(
                flex: used,
                child: const ColoredBox(color: leaveUsedColor),
              ),
            // Something has to be drawn, or the bar disappears on the day a
            // partner has spent everything and has nothing pending.
            if (available + pending + used == 0)
              const Expanded(child: ColoredBox(color: _meterTrack)),
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: XpertColors.muted,
          ),
        ),
      ],
    );
  }
}

class _UnpaidNotice extends StatelessWidget {
  const _UnpaidNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: XpertSpacing.sm,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: XpertColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(XpertRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: XpertColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: XpertColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
