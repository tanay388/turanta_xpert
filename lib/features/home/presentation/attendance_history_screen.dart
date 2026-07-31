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

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.item});

  final AttendanceHistoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = DateFormat('EEE, d MMM yyyy').format(
      item.scheduledStartAt.toLocal(),
    );
    final status = _statusLabel(ref, item.attendanceStatus);
    final color = _statusColor(item.attendanceStatus);

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
                  day,
                  style: XpertTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(XpertRadius.pill),
                ),
                child: Text(
                  status,
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
          Text(
            item.shiftLabel ?? item.shiftName ?? '—',
            style: XpertTypography.caption,
          ),
          if (item.warehouseName != null) ...[
            Text(item.warehouseName!, style: XpertTypography.caption),
          ],
          const SizedBox(height: 8),
          Text(
            '${ref.t('attendance.check_in')}: ${_fmt(item.checkinAt)}',
            style: XpertTypography.caption.copyWith(
              color: XpertColors.onSurface,
            ),
          ),
          Text(
            '${ref.t('attendance.check_out')}: ${_fmt(item.checkoutAt)}',
            style: XpertTypography.caption.copyWith(
              color: XpertColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('h:mm a').format(dt.toLocal());
  }

  String _statusLabel(WidgetRef ref, String status) {
    return switch (status) {
      'CHECKED_IN' => ref.t('attendance.status_checked_in'),
      'CHECKED_OUT' => ref.t('attendance.status_checked_out'),
      'AUTO_CHECKED_OUT' => ref.t('attendance.status_auto_out'),
      'ABSENT' => ref.t('attendance.status_absent'),
      _ => status,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'CHECKED_IN' => XpertColors.success,
      'CHECKED_OUT' => XpertColors.muted,
      'AUTO_CHECKED_OUT' => const Color(0xFFF57C00),
      'ABSENT' => XpertColors.danger,
      _ => XpertColors.muted,
    };
  }
}
