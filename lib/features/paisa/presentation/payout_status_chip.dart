import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../data/earning_models.dart';

/// The colour and word for a payout's state, in one place so the chip, the
/// rail beside a row and the dot in a list never disagree.
(Color, String) payoutStatusLook(PayoutStatus status) => switch (status) {
  PayoutStatus.accruing => (XpertColors.heroAccent, 'paisa.status.accruing'),
  // Amber at 1.9:1 was unreadable as text; this is the same idea at 4.8:1.
  PayoutStatus.pending => (XpertColors.warning, 'paisa.status.pending'),
  PayoutStatus.paid => (XpertColors.success, 'paisa.status.paid'),
};

/// Small coloured pill for a payout cycle status.
class PayoutStatusChip extends ConsumerWidget {
  const PayoutStatusChip({super.key, required this.status});
  final PayoutStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, key) = payoutStatusLook(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(XpertRadius.pill),
      ),
      child: Text(
        ref.t(key),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }
}
