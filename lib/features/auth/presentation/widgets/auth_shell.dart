import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/xpert_tokens.dart';
import 'xpert_mark.dart';

/// The Xpert who greets you. Missing is survivable — the canvas still reads.
const _heroArt = 'assets/images/auth_hero.png';

/// One duration for everything that moves when the keyboard does, so the art,
/// the mark and the card travel together instead of racing each other.
const _motion = Duration(milliseconds: 260);

/// How far she sinks on her way out.
const _artExit = 48.0;

/// Lets a test watch her fade rather than guess at it.
const heroFadeKey = ValueKey('auth-hero-fade');

/// The auth layout: an Xpert on an ink canvas, the form on a card over her.
///
/// The old screen was a pale wash with a small mark adrift in it above a plain
/// white sheet — two empty halves and nothing to look at. This one has a
/// subject: she is large, lit from behind, and bleeds off the right edge, and
/// the form sits on top of her rather than beside her, so the screen has depth
/// instead of two stacked rectangles.
///
/// Sign-in and the code step share this frame exactly, so moving between them
/// reads as the same card carrying on.
class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.child});

  /// Card content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final hasKeyboard = keyboardInset > 0;
    final size = MediaQuery.sizeOf(context);

    // She is the screen. The art is 4:3, so width is what limits her — she
    // is drawn wider than the phone and bleeds off both sides, which is what
    // makes her read as a subject rather than a sticker on a field.
    final artWidth = size.width * 1.24;

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
            const _CanvasBackdrop(),
            // She makes way for the keyboard by stepping back — fading and
            // sinking a little — rather than being deleted from the tree
            // between one frame and the next.
            AnimatedPositioned(
              duration: _motion,
              curve: hasKeyboard ? Curves.easeInCubic : Curves.easeOutCubic,
              left: -(artWidth - size.width) / 2,
              width: artWidth,
              // Her feet stop just above the card, so she stands on it rather
              // than hiding behind it.
              bottom: hasKeyboard
                  ? size.height * 0.33 - _artExit
                  : size.height * 0.33,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  key: heroFadeKey,
                  duration: _motion,
                  curve: Curves.easeOut,
                  opacity: hasKeyboard ? 0 : 1,
                  child: AnimatedScale(
                    duration: _motion,
                    curve: Curves.easeOutCubic,
                    scale: hasKeyboard ? 0.94 : 1,
                    alignment: Alignment.bottomCenter,
                    child: Image.asset(
                      _heroArt,
                      width: artWidth,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
            // The ink comes back up to meet the card, so her legs do not end
            // in a hard line against it.
            IgnorePointer(
              child: AnimatedOpacity(
                duration: _motion,
                curve: Curves.easeOut,
                opacity: hasKeyboard ? 0 : 1,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x000B1720),
                        Color(0x990B1720),
                        Color(0xFF0B1720),
                      ],
                      stops: [0.5, 0.72, 0.88],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: _motion,
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              top: 0,
              bottom: keyboardInset,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // With the keyboard up she is gone and the canvas is
                    // empty, so the mark takes the room instead of being
                    // stranded at the top of nothing: it slides to the middle
                    // and grows, then goes back when she returns.
                    Expanded(
                      child: AnimatedAlign(
                        duration: _motion,
                        curve: Curves.easeOutCubic,
                        alignment: hasKeyboard
                            ? Alignment.center
                            : Alignment.topCenter,
                        child: AnimatedPadding(
                          duration: _motion,
                          curve: Curves.easeOutCubic,
                          // Clear of the notch, and read as placed rather than
                          // pinned to the top edge.
                          padding: EdgeInsets.fromLTRB(
                            XpertSpacing.lg,
                            hasKeyboard ? 0 : XpertSpacing.xxl,
                            XpertSpacing.lg,
                            0,
                          ),
                          // Scaled rather than rebuilt at a new size: the mark
                          // animates its own entrance, and a size change would
                          // restart it every time the keyboard moves.
                          child: AnimatedScale(
                            duration: _motion,
                            curve: Curves.easeOutCubic,
                            scale: hasKeyboard ? 1.5 : 1,
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: XpertMarkLockup(
                                markSize: 44,
                                onDark: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Capped rather than flexible: a Flexible card would split
                    // the free space with the Spacer above it and float in the
                    // middle. This lets it take what it needs and hands the
                    // overflow to its own scroll view on a short screen.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                            (size.height -
                                    keyboardInset -
                                    MediaQuery.paddingOf(context).top -
                                    120)
                                .clamp(160.0, size.height),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          XpertSpacing.md,
                          XpertSpacing.lg,
                          XpertSpacing.md,
                          XpertSpacing.md,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: XpertColors.surface,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 34,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(XpertSpacing.lg),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ink, with the brand cyan glowing behind where she stands.
class _CanvasBackdrop extends StatelessWidget {
  const _CanvasBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1720), Color(0xFF10324A), Color(0xFF0B1720)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.5, -0.3),
            radius: 0.95,
            colors: [Color(0x3D00CCFF), Color(0x0000CCFF)],
          ),
        ),
      ),
    );
  }
}
