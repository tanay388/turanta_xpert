import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/xpert_tokens.dart';

/// The four-digit code the customer reads out to start or finish a job.
///
/// It used to be one boxed `TextField` with letter-spacing faking the gaps —
/// which meant the app had two different-looking OTP entries, this one and the
/// sign-in screen's. Same four cells here, so a partner who has entered one
/// already knows what this is.
class JobOtpField extends StatefulWidget {
  const JobOtpField({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.enabled = true,
    this.hasError = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final bool enabled;
  final bool hasError;

  static const length = 4;

  @override
  State<JobOtpField> createState() => _JobOtpFieldState();
}

class _JobOtpFieldState extends State<JobOtpField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;

    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: widget.enabled ? _focus.requestFocus : null,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < JobOtpField.length; i++) ...[
                if (i > 0) const SizedBox(width: XpertSpacing.sm),
                _Cell(
                  digit: i < code.length ? code[i] : '',
                  focused: _focus.hasFocus && i == code.length,
                  hasError: widget.hasError,
                ),
              ],
            ],
          ),
        ),
        Opacity(
          opacity: 0,
          child: SizedBox(
            width: 4 * 52.0 + 3 * XpertSpacing.sm,
            height: 58,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              showCursor: false,
              enableSuggestions: false,
              autocorrect: false,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(JobOtpField.length),
              ],
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                if (value.length == JobOtpField.length) {
                  widget.onCompleted(value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.digit,
    required this.focused,
    required this.hasError,
  });

  final String digit;
  final bool focused;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final filled = digit.isNotEmpty;
    final border = hasError
        ? XpertColors.danger
        : focused
        ? XpertColors.primary
        : filled
        ? const Color(0xFFC9D6DE)
        : const Color(0xFFE3EAEF);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 52,
      height: 58,
      decoration: BoxDecoration(
        color: filled ? XpertColors.surface : const Color(0xFFF6F9FB),
        borderRadius: BorderRadius.circular(XpertRadius.md),
        border: Border.all(color: border, width: focused ? 2 : 1.2),
      ),
      alignment: Alignment.center,
      child: filled
          ? Text(
              digit,
              style: XpertTypography.metric.copyWith(fontSize: 24),
            )
          : focused
          ? Container(
              width: 2,
              height: 22,
              decoration: BoxDecoration(
                color: XpertColors.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
