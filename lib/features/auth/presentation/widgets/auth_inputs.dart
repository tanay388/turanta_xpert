import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/xpert_tokens.dart';

/// The phone number, set at the size of the thing it is.
///
/// Not a labelled form field: this card asks one question, so the number is
/// the content rather than a value inside a row of inputs. The country code
/// sits in its own tile so the digits start where the eye lands.
class AuthPhoneField extends StatelessWidget {
  const AuthPhoneField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.enabled,
    required this.onSubmitted,
    this.errorText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool enabled;
  final VoidCallback onSubmitted;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: XpertColors.background,
            borderRadius: BorderRadius.circular(XpertRadius.lg),
            border: Border.all(
              color: hasError
                  ? XpertColors.danger
                  : focusNode.hasFocus
                  ? XpertColors.primaryDeep
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  XpertSpacing.md,
                  XpertSpacing.md,
                  XpertSpacing.sm,
                  XpertSpacing.md,
                ),
                child: Text(
                  '🇮🇳  +91',
                  style: XpertTypography.label.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 26,
                color: XpertColors.border.withValues(alpha: 0.5),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmitted(),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: XpertTypography.title.copyWith(
                    fontSize: 22,
                    letterSpacing: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: XpertTypography.title.copyWith(
                      fontSize: 22,
                      letterSpacing: 1.5,
                      color: XpertColors.disabled,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: XpertSpacing.md,
                      vertical: XpertSpacing.md,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: XpertSpacing.xs),
          Text(
            errorText!,
            style: XpertTypography.caption.copyWith(
              color: XpertColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Six digits, big enough to check at a glance against the SMS.
class AuthCodeField extends StatelessWidget {
  const AuthCodeField({
    super.key,
    required this.length,
    required this.code,
    required this.focusNode,
    required this.controller,
    required this.hasError,
    required this.onCompleted,
  });

  final int length;
  final String code;
  final FocusNode focusNode;
  final TextEditingController controller;
  final bool hasError;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final cell = ((constraints.maxWidth - gap * (length - 1)) / length)
            .clamp(38.0, 54.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: focusNode.requestFocus,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < length; i++)
                    _Cell(
                      size: cell,
                      digit: i < code.length ? code[i] : '',
                      active: focusNode.hasFocus && i == code.length,
                      hasError: hasError,
                    ),
                ],
              ),
            ),
            Opacity(
              opacity: 0,
              child: SizedBox(
                width: constraints.maxWidth,
                height: cell,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  enableSuggestions: false,
                  autocorrect: false,
                  showCursor: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(length),
                  ],
                  onChanged: (value) {
                    if (value.length == length) onCompleted();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.size,
    required this.digit,
    required this.active,
    required this.hasError,
  });

  final double size;
  final String digit;
  final bool active;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final filled = digit.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: size,
      height: size * 1.15,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? XpertColors.secondary : XpertColors.background,
        borderRadius: BorderRadius.circular(XpertRadius.md),
        border: Border.all(
          color: hasError
              ? XpertColors.danger
              : active
              ? XpertColors.primaryDeep
              : filled
              ? XpertColors.primary
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Text(
        digit,
        style: XpertTypography.title.copyWith(fontSize: 22, height: 1),
      ),
    );
  }
}

/// The one action on the card: a full-width pill that says what happens next.
class AuthCta extends StatelessWidget {
  const AuthCta({
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
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: XpertColors.primary,
          foregroundColor: XpertColors.onPrimary,
          disabledBackgroundColor: XpertColors.primary.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(XpertRadius.pill),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: XpertColors.onPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: XpertSpacing.xs),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
      ),
    );
  }
}
