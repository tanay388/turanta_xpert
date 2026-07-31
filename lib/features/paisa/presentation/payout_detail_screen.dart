import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/earning_api.dart';
import '../data/earning_models.dart';
import 'payout_status_chip.dart';

/// Per-job earning breakdown for a single payout cycle.
class PayoutDetailScreen extends ConsumerWidget {
  const PayoutDetailScreen({super.key, required this.cycleId});
  final int cycleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(payoutCycleDetailProvider(cycleId));

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(title: Text(ref.t('paisa.detail.title'))),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(XpertSpacing.xl),
            child: Text(
              ref.t('paisa.error'),
              textAlign: TextAlign.center,
              style: XpertTypography.caption.copyWith(color: XpertColors.danger),
            ),
          ),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(payoutCycleDetailProvider(cycleId));
            await ref.read(payoutCycleDetailProvider(cycleId).future);
          },
          child: ListView(
            padding: const EdgeInsets.all(XpertSpacing.lg),
            children: [
              _HeaderCard(cycle: d.cycle),
              const SizedBox(height: XpertSpacing.lg),
              Text(ref.t('paisa.breakdown.title'), style: XpertTypography.label),
              const SizedBox(height: XpertSpacing.sm),
              if (d.items.isEmpty)
                _EmptyBreakdown(message: ref.t('paisa.empty'))
              else
                for (final item in d.items) ...[
                  _LineItemRow(item: item),
                  const SizedBox(height: XpertSpacing.sm),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

String _money(double v) => '₹${v.toStringAsFixed(0)}';

class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({required this.cycle});
  final PayoutCycle cycle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = (cycle.periodStart != null && cycle.periodEnd != null)
        ? '${DateFormat('d MMM').format(cycle.periodStart!)} – '
            '${DateFormat('d MMM yyyy').format(cycle.periodEnd!)}'
        : '';
    return Container(
      padding: const EdgeInsets.all(XpertSpacing.lg),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(period, style: XpertTypography.caption),
              PayoutStatusChip(status: cycle.status),
            ],
          ),
          const SizedBox(height: XpertSpacing.xs),
          Text(
            _money(cycle.totalAmount),
            style: XpertTypography.title.copyWith(fontSize: 30),
          ),
          if (cycle.status == PayoutStatus.paid && cycle.paidAt != null) ...[
            const SizedBox(height: 2),
            Text(
              ref.t('paisa.paid_on', {
                'date': DateFormat('d MMM yyyy').format(cycle.paidAt!),
              }),
              style: XpertTypography.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _LineItemRow extends ConsumerWidget {
  const _LineItemRow({required this.item});
  final EarningLineItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr =
        item.earnedAt != null ? DateFormat('d MMM').format(item.earnedAt!) : '';
    return Container(
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.serviceName ?? ref.t('jobs.service_fallback'),
                  style: XpertTypography.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  ref.t('paisa.breakdown.row', {
                    'hours': _trimNum(item.hours),
                    'rate': item.ratePerHour.toStringAsFixed(0),
                  }),
                  style: XpertTypography.caption,
                ),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(dateStr,
                      style: XpertTypography.caption.copyWith(fontSize: 11)),
                ],
              ],
            ),
          ),
          const SizedBox(width: XpertSpacing.sm),
          Text(
            _money(item.amount),
            style: XpertTypography.label.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// "1.5" but "1" for whole hours.
  String _trimNum(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

class _EmptyBreakdown extends StatelessWidget {
  const _EmptyBreakdown({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(XpertSpacing.xl),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.md),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: XpertTypography.caption,
      ),
    );
  }
}
