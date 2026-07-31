import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/leave_api.dart';
import 'leave_controller.dart';

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});

  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends ConsumerState<LeaveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaveProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leaveProvider);
    final summary = state.summary;

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(
        title: Text(ref.t('leave.title')),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(leaveProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(XpertSpacing.lg),
          children: [
            _BalanceCard(
              available: summary?.availableDays ?? 0,
              total: summary?.balanceDays ?? 0,
              pending: summary?.pendingDays ?? 0,
              lapsed: summary?.lapsedDaysTotal ?? 0,
              canApplyUnpaid: summary?.canApplyUnpaid ?? false,
              loading: state.isLoading && summary == null,
            ),
            const SizedBox(height: XpertSpacing.md),
            Text(
              summary?.canApplyUnpaid == true
                  ? ref.t('leave.hint_unpaid', {
                      'days': '${summary!.maxUnpaidDays}',
                    })
                  : ref.t('leave.hint'),
              style: XpertTypography.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: XpertSpacing.lg),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: summary == null || !summary.canApply
                    ? null
                    : () => _openApplySheet(context, summary),
                icon: const Icon(Icons.event_busy, size: 28),
                label: Text(
                  summary?.canApplyUnpaid == true
                      ? ref.t('leave.apply_cta_unpaid')
                      : ref.t('leave.apply_cta'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: XpertColors.primary,
                  foregroundColor: XpertColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(XpertRadius.lg),
                  ),
                ),
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: XpertSpacing.md),
              Text(
                state.error!,
                style: XpertTypography.caption.copyWith(color: XpertColors.danger),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: XpertSpacing.xl),
            Text(ref.t('leave.my_requests'), style: XpertTypography.label),
            const SizedBox(height: XpertSpacing.sm),
            if (state.isLoading && summary == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (summary == null || summary.requests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  ref.t('leave.empty'),
                  style: XpertTypography.caption,
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...summary.requests.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: XpertSpacing.sm),
                  child: _RequestCard(
                    item: r,
                    busy: state.isSubmitting,
                    onCancel: r.isPending
                        ? () => _confirmCancel(context, r.id)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openApplySheet(BuildContext context, LeaveSummary summary) async {
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: XpertColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(XpertRadius.xl)),
      ),
      builder: (_) => _ApplyLeaveSheet(summary: summary),
    );
    if (applied == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text(ref.t('leave.applied_ok'))),
      );
    }
  }

  Future<void> _confirmCancel(BuildContext context, int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.t('leave.cancel_title')),
        content: Text(ref.t('leave.cancel_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ref.t('leave.no')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ref.t('leave.yes_cancel')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final success = await ref.read(leaveProvider.notifier).cancel(id);
    if (!mounted) return;
    final err = ref.read(leaveProvider).error;
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(
          success ? ref.t('leave.cancelled_ok') : (err ?? 'Error'),
        ),
      ),
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({
    required this.available,
    required this.total,
    required this.pending,
    required this.lapsed,
    required this.canApplyUnpaid,
    required this.loading,
  });

  final int available;
  final int total;
  final int pending;
  final int lapsed;
  final bool canApplyUnpaid;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(XpertSpacing.xl),
      decoration: BoxDecoration(
        color: XpertColors.secondary,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Text(
                  '$available',
                  style: XpertTypography.title.copyWith(fontSize: 56, height: 1),
                ),
                const SizedBox(height: XpertSpacing.xs),
                Text(
                  ref.t('leave.balance_label'),
                  style: XpertTypography.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: XpertSpacing.sm),
                Text(
                  ref.t('leave.balance_detail', {
                    'total': '$total',
                    'pending': '$pending',
                  }),
                  style: XpertTypography.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: XpertSpacing.xs),
                Text(
                  ref.t('leave.lapsed_label', {'days': '$lapsed'}),
                  style: XpertTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: XpertColors.muted,
                  ),
                ),
                if (canApplyUnpaid) ...[
                  const SizedBox(height: XpertSpacing.xs),
                  Text(
                    ref.t('leave.unpaid_available_hint'),
                    style: XpertTypography.caption.copyWith(
                      color: const Color(0xFFE65100),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({
    required this.item,
    required this.busy,
    this.onCancel,
  });

  final LeaveRequestItem item;
  final bool busy;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusLabel = switch (item.status) {
      'PENDING' => ref.t('leave.status_waiting'),
      'APPROVED' => ref.t('leave.status_approved'),
      'REJECTED' => ref.t('leave.status_rejected'),
      'CANCELLED' => ref.t('leave.status_cancelled'),
      _ => item.status,
    };
    final color = switch (item.status) {
      'PENDING' => const Color(0xFFF57C00),
      'APPROVED' => XpertColors.success,
      'REJECTED' => XpertColors.danger,
      _ => XpertColors.muted,
    };

    final range = item.startDate == item.endDate
        ? _pretty(item.startDate)
        : '${_pretty(item.startDate)} → ${_pretty(item.endDate)}';

    return Container(
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.md),
        border: Border.all(color: XpertColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  range,
                  style: XpertTypography.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(XpertRadius.pill),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${item.daysCount} day${item.daysCount == 1 ? '' : 's'}',
                style: XpertTypography.caption,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: item.isUnpaid
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(XpertRadius.pill),
                ),
                child: Text(
                  item.isUnpaid
                      ? ref.t('leave.type_unpaid')
                      : ref.t('leave.type_paid'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: item.isUnpaid
                        ? const Color(0xFFE65100)
                        : XpertColors.success,
                  ),
                ),
              ),
            ],
          ),
          if (onCancel != null) ...[
            const SizedBox(height: XpertSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: busy ? null : onCancel,
                child: Text(ref.t('leave.cancel_cta')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _pretty(String iso) {
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}

class _ApplyLeaveSheet extends ConsumerStatefulWidget {
  const _ApplyLeaveSheet({required this.summary});

  final LeaveSummary summary;

  @override
  ConsumerState<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends ConsumerState<_ApplyLeaveSheet> {
  late DateTime _start;
  late DateTime _end;
  String? _reasonCode;
  final _otherReasonCtrl = TextEditingController();
  String? _formError;

  static const _reasonCodes = [
    'sick',
    'family',
    'personal',
    'festival',
    'other',
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

  int get _days {
    return _end.difference(_start).inDays + 1;
  }

  bool get _isOther => _reasonCode == 'other';

  bool get _daysOverLimit {
    if (widget.summary.canApplyUnpaid) {
      return _days > widget.summary.maxUnpaidDays;
    }
    return _days > widget.summary.availableDays;
  }

  String _reasonLabel(String code) => ref.t('leave.reason_$code');

  void _onDatesChanged() {
    setState(() {
      _formError = null;
      if (_daysOverLimit) {
        _formError = widget.summary.canApplyUnpaid
            ? ref.t('leave.unpaid_too_long', {
                'days': '${widget.summary.maxUnpaidDays}',
              })
            : ref.t('leave.not_enough_detail', {
                'available': '${widget.summary.availableDays}',
                'selected': '$_days',
              });
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    final leaveState = ref.watch(leaveProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        XpertSpacing.lg,
        XpertSpacing.lg,
        XpertSpacing.lg,
        XpertSpacing.lg + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Text(ref.t('leave.apply_title'), style: XpertTypography.title.copyWith(fontSize: 22)),
          const SizedBox(height: XpertSpacing.xs),
          Text(
            widget.summary.canApplyUnpaid
                ? ref.t('leave.apply_subtitle_unpaid', {
                    'days': '${widget.summary.maxUnpaidDays}',
                  })
                : ref.t('leave.apply_subtitle', {
                    'days': '${widget.summary.availableDays}',
                  }),
            style: XpertTypography.caption,
          ),
          const SizedBox(height: XpertSpacing.lg),
          _DatePickerTile(
            label: ref.t('leave.from'),
            value: _start,
            first: _min,
            last: _max,
            onPick: (d) {
              setState(() {
                _start = d;
                if (_end.isBefore(_start)) _end = _start;
              });
              _onDatesChanged();
            },
          ),
          const SizedBox(height: XpertSpacing.sm),
          _DatePickerTile(
            label: ref.t('leave.to'),
            value: _end,
            first: _start,
            last: _max,
            onPick: (d) {
              setState(() => _end = d);
              _onDatesChanged();
            },
          ),
          const SizedBox(height: XpertSpacing.md),
          Text(
            ref.t('leave.days_selected', {'days': '$_days'}),
            style: XpertTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              color: _daysOverLimit ? XpertColors.danger : null,
            ),
            textAlign: TextAlign.center,
          ),
          if (_formError != null || leaveState.error != null) ...[
            const SizedBox(height: XpertSpacing.sm),
            Text(
              _formError ?? leaveState.error!,
              style: XpertTypography.caption.copyWith(color: XpertColors.danger),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: XpertSpacing.md),
          Text(ref.t('leave.reason_label'), style: XpertTypography.caption),
          const SizedBox(height: XpertSpacing.xs),
          DropdownButtonFormField<String>(
            value: _reasonCode,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: ref.t('leave.reason_hint'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(XpertRadius.md),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: XpertSpacing.md,
                vertical: XpertSpacing.md,
              ),
            ),
            items: _reasonCodes
                .map(
                  (code) => DropdownMenuItem(
                    value: code,
                    child: Text(
                      _reasonLabel(code),
                      style: XpertTypography.body.copyWith(fontSize: 16),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _reasonCode = v),
          ),
          if (_isOther) ...[
            const SizedBox(height: XpertSpacing.sm),
            TextField(
              controller: _otherReasonCtrl,
              maxLength: 200,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: ref.t('leave.reason_other_hint'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(XpertRadius.md),
                ),
              ),
            ),
          ],
          const SizedBox(height: XpertSpacing.md),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: leaveState.isSubmitting || _daysOverLimit ? null : _submit,
              child: leaveState.isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      ref.t('leave.submit'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: XpertSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (widget.summary.canApplyUnpaid) {
      if (_days > widget.summary.maxUnpaidDays) {
        setState(() {
          _formError = ref.t('leave.unpaid_too_long', {
            'days': '${widget.summary.maxUnpaidDays}',
          });
        });
        return;
      }
    } else if (_days > widget.summary.availableDays) {
      setState(() {
        _formError = ref.t('leave.not_enough_detail', {
          'available': '${widget.summary.availableDays}',
          'selected': '$_days',
        });
      });
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

    final start = DateFormat('yyyy-MM-dd').format(_start);
    final end = DateFormat('yyyy-MM-dd').format(_end);
    final ok = await ref.read(leaveProvider.notifier).apply(
          startDate: start,
          endDate: end,
          reason: reason,
        );
    if (ok && mounted) {
      Navigator.pop(context, true);
    } else if (mounted) {
      setState(() {
        _formError = ref.read(leaveProvider).error ?? ref.t('leave.not_enough');
      });
    }
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.label,
    required this.value,
    required this.first,
    required this.last,
    required this.onPick,
  });

  final String label;
  final DateTime value;
  final DateTime first;
  final DateTime last;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: XpertColors.background,
      borderRadius: BorderRadius.circular(XpertRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(XpertRadius.md),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value,
            firstDate: first,
            lastDate: last,
            helpText: label,
          );
          if (picked != null) onPick(picked);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: XpertSpacing.md,
            vertical: XpertSpacing.lg,
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, size: 28),
              const SizedBox(width: XpertSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: XpertTypography.caption),
                    Text(
                      DateFormat('EEEE, d MMM yyyy').format(value),
                      style: XpertTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
