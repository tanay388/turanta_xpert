import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/shell/xpert_screen_scaffold.dart';
import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/earning_api.dart';
import '../data/earning_models.dart';
import 'widgets/cycle_hero.dart';

/// Paisa — earnings and payouts.
///
/// Money leads, on the canvas, because that is the entire question a partner
/// opens this tab to answer. Below it: what you are paid per hour, then every
/// payout that has already happened, with the amounts set in a column you can
/// actually compare down.
class PaisaScreen extends ConsumerWidget {
  const PaisaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(earningSummaryProvider);
    final cycles = ref.watch(payoutCyclesProvider);
    final data = summary.valueOrNull;

    return XpertScreenScaffold(
      title: ref.t('nav.paisa'),
      header: data == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: XpertSpacing.lg),
              child: CycleHero(
                summary: data,
                onTap: data.currentCycleId == null
                    ? null
                    : () => context.push('/paisa/cycles/${data.currentCycleId}'),
              ),
            ),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(earningSummaryProvider);
          ref.invalidate(payoutCyclesProvider);
          await Future.wait([
            ref.read(earningSummaryProvider.future),
            ref.read(payoutCyclesProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            XpertSpacing.lg,
            XpertSpacing.lg,
            XpertSpacing.lg,
            XpertSpacing.xxl,
          ),
          children: [
            summary.when(
              loading: () => const _Loading(height: 78),
              error: (_, _) => _ErrorCard(message: ref.t('paisa.error')),
              data: (s) => _RateStrip(summary: s),
            ),
            const SizedBox(height: XpertSpacing.xl),
            cycles.when(
              loading: () => const _Loading(height: 120),
              error: (_, _) => _ErrorCard(message: ref.t('paisa.error')),
              data: (list) {
                // The accruing window is already the hero above.
                final previous = list
                    .where((c) => c.status != PayoutStatus.accruing)
                    .toList();

                if (previous.isEmpty) {
                  return EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: ref.t('paisa.empty.title'),
                    body: ref.t('paisa.empty.body'),
                  );
                }

                final paid = previous
                    .where((c) => c.status == PayoutStatus.paid)
                    .fold<double>(0, (sum, c) => sum + c.totalAmount);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionLabel(
                      ref.t('paisa.previous'),
                      // What every one of these rows adds up to. It is the
                      // reason to scroll the list at all.
                      trailing: paid <= 0
                          ? null
                          : Text(
                              '₹${paid.toStringAsFixed(0)}',
                              style: XpertTypography.metric.copyWith(
                                fontSize: 13,
                              ),
                            ),
                    ),
                    const SizedBox(height: XpertSpacing.sm),
                    for (final cycle in previous) ...[
                      _CycleRow(cycle: cycle),
                      const SizedBox(height: XpertSpacing.sm),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// What an hour is worth right now, and the rating that sets it. The band and
/// the rating used to be two label-over-value blocks with the labels nearly as
/// loud as the numbers.
class _RateStrip extends ConsumerWidget {
  const _RateStrip({required this.summary});

  final EarningSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final band = summary.band?.label;

    return Container(
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summary.ratePerHour > 0
                      ? '₹${summary.ratePerHour.toStringAsFixed(0)}'
                      : '—',
                  style: XpertTypography.metric.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 2),
                Text(
                  band == null || band.isEmpty
                      ? ref.t('paisa.per_hour')
                      : '${ref.t('paisa.per_hour')} · $band',
                  style: XpertTypography.caption.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (summary.rating != null) ...[
            Container(width: 1, height: 34, color: const Color(0xFFE8EDF1)),
            const SizedBox(width: XpertSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 17,
                      color: Color(0xFFF5A623),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      summary.rating!.toStringAsFixed(1),
                      style: XpertTypography.metric.copyWith(fontSize: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  ref.t('home.stats.rating'),
                  style: XpertTypography.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One past payout. The status is a coloured rail rather than a chip, so it
/// does not compete with the amount for the eye.
class _CycleRow extends ConsumerWidget {
  const _CycleRow({required this.cycle});

  final PayoutCycle cycle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (railColor, statusKey) = switch (cycle.status) {
      PayoutStatus.paid => (XpertColors.success, 'paisa.status.paid'),
      PayoutStatus.pending => (const Color(0xFFF5A623), 'paisa.status.pending'),
      PayoutStatus.accruing => (XpertColors.primary, 'paisa.status.accruing'),
    };

    final paidAt = cycle.paidAt;
    final subtitle = paidAt != null
        ? ref.t('paisa.paid_on', {'date': DateFormat('d MMM').format(paidAt)})
        : ref.t(statusKey);

    return Material(
      color: XpertColors.surface,
      borderRadius: BorderRadius.circular(XpertRadius.lg),
      child: InkWell(
        onTap: () => context.push('/paisa/cycles/${cycle.id}'),
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(XpertRadius.lg),
            border: Border.all(
              color: XpertColors.border.withValues(alpha: 0.45),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 4, color: railColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(XpertSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _period(cycle.periodStart, cycle.periodEnd),
                                style: XpertTypography.label.copyWith(
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                style: XpertTypography.caption.copyWith(
                                  fontSize: 12,
                                  color: railColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: XpertSpacing.sm),
                        // Tabular, so a column of amounts lines up on the
                        // decimal and can be compared at a glance.
                        Text(
                          '₹${cycle.totalAmount.toStringAsFixed(0)}',
                          style: XpertTypography.metric.copyWith(fontSize: 17),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _period(DateTime? start, DateTime? end) {
  if (start == null || end == null) return '';
  return '${DateFormat('d MMM').format(start)} – '
      '${DateFormat('d MMM').format(end)}';
}

class _Loading extends StatelessWidget {
  const _Loading({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(XpertRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: XpertColors.danger,
          ),
          const SizedBox(width: XpertSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: XpertTypography.caption.copyWith(
                color: XpertColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
