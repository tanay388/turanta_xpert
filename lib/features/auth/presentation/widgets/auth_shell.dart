import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/xpert_tokens.dart';
import 'xpert_mark.dart';

/// The auth layout: a dark canvas carrying the mark, a white sheet below
/// carrying the work.
///
/// The shell owns keyboard behaviour so screens don't hand-compensate: the
/// canvas stays full-bleed while the foreground is confined above the
/// keyboard, so the sheet rises instead of being covered. The old screens
/// padded themselves by `viewInsets.bottom`, which pushed content up but left
/// the layout fighting for the same shrinking column.
class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.child, this.headline});

  /// Sheet content.
  final Widget child;

  /// One line under the mark. Omitted on screens that are mid-flow.
  final Widget? headline;

  /// Share of the available height the sheet takes. It grows once the keyboard
  /// is up, because the same fields then have to fit in a much shorter space.
  static const _sheetFlex = 60;
  static const _sheetFlexWithKeyboard = 80;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final hasKeyboard = keyboardInset > 0;
    final sheetFlex = hasKeyboard ? _sheetFlexWithKeyboard : _sheetFlex;

    // Dark canvas, no AppBar — nothing else would tell the system to draw
    // light status-bar icons, and the theme's default is dark-on-light.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: XpertColors.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: XpertColors.canvas),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              top: 0,
              bottom: keyboardInset,
              child: Column(
                children: [
                  Expanded(
                    flex: 100 - sheetFlex,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          XpertSpacing.lg,
                          XpertSpacing.md,
                          XpertSpacing.lg,
                          hasKeyboard ? XpertSpacing.sm : XpertSpacing.lg,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Only the mark goes in the FittedBox. A FittedBox
                            // hands its child unbounded width, so text inside one
                            // never wraps — it just gets scaled down, dragging
                            // the mark with it. The headline stays outside where
                            // it has a real width to wrap against.
                            //
                            // Once the keyboard is up the mark has said its piece
                            // and the field is the job, so it steps down rather
                            // than competing for what height is left.
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.bottomLeft,
                                child: XpertMarkLockup(
                                  markSize: hasKeyboard ? 44 : 68,
                                ),
                              ),
                            ),
                            if (headline != null && !hasKeyboard) ...[
                              const SizedBox(height: XpertSpacing.lg),
                              headline!,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: sheetFlex,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: XpertColors.surface,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(XpertRadius.sheetTop),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          XpertSpacing.lg,
                          XpertSpacing.xl,
                          XpertSpacing.lg,
                          XpertSpacing.lg,
                        ),
                        child: SafeArea(top: false, child: child),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
