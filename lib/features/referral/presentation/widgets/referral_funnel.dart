import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../data/referral_api.dart';

/// The four states an invite passes through, in order.
///
/// This is the one place a numbered rail is honestly earned: referral status
/// really is a sequence, and the whole reason a partner opens this screen is
/// to ask how far along a friend is. It used to be a bare caption — "2 steps
/// to earn" — with nothing showing where those steps sat in the journey.
const _stages = ['INVITED', 'SIGNED_UP', 'ACTIVE', 'REWARDED'];

int stageIndexOf(String status) {
  final index = _stages.indexOf(status);
  return index < 0 ? 0 : index;
}

class ReferralFunnel extends ConsumerWidget {
  const ReferralFunnel({
    super.key,
    required this.status,
    this.lapsed = false,
  });

  final String status;
  final bool lapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reached = lapsed ? -1 : stageIndexOf(status);
    final done = lapsed ? XpertColors.muted : XpertColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _stages.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i <= reached
                        ? done
                        : XpertColors.border.withValues(alpha: 0.5),
                  ),
                ),
              _Node(filled: i <= reached, color: done, last: i == _stages.length - 1),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < _stages.length; i++)
              Expanded(
                child: Text(
                  ref.t('referral.status.${_stages[i].toLowerCase()}'),
                  textAlign: i == 0
                      ? TextAlign.start
                      : i == _stages.length - 1
                      ? TextAlign.end
                      : TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: i == reached ? FontWeight.w800 : FontWeight.w500,
                    color: i <= reached ? XpertColors.onSurface : XpertColors.muted,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.filled, required this.color, required this.last});

  final bool filled;
  final Color color;
  final bool last;

  @override
  Widget build(BuildContext context) {
    // The last node is the payout, so it is drawn a size larger — the rail
    // should read as heading somewhere, not as four equal dots.
    final size = last ? 14.0 : 10.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : XpertColors.surface,
        border: Border.all(
          color: filled ? color : XpertColors.border.withValues(alpha: 0.7),
          width: 2,
        ),
      ),
      child: last && filled
          ? const Icon(Icons.check_rounded, size: 8, color: Colors.white)
          : null,
    );
  }
}

/// One invited friend.
class ReferralInviteCard extends ConsumerWidget {
  const ReferralInviteCard({
    super.key,
    required this.item,
    required this.milestoneJobs,
    required this.onRemind,
  });

  final ReferralInvite item;
  final int milestoneJobs;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = item.refereeDisplayName?.trim();
    final title = (name == null || name.isEmpty)
        ? ref.t('referral.invite_pending')
        : name;
    final remaining = (milestoneJobs - item.stepsCompleted).clamp(
      0,
      milestoneJobs,
    );

    return Container(
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: XpertTypography.label.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.serviceName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.serviceName!,
                        style: XpertTypography.caption.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Paid out is the only outcome worth a number on this card.
              if (item.isRewarded)
                Text(
                  '₹${item.rewardAmount.toStringAsFixed(0)}',
                  style: XpertTypography.metric.copyWith(
                    fontSize: 17,
                    color: XpertColors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: XpertSpacing.md),
          ReferralFunnel(status: item.status, lapsed: item.isLapsed),
          if (item.isActive && remaining > 0) ...[
            const SizedBox(height: XpertSpacing.md),
            Text(
              ref.t('referral.jobs_to_go', {
                'count': '$remaining',
                'amount': item.rewardAmount.toStringAsFixed(0),
              }),
              style: XpertTypography.caption.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: XpertColors.onSurface,
              ),
            ),
          ],
          if (item.isInvited || item.isSignedUp) ...[
            const SizedBox(height: XpertSpacing.sm),
            // A nudge, not a second primary action — the screen already has
            // one filled button and it is Invite a friend.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRemind,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: XpertSpacing.sm,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: XpertColors.primary,
                ),
                icon: const Icon(Icons.send_rounded, size: 15),
                label: Text(
                  ref.t('referral.remind'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
