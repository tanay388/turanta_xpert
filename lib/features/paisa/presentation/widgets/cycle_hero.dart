import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../../../core/utils/rupees.dart';
import '../../data/earning_models.dart';
import '../payout_status_chip.dart';

/// This fortnight's money.
///
/// A cycle is a window, so it is drawn as one: how far through it you are and
/// how many days are left, which together answer "why is this smaller than
/// last time" on day three and "when do I get it" on day twelve.
class CycleHero extends ConsumerWidget {
  const CycleHero({super.key, required this.summary, this.onTap});

  final EarningSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = summary.periodStart;
    final end = summary.periodEnd;

    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(XpertSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ref.t('paisa.current_cycle').toUpperCase(),
                        style: XpertTypography.eyebrow.copyWith(
                          color: XpertColors.muted,
                          letterSpacing: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: XpertSpacing.sm),
                    PayoutStatusChip(status: summary.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  rupees(summary.totalAmount),
                  style: XpertTypography.metric.copyWith(fontSize: 38),
                ),
                if (start != null && end != null) ...[
                  const SizedBox(height: XpertSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(XpertRadius.pill),
                    child: LinearProgressIndicator(
                      value: _cycleProgress(start, end),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE3EBF1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        XpertColors.heroAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${DateFormat('d MMM').format(start)} – '
                          '${DateFormat('d MMM').format(end)}',
                          style: XpertTypography.caption.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: XpertSpacing.sm),
                      Text(
                        _daysLeftLabel(ref, end),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: XpertColors.heroAccent,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // The one tappable thing on the card, said in words. It used to be a
          // chevron beside the dates, which read as decoration.
          if (onTap != null)
            InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: XpertSpacing.md,
                  vertical: 11,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE8EDF1))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ref.t('paisa.see_jobs'),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: XpertColors.heroAccent,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: XpertColors.heroAccent,
                    ),
                  ],
                ),
              ),
            ),
        ],
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

/// Counted in calendar days, the way a partner counts them: a cycle ending on
/// the 27th has nine days left on the 18th, whatever the hour.
String _daysLeftLabel(WidgetRef ref, DateTime end) {
  final now = DateTime.now();
  final days = DateTime(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days < 0) return ref.t('paisa.cycle_closed');
  if (days == 0) return ref.t('paisa.last_day');
  if (days == 1) return ref.t('paisa.one_day_left');
  return ref.t('paisa.days_left', {'days': '$days'});
}
