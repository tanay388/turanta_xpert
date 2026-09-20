import 'package:flutter/material.dart';

import '../../../../core/theme/xpert_tokens.dart';

/// The Xpert logo. A square app icon with no alpha, baked onto near-white —
/// so it is shown the way an app icon is meant to be shown, clipped to a
/// rounded tile, rather than bled into the canvas.
const _markAsset = 'assets/logo/turanta_xpert_app_logo.png';

class XpertMark extends StatelessWidget {
  const XpertMark({super.key, this.size = 68});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        // The tile's own field is near-white, so on the wash it needs a
        // darker hairline to read as an edge at all.
        border: Border.all(color: XpertColors.border.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        _markAsset,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// The tile and the wordmark, arriving together on the opening screen.
///
/// "Xpert" carries the accent: it is the only word that separates this app
/// from the customer one, and a partner installing both should be able to tell
/// which they opened before reading anything else.
class XpertMarkLockup extends StatefulWidget {
  const XpertMarkLockup({super.key, this.markSize = 68, this.onDark = false});

  final double markSize;

  /// Flips the wordmark to white for the ink canvas.
  final bool onDark;

  @override
  State<XpertMarkLockup> createState() => _XpertMarkLockupState();
}

class _XpertMarkLockupState extends State<XpertMarkLockup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  late final Animation<double> _mark = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.8, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _wordmark = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.markSize * 0.38;

    return Semantics(
      label: 'Turanta Xpert',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Transform.translate(
                offset: Offset(-widget.markSize * 0.4 * (1 - _mark.value), 0),
                child: Opacity(
                  opacity: _mark.value,
                  child: XpertMark(size: widget.markSize),
                ),
              ),
              SizedBox(width: widget.markSize * 0.22),
              Opacity(
                opacity: _wordmark.value,
                child: Text.rich(
                  TextSpan(
                    text: 'Turanta ',
                    children: [
                      TextSpan(
                        text: 'Xpert',
                        style: TextStyle(
                          color: widget.onDark
                              ? XpertColors.primary
                              : XpertColors.heroAccent,
                        ),
                      ),
                    ],
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      height: 1,
                      color: widget.onDark
                          ? Colors.white
                          : XpertColors.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
