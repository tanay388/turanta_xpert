import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/shell/xpert_screen_scaffold.dart';
import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/leave_api.dart';
import 'leave_controller.dart';
import 'widgets/apply_leave_sheet.dart';
import 'widgets/leave_balance.dart';

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
    final loading = state.isLoading && summary == null;

    return XpertScreenScaffold(
      title: ref.t('leave.title'),
      header: summary == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: XpertSpacing.lg),
              child: LeaveBalance(
                available: summary.availableDays,
                total: summary.balanceDays,
                pending: summary.pendingDays,
                lapsed: summary.lapsedDaysTotal,
                canApplyUnpaid: summary.canApplyUnpaid,
              ),
            ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(leaveProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  XpertSpacing.lg,
                  XpertSpacing.lg,
                  XpertSpacing.lg,
                  XpertSpacing.xxl,
                ),
                children: [
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: summary == null || !summary.canApply
                          ? null
                          : () => _openApplySheet(summary),
                      icon: const Icon(Icons.event_busy_rounded, size: 22),
                      label: Text(
                        summary?.canApplyUnpaid == true
                            ? ref.t('leave.apply_cta_unpaid')
                            : ref.t('leave.apply_cta'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: XpertSpacing.sm),
                  Text(
                    ref.t('leave.approval_note'),
                    style: XpertTypography.caption.copyWith(fontSize: 12.5),
                    textAlign: TextAlign.center,
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: XpertSpacing.md),
                    Text(
                      state.error!,
                      style: XpertTypography.caption.copyWith(
                        color: XpertColors.danger,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: XpertSpacing.xl),
                  if (summary == null || summary.requests.isEmpty)
                    EmptyState(
                      icon: Icons.event_available_rounded,
                      title: ref.t('leave.empty.title'),
                      body: ref.t('leave.empty.body'),
                    )
                  else ...[
                    SectionLabel(ref.t('leave.my_requests')),
                    const SizedBox(height: XpertSpacing.sm),
                    for (final request in summary.requests) ...[
                      _RequestCard(
                        item: request,
                        busy: state.isSubmitting,
                        onCancel: request.isPending
                            ? () => _confirmCancel(request.id)
                            : null,
                      ),
                      const SizedBox(height: XpertSpacing.sm),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _openApplySheet(LeaveSummary summary) async {
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: XpertColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(XpertRadius.sheetTop),
        ),
      ),
      builder: (_) => ApplyLeaveSheet(summary: summary),
    );
    if (applied == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ref.t('leave.applied_ok'))));
    }
  }

  Future<void> _confirmCancel(int id) async {
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
            style: FilledButton.styleFrom(
              backgroundColor: XpertColors.danger,
            ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? ref.t('leave.cancelled_ok')
              : (err ?? ref.t('common.error_generic')),
        ),
      ),
    );
  }
}

/// One leave request.
///
/// The dates lead, because that is what the request is. The old card gave the
/// status pill equal billing and hung a full-width outlined Cancel button off
/// every pending row, which made cancelling look like the point.
class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.item, required this.busy, this.onCancel});

  final LeaveRequestItem item;
  final bool busy;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, statusKey) = switch (item.status) {
      'PENDING' => (const Color(0xFFF57C00), 'leave.status_waiting'),
      'APPROVED' => (XpertColors.success, 'leave.status_approved'),
      'REJECTED' => (XpertColors.danger, 'leave.status_rejected'),
      _ => (XpertColors.muted, 'leave.status_cancelled'),
    };

    final single = item.startDate == item.endDate;
    final range = single
        ? _pretty(item.startDate)
        : '${_pretty(item.startDate)}  →  ${_pretty(item.endDate)}';

    return Container(
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The day count is the quantity; the dates are the detail.
              SizedBox(
                width: 46,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item.daysCount}',
                      style: XpertTypography.metric.copyWith(fontSize: 22),
                    ),
                    Text(
                      ref.t(
                        item.daysCount == 1 ? 'leave.day' : 'leave.balance.days',
                      ),
                      style: XpertTypography.caption.copyWith(fontSize: 11),
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
                    Text(
                      range,
                      style: XpertTypography.label.copyWith(fontSize: 14),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 5),
                    // Wrap, not Row: "प्रतीक्षेत" beside "बिनपगारी" does not
                    // fit the remaining width on a 360pt screen.
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Pill(label: ref.t(statusKey), color: color),
                        _Pill(
                          label: item.isUnpaid
                              ? ref.t('leave.type_unpaid')
                              : ref.t('leave.type_paid'),
                          color: item.isUnpaid
                              ? const Color(0xFFE65100)
                              : XpertColors.success,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onCancel != null) ...[
            const SizedBox(height: XpertSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: busy ? null : onCancel,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: XpertSpacing.sm,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: XpertColors.danger,
                ),
                child: Text(
                  ref.t('leave.cancel_cta'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _pretty(String iso) {
    try {
      return DateFormat('d MMM').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(XpertRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
