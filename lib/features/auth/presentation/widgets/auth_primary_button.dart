import 'package:flutter/material.dart';

import '../../../../core/theme/xpert_tokens.dart';

/// The one filled control on an auth screen. Cyan on black text — the mark's
/// own contrast — with a trailing arrow that carries the forward lean.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled
            ? XpertColors.primary
            : XpertColors.primary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(XpertRadius.lg),
          child: SizedBox(
            width: double.infinity,
            height: 58,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: XpertColors.onPrimary,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: XpertSpacing.md,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // A long translation must shorten the label, never
                          // push the arrow off the button. Hindi and Marathi
                          // both run longer than the English here.
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: XpertTypography.button.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: XpertSpacing.sm),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: XpertColors.onPrimary,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
