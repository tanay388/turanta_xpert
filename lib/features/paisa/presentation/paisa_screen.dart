import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/earning_api.dart';
import '../data/earning_models.dart';
import 'payout_status_chip.dart';

/// Paisa (earnings / payouts) tab.
///
/// Shows the current fortnightly cycle payout, the partner's current rate band,
/// and the list of previous payout cycles (tap → per-job breakdown).
class PaisaScreen extends ConsumerWidget {
  const PaisaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(earningSummaryProvider);
    final cycles = ref.watch(payoutCyclesProvider);

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(title: Text(ref.t('nav.paisa'))),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(earningSummaryProvider);
          ref.invalidate(payoutCyclesProvider);
          await Future.wait([
            ref.read(earningSummaryProvider.future),
            ref.read(payoutCyclesProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(XpertSpacing.lg),
          children: [
            summary.when(
              loading: () => const _LoadingCard(),
              error: (_, _) => _ErrorCard(message: ref.t('paisa.error')),
              data: (s) => _CurrentCycleCard(summary: s),
            ),
            const SizedBox(height: XpertSpacing.lg),
            Text(
              ref.t('paisa.previous'),
              style: XpertTypography.label,
            ),
            const SizedBox(height: XpertSpacing.sm),
            cycles.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(XpertSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => _ErrorCard(message: ref.t('paisa.error')),
              data: (list) {
                // The current (ACCRUING) window is already shown at the top.
                final previous = list
                    .where((c) => c.status != PayoutStatus.accruing)
                    .toList();
                if (previous.isEmpty) {
                  return _EmptyCard(message: ref.t('paisa.empty'));
                }
                return Column(
                  children: [
                    for (final c in previous) ...[
                      _CycleRow(cycle: c),
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

String _money(double v) => '₹${v.toStringAsFixed(0)}';

String _periodLabel(DateTime? start, DateTime? end) {
  if (start == null || end == null) return '';
  final s = DateFormat('d MMM').format(start);
  final e = DateFormat('d MMM').format(end);
  return '$s – $e';
}

class _CurrentCycleCard extends ConsumerWidget {
  const _CurrentCycleCard({required this.summary});
  final EarningSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              Text(ref.t('paisa.current_cycle'), style: XpertTypography.caption),
              PayoutStatusChip(status: summary.status),
            ],
          ),
          const SizedBox(height: XpertSpacing.xs),
          Text(
            _money(summary.totalAmount),
            style: XpertTypography.title.copyWith(
              fontSize: 34,
              color: XpertColors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _periodLabel(summary.periodStart, summary.periodEnd),
            style: XpertTypography.caption,
          ),
          const SizedBox(height: XpertSpacing.md),
          const Divider(height: 1, color: XpertColors.border),
          const SizedBox(height: XpertSpacing.md),
          Row(
            children: [
              Expanded(
                child: _MetaBlock(
                  label: ref.t('paisa.rate_band'),
                  value: summary.band?.label.isNotEmpty == true
                      ? summary.band!.label
                      : '—',
                  sub: summary.ratePerHour > 0
                      ? ref.t('paisa.rate_per_hour',
                          {'rate': summary.ratePerHour.toStringAsFixed(0)})
                      : null,
                ),
              ),
              const SizedBox(width: XpertSpacing.md),
              _MetaBlock(
                label: ref.t('home.stats.rating'),
                value: summary.rating != null
                    ? summary.rating!.toStringAsFixed(1)
                    : '—',
                trailingIcon:
                    summary.rating != null ? Icons.star_rounded : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaBlock extends StatelessWidget {
  const _MetaBlock({
    required this.label,
    required this.value,
    this.sub,
    this.trailingIcon,
  });
  final String label;
  final String value;
  final String? sub;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: XpertTypography.caption),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value,
                style: XpertTypography.label.copyWith(fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 2),
              const Icon(Icons.star_rounded,
                  size: 16, color: Color(0xFFF5A623)),
            ],
          ],
        ),
        if (sub != null) ...[
          const SizedBox(height: 1),
          Text(sub!, style: XpertTypography.caption.copyWith(fontSize: 11)),
        ],
      ],
    );
  }
}

class _CycleRow extends ConsumerWidget {
  const _CycleRow({required this.cycle});
  final PayoutCycle cycle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: XpertColors.surface,
      borderRadius: BorderRadius.circular(XpertRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(XpertRadius.md),
        onTap: () => context.push('/paisa/cycles/${cycle.id}'),
        child: Padding(
          padding: const EdgeInsets.all(XpertSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _periodLabel(cycle.periodStart, cycle.periodEnd),
                      style: XpertTypography.label,
                    ),
                    const SizedBox(height: 4),
                    PayoutStatusChip(status: cycle.status),
                  ],
                ),
              ),
              const SizedBox(width: XpertSpacing.sm),
              Text(
                _money(cycle.totalAmount),
                style: XpertTypography.label.copyWith(fontSize: 17),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: XpertColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
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
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 40,
            color: XpertColors.muted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: XpertSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: XpertTypography.caption,
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(XpertSpacing.lg),
      decoration: BoxDecoration(
        color: XpertColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(XpertRadius.md),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: XpertTypography.caption.copyWith(color: XpertColors.danger),
      ),
    );
  }
}
