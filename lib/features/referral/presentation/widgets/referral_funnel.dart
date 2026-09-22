import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../../../core/utils/rupees.dart';
import '../../data/referral_api.dart';

/// One friend who joined, and how close they are to paying out.
///
/// The old card drew a four-node funnel of internal statuses. A partner does
/// not think in INVITED → SIGNED_UP → ACTIVE → REWARDED; they think "how many
/// more jobs until I get paid", so that is the whole card now.
class ReferralInviteCard extends ConsumerWidget {
  const ReferralInviteCard({super.key, required this.item});

  final ReferralInvite item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = item.refereeDisplayName?.trim().isNotEmpty == true
        ? item.refereeDisplayName!.trim()
        : ref.t('referral.friend.unnamed');

    return Container(
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: XpertTypography.label.copyWith(fontSize: 15),
                ),
              ),
              const SizedBox(width: XpertSpacing.sm),
              _RewardChip(amount: item.rewardAmount, paid: item.paid),
            ],
          ),
          const SizedBox(height: XpertSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(XpertRadius.pill),
            child: LinearProgressIndicator(
              value: item.paid ? 1 : item.progress,
              minHeight: 8,
              backgroundColor: XpertColors.heroCard,
              valueColor: AlwaysStoppedAnimation(
                item.paid ? XpertColors.success : XpertColors.heroAccent,
              ),
            ),
          ),
          const SizedBox(height: XpertSpacing.xs),
          Text(
            item.paid
                ? ref.t('referral.friend.paid')
                : ref.t('referral.friend.progress', {
                    'done': '${item.jobsDone}',
                    'total': '${item.jobsNeeded}',
                  }),
            style: XpertTypography.caption.copyWith(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.amount, required this.paid});

  final double amount;
  final bool paid;

  @override
  Widget build(BuildContext context) {
    final colour = paid ? XpertColors.success : XpertColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: XpertSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: paid
            ? XpertColors.success.withValues(alpha: 0.10)
            : XpertColors.background,
        borderRadius: BorderRadius.circular(XpertRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (paid) ...[
            Icon(Icons.check_rounded, size: 14, color: colour),
            const SizedBox(width: 3),
          ],
          Text(
            rupees(amount),
            style: XpertTypography.label.copyWith(fontSize: 13, color: colour),
          ),
        ],
      ),
    );
  }
}
