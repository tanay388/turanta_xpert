import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../app/shell/xpert_screen_scaffold.dart';
import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/leave_api.dart';
import 'leave_controller.dart';
import 'widgets/apply_leave_sheet.dart';
import 'widgets/leave_balance.dart';
import 'widgets/leave_request_card.dart';

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
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: summary == null || !summary.canApply
                          ? null
                          : () => _openApplySheet(summary),
                      style: FilledButton.styleFrom(
                        backgroundColor: XpertColors.heroAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(XpertRadius.pill),
                        ),
                      ),
                      icon: const Icon(Icons.event_busy_rounded, size: 21),
                      label: Text(
                        summary?.canApplyUnpaid == true
                            ? ref.t('leave.apply_cta_unpaid')
                            : ref.t('leave.apply_cta'),
                        style: const TextStyle(
                          fontSize: 16,
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
                  else
                    ..._requestSections(summary, state.isSubmitting),
                ],
              ),
            ),
    );
  }

  /// Waiting first — those are the ones a partner is still thinking about and
  /// the only ones they can cancel. Then days off still to come, then the
  /// record.
  List<Widget> _requestSections(LeaveSummary summary, bool busy) {
    final waiting = <LeaveRequestItem>[];
    final upcoming = <LeaveRequestItem>[];
    final past = <LeaveRequestItem>[];
    for (final request in summary.requests) {
      if (request.isPending) {
        waiting.add(request);
      } else if (request.isApproved && !_isOver(request, summary.today)) {
        upcoming.add(request);
      } else {
        past.add(request);
      }
    }

    return [
      ..._section(ref.t('leave.section.waiting'), waiting, busy),
      ..._section(ref.t('leave.section.upcoming'), upcoming, busy),
      ..._section(ref.t('leave.section.past'), past, busy),
    ];
  }

  List<Widget> _section(String title, List<LeaveRequestItem> items, bool busy) {
    if (items.isEmpty) return const [];
    return [
      SectionLabel(title),
      const SizedBox(height: XpertSpacing.sm),
      for (final item in items) ...[
        LeaveRequestCard(
          item: item,
          busy: busy,
          onCancel: item.isPending ? () => _confirmCancel(item.id) : null,
        ),
        const SizedBox(height: XpertSpacing.sm),
      ],
      const SizedBox(height: XpertSpacing.md),
    ];
  }

  bool _isOver(LeaveRequestItem request, String today) =>
      request.endDate.compareTo(today) < 0;

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
            style: FilledButton.styleFrom(backgroundColor: XpertColors.danger),
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
