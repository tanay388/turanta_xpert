import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../data/leave_api.dart';
import '../leave_controller.dart';

/// Asking for time off.
///
/// Two things were wrong with the old sheet. The dates were two separate
/// full-width tiles that each opened their own modal picker, so choosing one
/// range meant going two modals deep and holding "from" in your head while
/// picking "to". And the reason was a dropdown — five fixed options behind a
/// tap and a scroll, in an app used one-handed on the move.
///
/// Now: one range, one picker; and five reasons you can see and tap.
class ApplyLeaveSheet extends ConsumerStatefulWidget {
  const ApplyLeaveSheet({super.key, required this.summary});

  final LeaveSummary summary;

  @override
  ConsumerState<ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends ConsumerState<ApplyLeaveSheet> {
  late DateTime _start;
  late DateTime _end;
  String? _reasonCode;
  final _otherReasonCtrl = TextEditingController();
  String? _formError;

  static const _reasons = <(String, IconData)>[
    ('sick', Icons.healing_rounded),
    ('family', Icons.family_restroom_rounded),
    ('personal', Icons.person_outline_rounded),
    ('festival', Icons.celebration_rounded),
    ('other', Icons.more_horiz_rounded),
  ];

  DateTime get _min => DateTime.parse(widget.summary.today);
  DateTime get _max => DateTime.parse(widget.summary.maxDate);

  @override
  void initState() {
    super.initState();
    _start = _min;
    _end = _min;
  }

  @override
  void dispose() {
    _otherReasonCtrl.dispose();
    super.dispose();
  }

  int get _days => _end.difference(_start).inDays + 1;

  bool get _isOther => _reasonCode == 'other';

  int get _limit => widget.summary.canApplyUnpaid
      ? widget.summary.maxUnpaidDays
      : widget.summary.availableDays;

  bool get _daysOverLimit => _days > _limit;

  String _reasonLabel(String code) => ref.t('leave.reason_$code');

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: _min,
      lastDate: _max,
      initialDateRange: DateTimeRange(start: _start, end: _end),
      helpText: ref.t('leave.pick_dates'),
    );
    if (picked == null) return;
    setState(() {
      _start = picked.start;
      _end = picked.end;
      _formError = _daysOverLimit ? _limitMessage() : null;
    });
  }

  String _limitMessage() => widget.summary.canApplyUnpaid
      ? ref.t('leave.unpaid_too_long', {'days': '${widget.summary.maxUnpaidDays}'})
      : ref.t('leave.not_enough_detail', {
          'available': '${widget.summary.availableDays}',
          'selected': '$_days',
        });

  @override
  Widget build(BuildContext context) {
    final leaveState = ref.watch(leaveProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final canSubmit = !leaveState.isSubmitting && !_daysOverLimit;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        XpertSpacing.lg,
        XpertSpacing.md,
        XpertSpacing.lg,
        XpertSpacing.lg + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: XpertColors.border,
                  borderRadius: BorderRadius.circular(XpertRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: XpertSpacing.lg),
            Text(
              ref.t('leave.apply_title'),
              style: XpertTypography.title.copyWith(fontSize: 20),
            ),
            const SizedBox(height: XpertSpacing.xs),
            Text(
              widget.summary.canApplyUnpaid
                  ? ref.t('leave.apply_subtitle_unpaid', {
                      'days': '${widget.summary.maxUnpaidDays}',
                    })
                  : ref.t('leave.apply_subtitle', {
                      'days': '${widget.summary.availableDays}',
                    }),
              style: XpertTypography.caption.copyWith(fontSize: 13),
            ),
            const SizedBox(height: XpertSpacing.lg),
            _FieldLabel(ref.t('leave.dates')),
            const SizedBox(height: XpertSpacing.sm),
            _RangeTile(
              start: _start,
              end: _end,
              days: _days,
              hasError: _daysOverLimit,
              onTap: _pickRange,
            ),
            if (_formError != null) ...[
              const SizedBox(height: XpertSpacing.sm),
              _InlineError(message: _formError!),
            ],
            const SizedBox(height: XpertSpacing.lg),
            _FieldLabel(ref.t('leave.reason_label')),
            const SizedBox(height: XpertSpacing.sm),
            // Tappable and visible beats a dropdown for five fixed options —
            // one tap instead of tap, scroll, tap, and you can see them all.
            Wrap(
              spacing: XpertSpacing.sm,
              runSpacing: XpertSpacing.sm,
              children: [
                for (final (code, icon) in _reasons)
                  _ReasonChip(
                    icon: icon,
                    label: _reasonLabel(code),
                    selected: _reasonCode == code,
                    onTap: () => setState(() {
                      _reasonCode = code;
                      _formError = null;
                    }),
                  ),
              ],
            ),
            if (_isOther) ...[
              const SizedBox(height: XpertSpacing.md),
              TextField(
                controller: _otherReasonCtrl,
                maxLength: 200,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: ref.t('leave.reason_other_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(XpertRadius.md),
                  ),
                ),
              ),
            ],
            if (leaveState.error != null) ...[
              const SizedBox(height: XpertSpacing.md),
              _InlineError(message: leaveState.error!),
            ],
            const SizedBox(height: XpertSpacing.lg),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: canSubmit ? _submit : null,
                child: leaveState.isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        // The button states what it will do, including how much
                        // of the balance it spends.
                        ref.t('leave.submit_days', {'days': '$_days'}),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_daysOverLimit) {
      setState(() => _formError = _limitMessage());
      return;
    }
    if (_reasonCode == null) {
      setState(() => _formError = ref.t('leave.reason_required'));
      return;
    }
    if (_isOther && _otherReasonCtrl.text.trim().isEmpty) {
      setState(() => _formError = ref.t('leave.reason_other_required'));
      return;
    }

    setState(() => _formError = null);

    final reason = _isOther
        ? _otherReasonCtrl.text.trim()
        : _reasonLabel(_reasonCode!);

    final ok = await ref
        .read(leaveProvider.notifier)
        .apply(
          startDate: DateFormat('yyyy-MM-dd').format(_start),
          endDate: DateFormat('yyyy-MM-dd').format(_end),
          reason: reason,
        );

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _formError = ref.read(leaveProvider).error ?? ref.t('leave.not_enough');
      });
    }
  }
}

class _RangeTile extends ConsumerWidget {
  const _RangeTile({
    required this.start,
    required this.end,
    required this.days,
    required this.hasError,
    required this.onTap,
  });

  final DateTime start;
  final DateTime end;
  final int days;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('EEE, d MMM');
    final single = DateUtils.isSameDay(start, end);

    return Material(
      color: const Color(0xFFF6F9FB),
      borderRadius: BorderRadius.circular(XpertRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(XpertSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(XpertRadius.lg),
            border: Border.all(
              color: hasError ? XpertColors.danger : const Color(0xFFDCE4EA),
              width: hasError ? 2 : 1.2,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 22,
                color: XpertColors.primary,
              ),
              const SizedBox(width: XpertSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      single
                          ? fmt.format(start)
                          : '${fmt.format(start)}  →  ${fmt.format(end)}',
                      style: XpertTypography.label.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ref.t('leave.days_selected', {'days': '$days'}),
                      style: XpertTypography.caption.copyWith(
                        fontSize: 12.5,
                        color: hasError ? XpertColors.danger : XpertColors.muted,
                        fontWeight: hasError ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: XpertColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? XpertColors.primary.withValues(alpha: 0.12)
            : const Color(0xFFF6F9FB),
        borderRadius: BorderRadius.circular(XpertRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(XpertRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: XpertSpacing.md,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(XpertRadius.pill),
              border: Border.all(
                color: selected ? XpertColors.primary : const Color(0xFFDCE4EA),
                width: selected ? 1.8 : 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? XpertColors.primary : XpertColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? XpertColors.onSurface
                        : XpertColors.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: XpertTypography.eyebrow.copyWith(
        color: XpertColors.muted,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// Errors sit against the thing that is wrong, not centred at the foot of the
/// sheet where you have to work out what they refer to.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 15,
          color: XpertColors.danger,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: XpertTypography.caption.copyWith(
              color: XpertColors.danger,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
