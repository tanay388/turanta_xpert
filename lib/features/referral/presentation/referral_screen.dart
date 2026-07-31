import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/referral_api.dart';
import 'invite_sheet.dart';
import 'referral_controller.dart';

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

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(title: Text(ref.t('referral.title'))),
      body: RefreshIndicator(
        onRefresh: () => ref.read(referralProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(XpertSpacing.lg),
          children: [
            _HeroCard(
              summary: summary,
              loading: state.isLoading && summary == null,
            ),
            const SizedBox(height: XpertSpacing.lg),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: summary == null ? null : () => _openInvite(summary),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 24),
                label: Text(
                  ref.t('referral.cta.invite'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: XpertSpacing.md),
              Text(
                state.error!,
                style: XpertTypography.caption.copyWith(color: XpertColors.danger),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: XpertSpacing.xl),
            Text(ref.t('referral.active'), style: XpertTypography.label),
            const SizedBox(height: XpertSpacing.sm),
            if (state.isLoading && summary == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (summary == null || summary.active.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  ref.t('referral.empty_active'),
                  style: XpertTypography.caption,
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...summary.active.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: XpertSpacing.sm),
                  child: _InviteCard(
                    item: r,
                    milestoneJobs: summary.milestoneJobs,
                    code: summary.code,
                    shareLink: summary.shareLink,
                  ),
                ),
              ),
            if (summary != null && summary.lapsed.isNotEmpty) ...[
              const SizedBox(height: XpertSpacing.xl),
              Text(ref.t('referral.lapsed'), style: XpertTypography.label),
              const SizedBox(height: XpertSpacing.sm),
              ...summary.lapsed.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: XpertSpacing.sm),
                  child: _InviteCard(
                    item: r,
                    milestoneJobs: summary.milestoneJobs,
                    code: summary.code,
                    shareLink: summary.shareLink,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openInvite(ReferralSummary summary) async {
    final invited = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: XpertColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(XpertRadius.xl)),
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

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.summary, required this.loading});

  final ReferralSummary? summary;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(XpertSpacing.xl),
      decoration: BoxDecoration(
        color: XpertColors.secondary,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Icon(Icons.card_giftcard_rounded,
                    size: 36, color: XpertColors.primary),
                const SizedBox(height: XpertSpacing.sm),
                Text(
                  ref.t('referral.hero', {
                    'amount': (summary?.rewardAmount ?? 0).toStringAsFixed(0),
                  }),
                  style: XpertTypography.title.copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: XpertSpacing.md),
                Text(
                  ref.t('referral.earned', {
                    'amount': (summary?.totalEarned ?? 0).toStringAsFixed(0),
                  }),
                  style: XpertTypography.title.copyWith(fontSize: 32),
                ),
                if (summary != null && summary!.code.isNotEmpty) ...[
                  const SizedBox(height: XpertSpacing.md),
                  _CodeChip(code: summary!.code),
                ],
              ],
            ),
    );
  }
}

class _CodeChip extends ConsumerWidget {
  const _CodeChip({required this.code});
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: XpertColors.surface,
      borderRadius: BorderRadius.circular(XpertRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(XpertRadius.pill),
        onTap: () => SharePlus.instance.share(ShareParams(text: code)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: XpertSpacing.md,
            vertical: XpertSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                code,
                style: XpertTypography.label.copyWith(
                  letterSpacing: 2,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: XpertSpacing.sm),
              const Icon(Icons.copy_rounded, size: 18, color: XpertColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard({
    required this.item,
    required this.milestoneJobs,
    required this.code,
    required this.shareLink,
  });

  final ReferralInvite item;
  final int milestoneJobs;
  final String code;
  final String shareLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, statusKey) = switch (item.status) {
      'INVITED' => (XpertColors.muted, 'referral.status.invited'),
      'SIGNED_UP' => (const Color(0xFFF57C00), 'referral.status.signed_up'),
      'ACTIVE' => (XpertColors.primary, 'referral.status.active'),
      'REWARDED' => (XpertColors.success, 'referral.status.rewarded'),
      _ => (XpertColors.muted, 'referral.status.lapsed'),
    };

    final name = item.refereeDisplayName?.trim();
    final title = (name == null || name.isEmpty)
        ? ref.t('referral.invite_pending')
        : name;

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
                  title,
                  style: XpertTypography.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(XpertRadius.pill),
                ),
                child: Text(
                  ref.t(statusKey),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (item.serviceName != null) ...[
            const SizedBox(height: 4),
            Text(item.serviceName!, style: XpertTypography.caption),
          ],
          if (item.isActive) ...[
            const SizedBox(height: XpertSpacing.sm),
            Text(
              ref.t('referral.steps', {
                'n': '${(milestoneJobs - item.stepsCompleted).clamp(0, milestoneJobs)}',
              }),
              style: XpertTypography.caption.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          if (item.isRewarded) ...[
            const SizedBox(height: XpertSpacing.sm),
            Text(
              '₹${item.rewardAmount.toStringAsFixed(0)}',
              style: XpertTypography.body.copyWith(
                color: XpertColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (item.isInvited || item.isSignedUp) ...[
            const SizedBox(height: XpertSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _remind(ref),
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: Text(ref.t('referral.remind')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _remind(WidgetRef ref) {
    final message = ref.t('referral.share.message', {
      'code': code,
      'link': shareLink,
    });
    SharePlus.instance.share(ShareParams(text: message));
  }
}
