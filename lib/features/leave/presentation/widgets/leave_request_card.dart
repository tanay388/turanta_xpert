import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../data/leave_api.dart';

/// How a request looks at a glance: one colour, one icon, one word.
class LeaveStatusLook {
  const LeaveStatusLook(this.color, this.icon, this.labelKey);

  final Color color;
  final IconData icon;
  final String labelKey;
}

LeaveStatusLook leaveStatusLook(LeaveRequestItem item) => switch (item.status) {
  'PENDING' => const LeaveStatusLook(
    XpertColors.warning,
    Icons.hourglass_top_rounded,
    'leave.status_waiting',
  ),
  'APPROVED' => const LeaveStatusLook(
    XpertColors.success,
    Icons.check_circle_rounded,
    'leave.status_approved',
  ),
  'REJECTED' => const LeaveStatusLook(
    XpertColors.danger,
    Icons.cancel_rounded,
    'leave.status_rejected',
  ),
  _ => const LeaveStatusLook(
    XpertColors.muted,
    Icons.remove_circle_outline_rounded,
    'leave.status_cancelled',
  ),
};

/// One leave request.
///
/// The dates lead, because that is what the request is, and the status is the
/// colour of the whole card rather than one pill among others. The reason the
/// partner gave and whatever their supervisor wrote back were both on the
/// payload and shown nowhere — a rejected request said "Rejected" and left the
/// partner to guess why.
class LeaveRequestCard extends ConsumerWidget {
  const LeaveRequestCard({
    super.key,
    required this.item,
    required this.busy,
    this.onCancel,
  });

  final LeaveRequestItem item;
  final bool busy;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = leaveStatusLook(item);
    final reason = (item.reason ?? '').trim();
    final note = (item.reviewNote ?? '').trim();
    final decidedBy = (item.reviewedByName ?? '').trim();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0B1720),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      // The status as a stripe down the side: four cards in a list are told
      // apart before a word of any of them is read. Positioned, not a Row
      // child, so the stripe takes the card's height without measuring it
      // twice.
      child: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: 4,
            child: ColoredBox(color: look.color),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              XpertSpacing.md + 4,
              XpertSpacing.md,
              XpertSpacing.md,
              XpertSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: look.color.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(look.icon, size: 20, color: look.color),
                    ),
                    const SizedBox(width: XpertSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _range(),
                            style: XpertTypography.label.copyWith(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              ref.t(look.labelKey),
                              ref.t(
                                item.isUnpaid
                                    ? 'leave.type_unpaid_leave'
                                    : 'leave.type_paid_leave',
                              ),
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: look.color,
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: XpertSpacing.xs),
                    Flexible(child: _DayCount(days: item.daysCount)),
                  ],
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: XpertSpacing.sm),
                  Text(
                    reason,
                    style: XpertTypography.caption.copyWith(fontSize: 13),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (note.isNotEmpty) ...[
                  const SizedBox(height: XpertSpacing.sm),
                  _Note(text: note, color: look.color),
                ],
                if (decidedBy.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    ref.t('leave.decided_by', {'name': decidedBy}),
                    style: XpertTypography.caption.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (onCancel != null) ...[
                  const SizedBox(height: XpertSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: busy ? null : onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: XpertColors.danger,
                        side: BorderSide(
                          color: XpertColors.danger.withValues(alpha: 0.4),
                        ),
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(XpertRadius.pill),
                        ),
                      ),
                      child: Text(ref.t('leave.cancel_cta')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// `24 – 26 Sep`, or one date when it is a single day. The month is printed
  /// once unless the range crosses one.
  String _range() {
    final start = DateTime.tryParse(item.startDate);
    final end = DateTime.tryParse(item.endDate);
    if (start == null || end == null) return item.startDate;
    if (item.startDate == item.endDate) {
      return DateFormat('EEE, d MMM').format(start);
    }
    final from = DateFormat(
      start.month == end.month && start.year == end.year ? 'd' : 'd MMM',
    ).format(start);
    return '$from – ${DateFormat('d MMM').format(end)}';
  }
}

class _DayCount extends ConsumerWidget {
  const _DayCount({required this.days});

  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: XpertColors.background,
        borderRadius: BorderRadius.circular(XpertRadius.pill),
      ),
      child: Text(
        '$days ${ref.t(days == 1 ? 'leave.day' : 'leave.balance.days')}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: XpertColors.onSurface,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// What the supervisor wrote back, in the colour of their answer.
class _Note extends StatelessWidget {
  const _Note({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: XpertSpacing.sm,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(XpertRadius.md),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, height: 1.4, color: color),
      ),
    );
  }
}
