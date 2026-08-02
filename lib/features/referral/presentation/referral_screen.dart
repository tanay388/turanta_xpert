import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/shell/xpert_screen_scaffold.dart';
import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/referral_api.dart';
import 'invite_sheet.dart';
import 'referral_controller.dart';
import 'widgets/referral_funnel.dart';

/// Refer & Earn.
///
/// The code is the product — it is the thing a partner came here to get hold
/// of — so it leads, on the canvas, at a size you can read across a room and
/// dictate over a phone call. Everything else follows from it.
///
/// The screen used to open with a gift icon and "You've earned ₹0" set larger
/// than the offer itself, which greeted every new partner with their own zero.
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(referralProvider);
    final summary = state.summary;
    final loading = state.isLoading && summary == null;

    return XpertScreenScaffold(
      title: ref.t('referral.title'),
      header: summary == null
          ? null
          : _CodeBlock(
              code: summary.code,
              reward: summary.rewardAmount,
              milestoneJobs: summary.milestoneJobs,
            ),
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
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: summary == null
                          ? null
                          : () => _openInvite(summary),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 22),
                      label: Text(
                        ref.t('referral.cta.invite'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
                  // Only once there is something to celebrate. A ₹0 total set
                  // in hero type is a discouragement, not a dashboard.
                  if (summary != null && summary.totalEarned > 0) ...[
                    const SizedBox(height: XpertSpacing.lg),
                    _EarnedStrip(amount: summary.totalEarned),
                  ],
                  const SizedBox(height: XpertSpacing.xl),
                  if (summary == null || summary.active.isEmpty)
                    EmptyState(
                      icon: Icons.group_add_rounded,
                      title: ref.t('referral.empty.title'),
                      body: ref.t('referral.empty.body', {
                        'amount': (summary?.rewardAmount ?? 0).toStringAsFixed(0),
                      }),
                    )
                  else ...[
                    SectionLabel(
                      ref.t('referral.active'),
                      trailing: Text(
                        '${summary.active.length}',
                        style: XpertTypography.metric.copyWith(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: XpertSpacing.sm),
                    for (final invite in summary.active) ...[
                      ReferralInviteCard(
                        item: invite,
                        milestoneJobs: summary.milestoneJobs,
                        onRemind: () => _remind(summary),
                      ),
                      const SizedBox(height: XpertSpacing.sm),
                    ],
                  ],
                  if (summary != null && summary.lapsed.isNotEmpty) ...[
                    const SizedBox(height: XpertSpacing.lg),
                    SectionLabel(ref.t('referral.lapsed')),
                    const SizedBox(height: XpertSpacing.sm),
                    for (final invite in summary.lapsed) ...[
                      ReferralInviteCard(
                        item: invite,
                        milestoneJobs: summary.milestoneJobs,
                        onRemind: () => _remind(summary),
                      ),
                      const SizedBox(height: XpertSpacing.sm),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  void _remind(ReferralSummary summary) {
    SharePlus.instance.share(
      ShareParams(
        text: ref.t('referral.share.message', {
          'code': summary.code,
          'link': summary.shareLink,
        }),
      ),
    );
  }

  Future<void> _openInvite(ReferralSummary summary) async {
    final invited = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: XpertColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(XpertRadius.sheetTop),
        ),
      ),
      builder: (_) => InviteSheet(
        code: summary.code,
        workProfiles: ref.read(referralProvider).workProfiles,
      ),
    );
    if (invited == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.t('referral.invite.sent_ok'))),
      );
    }
  }
}

/// The code, on the canvas, with the offer stated underneath it.
class _CodeBlock extends ConsumerWidget {
  const _CodeBlock({
    required this.code,
    required this.reward,
    required this.milestoneJobs,
  });

  final String code;
  final double reward;
  final int milestoneJobs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (code.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: XpertSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(XpertSpacing.md),
          decoration: BoxDecoration(
            color: XpertColors.canvasSoft,
            borderRadius: BorderRadius.circular(XpertRadius.lg),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ref.t('referral.code.label'),
                      style: XpertTypography.eyebrow,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        height: 1,
                        color: XpertColors.onCanvas,
                      ),
                    ),
                  ],
                ),
              ),
              // Copy actually copies. The old chip showed a copy icon and
              // opened the share sheet.
              _CanvasAction(
                icon: Icons.copy_rounded,
                label: ref.t('referral.code.copy'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ref.t('referral.code.copied'))),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: XpertSpacing.sm),
        Text(
          ref.t('referral.offer', {
            'amount': reward.toStringAsFixed(0),
            'jobs': '$milestoneJobs',
          }),
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: XpertColors.onCanvasMuted,
          ),
        ),
      ],
    );
  }
}

class _CanvasAction extends StatelessWidget {
  const _CanvasAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(XpertRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 19, color: XpertColors.onCanvas),
          ),
        ),
      ),
    );
  }
}

class _EarnedStrip extends ConsumerWidget {
  const _EarnedStrip({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(XpertRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.savings_rounded,
            size: 20,
            color: XpertColors.success,
          ),
          const SizedBox(width: XpertSpacing.sm),
          Expanded(
            child: Text(
              ref.t('referral.earned.label'),
              style: XpertTypography.caption.copyWith(fontSize: 13),
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: XpertTypography.metric.copyWith(
              fontSize: 20,
              color: XpertColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
