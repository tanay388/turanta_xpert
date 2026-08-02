import 'package:flutter/material.dart';

import '../../core/theme/xpert_tokens.dart';

/// Rows collected into one rounded card, separated by hairlines.
///
/// Profile and Settings both used to stack individually bordered cards with a
/// gap between each, so four related facts read as four unrelated objects.
/// Grouping is what says they belong together — and it lets a row that is
/// navigation look different from a row that is a value.
class XpertListGroup extends StatelessWidget {
  const XpertListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 56, color: Color(0xFFEDF1F4)),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One row: an icon, a title, an optional second line, and whatever sits on
/// the right — a value, a switch, or a chevron.
class XpertListRow extends StatelessWidget {
  const XpertListRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.tone,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;

  /// A read-only value, set on the right in the same weight as the title so
  /// the pair reads as one fact rather than a label and an afterthought.
  final String? value;

  final Widget? trailing;
  final VoidCallback? onTap;

  /// Colours the icon and title. Used for the one destructive row.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final titleColor = tone ?? XpertColors.onSurface;

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: XpertSpacing.md,
        vertical: XpertSpacing.md,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: (tone ?? XpertColors.primary).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(XpertRadius.sm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: tone ?? XpertColors.primary),
            ),
            const SizedBox(width: XpertSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: XpertTypography.label.copyWith(
                    fontSize: 14.5,
                    color: titleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: XpertTypography.caption.copyWith(fontSize: 12),
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: XpertSpacing.sm),
            Flexible(
              child: Text(
                value!,
                textAlign: TextAlign.end,
                style: XpertTypography.label.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: XpertColors.muted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          ?trailing,
          if (onTap != null && trailing == null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: XpertColors.border,
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
