import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/earning_models.dart';

/// Small coloured pill for a payout cycle status.
class PayoutStatusChip extends ConsumerWidget {
  const PayoutStatusChip({super.key, required this.status});
  final PayoutStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, key) = switch (status) {
      PayoutStatus.accruing => (XpertColors.primary, 'paisa.status.accruing'),
      PayoutStatus.pending => (
          const Color(0xFFF5A623),
          'paisa.status.pending',
        ),
      PayoutStatus.paid => (XpertColors.success, 'paisa.status.paid'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(XpertRadius.pill),
      ),
      child: Text(
        ref.t(key),
        style: XpertTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
