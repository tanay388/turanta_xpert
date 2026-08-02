import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/xpert_tokens.dart';

/// A single field, styled to be obvious rather than decorative: a quiet
/// resting state, a cyan ring on focus so the tap target confirms itself, and
/// a red ring plus a line of plain text when it's wrong.
///
/// The app's global [InputDecoration] theme is deliberately not used here —
/// the auth screens are the only place a partner is not yet signed in, and the
/// field needs to be readable at arm's length in a stairwell.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.focusNode,
    this.errorText,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onSubmitted,
    this.prefix,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final String? errorText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefix;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  FocusNode? _ownedNode;
  bool _focused = false;

  FocusNode get _node => widget.focusNode ?? (_ownedNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    _ownedNode?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _node.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.errorText;
    final hasError = error != null && error.isNotEmpty;
    final ringColor = hasError
        ? XpertColors.danger
        : _focused
        ? XpertColors.primary
        : const Color(0xFFDCE4EA);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: XpertTypography.eyebrow.copyWith(
            color: XpertColors.muted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: XpertSpacing.sm),
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 58,
          decoration: BoxDecoration(
            color: _focused || hasError
                ? XpertColors.surface
                : const Color(0xFFF6F9FB),
            borderRadius: BorderRadius.circular(XpertRadius.lg),
            border: Border.all(color: ringColor, width: _focused ? 2 : 1.2),
          ),
          child: Row(
            children: [
              if (widget.prefix != null) ...[
                widget.prefix!,
                Container(width: 1, height: 26, color: const Color(0xFFDCE4EA)),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _node,
                  enabled: widget.enabled,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  textCapitalization: widget.textCapitalization,
                  inputFormatters: widget.inputFormatters,
                  onSubmitted: widget.onSubmitted,
                  cursorColor: XpertColors.primary,
                  style: XpertTypography.body.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: XpertTypography.body.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                      color: const Color(0xFFA8B6C0),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: XpertSpacing.md,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: XpertSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 15,
                  color: XpertColors.danger,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    error,
                    style: XpertTypography.caption.copyWith(
                      color: XpertColors.danger,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class AuthPhonePrefix extends StatelessWidget {
  const AuthPhonePrefix({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: XpertSpacing.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🇮🇳', style: TextStyle(fontSize: 19)),
          SizedBox(width: XpertSpacing.xs),
          Text(
            '+91',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: XpertColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
