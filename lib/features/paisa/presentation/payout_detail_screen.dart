import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../../core/utils/rupees.dart';
import '../data/earning_api.dart';
import '../data/earning_models.dart';
import 'payout_status_chip.dart';

/// One payout, job by job.
///
/// Laid out like the rest of the app: what the payout came to on the wash,
/// and the jobs that made it on a sheet over it. Every line is a job the
/// partner did, so every line opens it.
class PayoutDetailScreen extends ConsumerWidget {
  const PayoutDetailScreen({super.key, required this.cycleId});
  final int cycleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(payoutCycleDetailProvider(cycleId));

    return Scaffold(
      backgroundColor: XpertColors.surface,
      appBar: AppBar(
        backgroundColor: XpertColors.heroTop,
        surfaceTintColor: Colors.transparent,
        title: Text(ref.t('paisa.detail.title')),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: Icons.cloud_off_rounded,
              title: ref.t('paisa.error'),
              body: ref.t('jobs.error.body'),
              action: FilledButton(
                onPressed: () =>
                    ref.invalidate(payoutCycleDetailProvider(cycleId)),
                child: Text(ref.t('hub.retry')),
              ),
            ),
          ],
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(payoutCycleDetailProvider(cycleId));
            await ref.read(payoutCycleDetailProvider(cycleId).future);
          },
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _Hero(cycle: d.cycle, items: d.items),
              Transform.translate(
                offset: const Offset(0, -XpertRadius.sheetTop),
                child: Container(
                  decoration: const BoxDecoration(
                    color: XpertColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(XpertRadius.sheetTop),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    XpertSpacing.lg,
                    XpertSpacing.xl,
                    XpertSpacing.lg,
                    XpertSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionLabel(ref.t('paisa.breakdown.title')),
                      const SizedBox(height: XpertSpacing.sm),
                      if (d.items.isEmpty)
                        _EmptyBreakdown(message: ref.t('paisa.breakdown.empty'))
                      else ...[
                        for (final item in d.items) ...[
                          _LineItemRow(item: item),
                          const SizedBox(height: XpertSpacing.sm),
                        ],
                        const SizedBox(height: XpertSpacing.xs),
                        _TotalRow(amount: d.cycle.totalAmount),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.cycle, required this.items});

  final PayoutCycle cycle;
  final List<EarningLineItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = (cycle.periodStart != null && cycle.periodEnd != null)
        ? '${DateFormat('d MMM').format(cycle.periodStart!)} – '
              '${DateFormat('d MMM yyyy').format(cycle.periodEnd!)}'
        : '';
    final hours = items.fold<double>(0, (sum, i) => sum + i.hours);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [XpertColors.heroTop, XpertColors.heroBottom],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        XpertSpacing.lg,
        XpertSpacing.xs,
        XpertSpacing.lg,
        XpertSpacing.xl + XpertRadius.sheetTop,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  period,
                  style: XpertTypography.eyebrow.copyWith(
                    color: XpertColors.muted,
                    letterSpacing: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: XpertSpacing.sm),
              PayoutStatusChip(status: cycle.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            rupees(cycle.totalAmount),
            style: XpertTypography.metric.copyWith(fontSize: 38),
          ),
          if (cycle.status == PayoutStatus.paid && cycle.paidAt != null) ...[
            const SizedBox(height: 4),
            Text(
              ref.t('paisa.paid_on', {
                'date': DateFormat('d MMM yyyy').format(cycle.paidAt!),
              }),
              style: XpertTypography.caption.copyWith(fontSize: 13),
            ),
          ],
          if (items.isNotEmpty) ...[
            const SizedBox(height: XpertSpacing.md),
            Text(
              [
                ref.t(items.length == 1 ? 'paisa.job_one' : 'paisa.job_many', {
                  'count': '${items.length}',
                }),
                ref.t('jobs.hours', {'hours': _trimNum(hours)}),
              ].join(' · '),
              style: XpertTypography.caption.copyWith(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// One job's earning. Tapping it opens the job, which is where the address,
/// the customer's rating and the times live — this row is only the money.
class _LineItemRow extends ConsumerWidget {
  const _LineItemRow({required this.item});
  final EarningLineItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnedAt = item.earnedAt;

    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/jobs/${item.bookingId}'),
          child: Padding(
            padding: const EdgeInsets.all(XpertSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.serviceName ?? ref.t('jobs.service_fallback'),
                        style: XpertTypography.label.copyWith(fontSize: 14.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (earnedAt != null)
                            DateFormat('d MMM').format(earnedAt),
                          ref.t('paisa.breakdown.row', {
                            'hours': _trimNum(item.hours),
                            'rate': item.ratePerHour.toStringAsFixed(0),
                          }),
                        ].join(' · '),
                        style: XpertTypography.caption.copyWith(fontSize: 12.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: XpertSpacing.sm),
                Text(
                  rupees(item.amount),
                  style: XpertTypography.metric.copyWith(fontSize: 16),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: XpertColors.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the rows above add up to — the same number as the hero, where a
/// partner checking the maths expects to find it.
class _TotalRow extends ConsumerWidget {
  const _TotalRow({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: XpertSpacing.md,
        vertical: XpertSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: XpertColors.background,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ref.t('paisa.detail.total'),
              style: XpertTypography.label.copyWith(fontSize: 14.5),
            ),
          ),
          Text(
            rupees(amount),
            style: XpertTypography.metric.copyWith(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

/// "1.5" but "1" for whole hours.
String _trimNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
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
        color: XpertColors.background,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: XpertTypography.caption,
      ),
    );
  }
}
