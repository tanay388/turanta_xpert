import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/shell/xpert_screen_scaffold.dart';
import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../../core/utils/rupees.dart';
import '../data/referral_api.dart';
import 'referral_controller.dart';
import 'widgets/referral_funnel.dart';

/// Refer & Earn.
///
/// The screen answers three questions in order, because a partner who cannot
/// answer them will not share anything: what do I get, what does my friend
/// get, and when does the money actually arrive. The code stays on the canvas
/// at a size you can read across a room and dictate over a phone call.
class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(referralProvider.notifier).refresh();
    });
  }

  Future<void> _share(ReferralSummary summary) async {
    final message = ref.t('referral.share.message', {
      'code': summary.code,
      'amount': rupees(summary.refereeAmount),
      'jobs': '${summary.refereeJobs}',
      'link': summary.shareLink,
    });
    await SharePlus.instance.share(ShareParams(text: message));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(referralProvider);
    final summary = state.summary;
    final loading = state.isLoading && summary == null;

    return XpertScreenScaffold(
      title: ref.t('referral.title'),
      header: summary == null
          ? null
          : _CodeBlock(summary: summary, onShare: () => _share(summary)),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(referralProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  XpertSpacing.lg,
                  XpertSpacing.lg,
                  XpertSpacing.lg,
                  XpertSpacing.xxl,
                ),
                children: [
                  if (state.error != null)
                    Text(
                      state.error!,
                      style: XpertTypography.caption.copyWith(
                        color: XpertColors.danger,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  if (summary != null) ...[
                    if (!summary.enabled) ...[
                      _PausedNotice(),
                      const SizedBox(height: XpertSpacing.lg),
                    ],
                    _OfferCard(summary: summary),
                    const SizedBox(height: XpertSpacing.lg),
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () => _share(summary),
                        icon: const Icon(Icons.share_rounded, size: 20),
                        label: Text(
                          ref.t('referral.cta.share'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: XpertSpacing.xl),
                    _HowItWorks(summary: summary),
                    if (summary.joiningBonus case final bonus?) ...[
                      const SizedBox(height: XpertSpacing.xl),
                      _JoiningBonusCard(bonus: bonus),
                    ],
                    if (summary.totalEarned > 0 ||
                        summary.pendingAmount > 0) ...[
                      const SizedBox(height: XpertSpacing.xl),
                      _EarnedStrip(summary: summary),
                    ],
                    const SizedBox(height: XpertSpacing.xl),
                    if (summary.friends.isEmpty)
                      EmptyState(
                        icon: Icons.group_add_rounded,
                        image: 'assets/images/empty_referal.png',
                        title: ref.t('referral.empty.title'),
                        body: ref.t('referral.empty.body', {
                          'amount': rupees(summary.referrerAmount),
                          'jobs': '${summary.referrerJobs}',
                        }),
                      )
                    else ...[
                      SectionLabel(
                        ref.t('referral.friends'),
                        trailing: Text(
                          '${summary.friends.length}',
                          style: XpertTypography.metric.copyWith(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: XpertSpacing.sm),
                      for (final friend in summary.friends) ...[
                        ReferralInviteCard(item: friend),
                        const SizedBox(height: XpertSpacing.sm),
                      ],
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

/// The code, on the dark canvas, with the two things you can do to it.
class _CodeBlock extends ConsumerWidget {
  const _CodeBlock({required this.summary, required this.onShare});

  final ReferralSummary summary;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        XpertSpacing.md,
        XpertSpacing.sm,
        XpertSpacing.sm,
        XpertSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: XpertColors.heroCard,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.t('referral.code.label'),
                  style: XpertTypography.eyebrow.copyWith(
                    color: XpertColors.heroAccent,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    summary.code,
                    style: XpertTypography.display.copyWith(
                      fontSize: 28,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _CodeAction(
            icon: Icons.copy_rounded,
            tooltip: ref.t('referral.code.copy'),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: summary.code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ref.t('referral.code.copied'))),
              );
            },
          ),
          const SizedBox(width: XpertSpacing.xs),
          _CodeAction(
            icon: Icons.share_rounded,
            tooltip: ref.t('referral.cta.share'),
            onTap: onShare,
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _CodeAction extends StatelessWidget {
  const _CodeAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? XpertColors.primary : XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(XpertRadius.md),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: XpertColors.onSurface),
          ),
        ),
      ),
    );
  }
}

/// Both sides of the deal, side by side. This is the screen's whole job.
class _OfferCard extends ConsumerWidget {
  const _OfferCard({required this.summary});

  final ReferralSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/images/two_person_refering_clay.png',
            height: 132,
            fit: BoxFit.contain,
            cacheHeight: 396,
            errorBuilder: (_, _, _) => const SizedBox(height: 8),
          ),
          const SizedBox(height: XpertSpacing.sm),
          _OfferRow(
            label: ref.t('referral.you_get'),
            amount: summary.referrerAmount,
            note: ref.t('referral.after_their_jobs', {
              'jobs': '${summary.referrerJobs}',
            }),
            emphasised: true,
          ),
          Divider(
            height: XpertSpacing.lg,
            color: XpertColors.border.withValues(alpha: 0.3),
          ),
          _OfferRow(
            label: ref.t('referral.friend_gets'),
            amount: summary.refereeAmount,
            note: ref.t('referral.after_own_jobs', {
              'jobs': '${summary.refereeJobs}',
            }),
          ),
        ],
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({
    required this.label,
    required this.amount,
    required this.note,
    this.emphasised = false,
  });

  final String label;
  final double amount;
  final String note;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: XpertTypography.label.copyWith(fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                note,
                style: XpertTypography.caption.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: XpertSpacing.sm),
        Text(
          rupees(amount),
          style: XpertTypography.metric.copyWith(
            fontSize: emphasised ? 26 : 20,
            color: emphasised ? XpertColors.success : XpertColors.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Three steps, ending where the money lands — the part nobody could find.
class _HowItWorks extends ConsumerWidget {
  const _HowItWorks({required this.summary});

  final ReferralSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = [
      ref.t('referral.how.share'),
      ref.t('referral.how.signup'),
      ref.t('referral.how.paid', {'jobs': '${summary.referrerJobs}'}),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(ref.t('referral.how.title')),
        const SizedBox(height: XpertSpacing.sm),
        for (var i = 0; i < steps.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: XpertColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: XpertTypography.label.copyWith(
                    fontSize: 12,
                    color: XpertColors.heroAccent,
                  ),
                ),
              ),
              const SizedBox(width: XpertSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    steps[i],
                    style: XpertTypography.body.copyWith(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          if (i < steps.length - 1) const SizedBox(height: XpertSpacing.sm),
        ],
        const SizedBox(height: XpertSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.push('/paisa'),
            icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
            label: Text(ref.t('referral.see_payouts')),
          ),
        ),
      ],
    );
  }
}

/// Shown to a partner who themselves joined on someone's code.
class _JoiningBonusCard extends ConsumerWidget {
  const _JoiningBonusCard({required this.bonus});

  final JoiningBonus bonus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.secondary,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
      ),
      child: Row(
        children: [
          Icon(
            bonus.paid ? Icons.verified_rounded : Icons.card_giftcard_rounded,
            color: XpertColors.heroAccent,
          ),
          const SizedBox(width: XpertSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.t('referral.joining.title', {
                    'amount': rupees(bonus.amount),
                  }),
                  style: XpertTypography.label.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  bonus.paid
                      ? ref.t('referral.joining.paid')
                      : ref.t('referral.joining.progress', {
                          'done': '${bonus.jobsDone}',
                          'total': '${bonus.jobsNeeded}',
                        }),
                  style: XpertTypography.caption.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EarnedStrip extends ConsumerWidget {
  const _EarnedStrip({required this.summary});

  final ReferralSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: XpertSpacing.md,
        vertical: XpertSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: XpertColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(XpertRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.savings_rounded,
            color: XpertColors.success,
            size: 20,
          ),
          const SizedBox(width: XpertSpacing.sm),
          Expanded(
            child: Text(
              ref.t('referral.earned.label'),
              style: XpertTypography.label.copyWith(fontSize: 14),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rupees(summary.totalEarned),
                style: XpertTypography.metric.copyWith(
                  fontSize: 18,
                  color: XpertColors.success,
                ),
              ),
              if (summary.pendingAmount > 0)
                Text(
                  ref.t('referral.pending', {
                    'amount': rupees(summary.pendingAmount),
                  }),
                  style: XpertTypography.caption.copyWith(fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PausedNotice extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.background,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(Icons.pause_circle_rounded, color: XpertColors.muted),
          const SizedBox(width: XpertSpacing.sm),
          Expanded(
            child: Text(
              ref.t('referral.paused'),
              style: XpertTypography.caption.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
