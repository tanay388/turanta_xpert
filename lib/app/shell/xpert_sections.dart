import 'package:flutter/material.dart';

import '../../core/theme/xpert_tokens.dart';

/// One tracked-out line above a block of content.
///
/// Sections used to be told apart only by a gap, which is not a hierarchy.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;

  /// A count or a link, set small and quiet so the label still leads.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text.toUpperCase(),
      style: XpertTypography.eyebrow.copyWith(
        color: XpertColors.muted,
        letterSpacing: 1.2,
      ),
    );

    if (trailing == null) return label;
    return Row(
      children: [
        Expanded(child: label),
        trailing!,
      ],
    );
  }
}

/// An empty screen is an invitation, not a dead end — so it says what will
/// appear here and what to do about it, rather than just that there is nothing.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // A Column, not a ListView: this is dropped inside lists that already
    // scroll, and a viewport inside a viewport has unbounded height. Callers
    // that need pull-to-refresh over an empty screen wrap it themselves.
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: XpertSpacing.xl,
        vertical: XpertSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: XpertColors.secondary,
              borderRadius: BorderRadius.circular(XpertRadius.xl),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 30, color: XpertColors.primary),
          ),
        ),
        const SizedBox(height: XpertSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: XpertTypography.title.copyWith(fontSize: 18),
        ),
        const SizedBox(height: XpertSpacing.xs),
        Text(
          body,
          textAlign: TextAlign.center,
          style: XpertTypography.caption.copyWith(fontSize: 13.5, height: 1.45),
        ),
        if (action != null) ...[
          const SizedBox(height: XpertSpacing.lg),
          Center(child: action!),
        ],
        ],
      ),
    );
  }
}
