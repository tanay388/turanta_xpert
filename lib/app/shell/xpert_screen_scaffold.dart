import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/xpert_tokens.dart';

/// A dark header with optional pill tabs, and the rounded sheet that rises
/// over it.
///
/// The same join the sign-in screen and home make, so a partner moving between
/// tabs is not moving between two different apps. Tabs live on the canvas
/// rather than in the sheet: switching is navigation, and navigation belongs
/// with the title, not with the content it changes.
class XpertScreenScaffold extends StatelessWidget {
  const XpertScreenScaffold({
    super.key,
    required this.title,
    required this.child,
    this.tabs = const [],
    this.selectedTab = 0,
    this.onTabSelected,
    this.trailing,
    this.header,
  });

  final String title;
  final Widget child;
  final List<String> tabs;
  final int selectedTab;
  final ValueChanged<int>? onTabSelected;
  final Widget? trailing;

  /// Extra content on the dark field, under the title — for a screen whose
  /// subject belongs on the canvas rather than in the sheet.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: XpertColors.canvas,
        body: Column(
          children: [
            ColoredBox(
              color: XpertColors.canvas,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    XpertSpacing.lg,
                    XpertSpacing.md,
                    XpertSpacing.lg,
                    tabs.isEmpty && header == null
                        ? XpertSpacing.xl
                        : XpertSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: XpertTypography.display.copyWith(
                                fontSize: 24,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ?trailing,
                        ],
                      ),
                      ?header,
                      if (tabs.isNotEmpty) ...[
                        const SizedBox(height: XpertSpacing.md),
                        _PillTabs(
                          tabs: tabs,
                          selected: selectedTab,
                          onSelected: onTabSelected,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: XpertColors.background,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(XpertRadius.sheetTop),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillTabs extends StatelessWidget {
  const _PillTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: XpertColors.canvasSoft,
        borderRadius: BorderRadius.circular(XpertRadius.pill),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: GestureDetector(
                  onTap: () => onSelected?.call(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: i == selected
                          ? XpertColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(XpertRadius.pill),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tabs[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: i == selected
                            ? XpertColors.onPrimary
                            : XpertColors.onCanvasMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
