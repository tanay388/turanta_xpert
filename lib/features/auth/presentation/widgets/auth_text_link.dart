import 'package:flutter/material.dart';

import '../../../../core/theme/xpert_tokens.dart';

/// A secondary action on the sheet — reveal the referral field, resend a code.
/// Cyan and bold so it reads as tappable, but flat, so it never competes with
/// the one filled button.
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(XpertRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: XpertSpacing.sm,
          vertical: XpertSpacing.xs,
        ),
        child: Text(
          label,
          style: XpertTypography.caption.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: XpertColors.primary,
          ),
        ),
      ),
    );
  }
}
