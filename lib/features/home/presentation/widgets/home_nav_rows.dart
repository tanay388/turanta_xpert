import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';

/// The two destinations that hang off home: attendance history and referrals.
///
/// They were two full-width cards, each as heavy as the job card above them,
/// each competing for the same attention. They are navigation, not content —
/// so they collapse into one grouped list, which is how navigation reads.
class HomeNavRows extends ConsumerWidget {
  const HomeNavRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _NavRow(
            icon: Icons.card_giftcard_rounded,
            iconColor: XpertColors.primary,
            title: ref.t('home.refer.title'),
            subtitle: ref.t('home.refer.subtitle'),
            onTap: () => context.push('/referral'),
          ),
          const Divider(height: 1, indent: 60, color: Color(0xFFE8EDF1)),
          _NavRow(
            icon: Icons.history_rounded,
            iconColor: XpertColors.muted,
            title: ref.t('home.attendance_history'),
            onTap: () => context.push('/attendance'),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: XpertSpacing.md,
          vertical: XpertSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(XpertRadius.sm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: XpertSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: XpertTypography.label.copyWith(fontSize: 14)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: XpertTypography.caption.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: XpertColors.border,
            ),
          ],
        ),
      ),
    );
  }
}
