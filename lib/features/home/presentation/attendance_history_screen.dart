import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/attendance_api.dart';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState
    extends ConsumerState<AttendanceHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<AttendanceHistoryItem> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(attendanceApiProvider).getHistory();
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(title: Text(ref.t('attendance.title'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(XpertSpacing.lg),
                    children: [
                      Text(
                        _error!,
                        style: XpertTypography.caption
                            .copyWith(color: XpertColors.danger),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: XpertSpacing.md),
                      FilledButton(
                        onPressed: _load,
                        child: Text(ref.t('splash.retry')),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 80),
                          Text(
                            ref.t('attendance.empty'),
                            style: XpertTypography.caption,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(XpertSpacing.lg),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: XpertSpacing.sm),
                        itemBuilder: (_, i) => _HistoryCard(item: _items[i]),
                      ),
      ),
    );
  }
}

const _warning = Color(0xFFF57C00);

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.item});

  final AttendanceHistoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = item.scheduledStartAt.toLocal();
    final day = DateFormat(
      start.year == DateTime.now().year ? 'EEE, d MMM' : 'EEE, d MMM yyyy',
    ).format(start);

    final verdict = _verdict(ref);
    final subtitle = [
      if (item.checkinAt != null)
        '${_fmt(item.checkinAt)} → ${_fmt(item.checkoutAt)}'
      else
        ref.t('attendance.no_check_in'),
      ?(item.shiftLabel ?? item.shiftName),
      ?item.warehouseName,
    ].join('  ·  ');

    return Container(
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.md),
        border: Border.all(color: XpertColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      // Stack, not Row + IntrinsicHeight: the intrinsic pass sizes the title
      // row at its natural width, which defeats the Expanded and overflows
      // once a verdict label runs long. A positioned rail stretches to the
      // content height with no intrinsic pass at all.
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              4 + XpertSpacing.sm + 2,
              XpertSpacing.sm,
              XpertSpacing.sm + 2,
              XpertSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // The date is the fixed side: its format is bounded, so
                    // it can take its natural width. The verdict flexes,
                    // because its width is a translation away from anything —
                    // a long locale string or a missing key would otherwise
                    // push the row off the screen.
                    Text(
                      day,
                      maxLines: 1,
                      style: XpertTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: XpertSpacing.xs),
                    Expanded(
                      child: Text(
                        verdict.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: verdict.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: XpertTypography.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: 4,
            child: ColoredBox(color: verdict.color),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('h:mm a').format(dt.toLocal());
  }

  ({String label, Color color}) _verdict(WidgetRef ref) {
    return switch (item.attendanceOutcome) {
      'PRESENT' => (
          label: ref.t('attendance.outcome_present'),
          color: XpertColors.success,
        ),
      'ABSENT' => (
          label: ref.t('attendance.outcome_absent'),
          color: XpertColors.danger,
        ),
      'LATE_CHECKIN' => (
          label: ref.t('attendance.outcome_late_checkin'),
          color: _warning,
        ),
      'EARLY_CHECKOUT' => (
          label: ref.t('attendance.outcome_early_checkout'),
          color: _warning,
        ),
      _ => _legacyStatus(ref),
    };
  }

  ({String label, Color color}) _legacyStatus(WidgetRef ref) {
    return switch (item.attendanceStatus) {
      'CHECKED_IN' => (
          label: ref.t('attendance.status_checked_in'),
          color: XpertColors.success,
        ),
      'CHECKED_OUT' => (
          label: ref.t('attendance.status_checked_out'),
          color: XpertColors.muted,
        ),
      'AUTO_CHECKED_OUT' => (
          label: ref.t('attendance.status_auto_out'),
          color: _warning,
        ),
      'ABSENT' => (
          label: ref.t('attendance.status_absent'),
          color: XpertColors.danger,
        ),
      _ => (label: item.attendanceStatus, color: XpertColors.muted),
    };
  }
}
