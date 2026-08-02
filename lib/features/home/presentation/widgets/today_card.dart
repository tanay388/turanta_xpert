import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../data/summary_api.dart';

/// Today's numbers.
///
/// This was four equal tiles across a 360pt screen — 78pt each, an icon on top
/// of every one, the label competing with the value. Nothing led, so nothing
/// read. A partner opens this to answer one question, so earnings answers it
/// at full size and the rest support it underneath.
class TodayCard extends ConsumerWidget {
  const TodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(todaySummaryProvider).valueOrNull;

    final hours = data?.hoursWorked ?? 0;
    final rating = data?.rating;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(XpertSpacing.lg),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data == null || data.earnings <= 0
                ? '—'
                : '₹${data.earnings.toStringAsFixed(0)}',
            style: XpertTypography.metric.copyWith(fontSize: 34),
          ),
          const SizedBox(height: XpertSpacing.xs),
          Text(
            ref.t('home.today.earned'),
            style: XpertTypography.caption.copyWith(fontSize: 13),
          ),
          const SizedBox(height: XpertSpacing.md),
          const Divider(height: 1, color: Color(0xFFE8EDF1)),
          const SizedBox(height: XpertSpacing.md),
          Row(
            children: [
              _Stat(
                value: '${data?.jobsDone ?? 0}',
                label: ref.t('home.stats.jobs'),
              ),
              const _StatDivider(),
              _Stat(
                value: hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1),
                label: ref.t('home.stats.hours'),
              ),
              const _StatDivider(),
              _Stat(
                value: rating == null ? '—' : rating.toStringAsFixed(1),
                label: ref.t('home.stats.rating'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Value over label, always — "3" is the answer, "Jobs today" is the
          // question.
          Text(
            value,
            style: XpertTypography.metric.copyWith(fontSize: 19),
            maxLines: 1,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: XpertTypography.caption.copyWith(fontSize: 11.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: XpertSpacing.md),
      color: const Color(0xFFE8EDF1),
    );
  }
}
