import 'package:flutter/material.dart';

/// Turanta Xpert design tokens (standalone — no shared_ui_kit).
@immutable
class XpertColors {
  const XpertColors._();

  static const primary = Color(0xFF00CCFF);

  /// The brand cyan darkened until it can carry meaning on a light background.
  ///
  /// [primary] is 1.8:1 on white — fine as a fill behind black text, unreadable
  /// as text or an icon on top of one. Anything small and cyan-coloured should
  /// use this instead; it is the same hue at 5:1.
  static const primaryDeep = Color(0xFF00799A);
  static const onPrimary = Color(0xFF000000);

  /// The auth canvas. Unlike the customer app — whose mark ships on its own
  /// black field and so dictates the backdrop — the Xpert logo is a square app
  /// icon baked onto near-white (#F8F8F8, no alpha). It is shown as a tile
  /// instead, which frees the canvas: this is the brand cyan taken down to
  /// something a partner reads at 6am, and it tells the two apps apart at a
  /// glance on a phone that has both.
  static const canvas = Color(0xFF0B1720);
  static const canvasSoft = Color(0xFF13222D);
  static const onCanvas = Color(0xFFF4F9FC);
  static const onCanvasMuted = Color(0xFF8CA3B2);

  static const secondary = Color(0xFFE6F9FF);
  static const onSecondary = Color(0xFF0A0A0A);
  static const surface = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF0A0A0A);
  static const background = Color(0xFFF2F5F8);
  static const border = Color(0xFFB0BEC5);
  static const muted = Color(0xFF455A64);
  static const danger = Color(0xFFD32F2F);
  static const success = Color(0xFF2E7D32);
  static const online = Color(0xFF1B8A4A);
  static const offline = Color(0xFF78909C);
  static const disabled = Color(0xFFB0BEC5);
}

@immutable
class XpertSpacing {
  const XpertSpacing._();

  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const xxl = 40.0;
}

@immutable
class XpertRadius {
  const XpertRadius._();

  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 18.0;
  static const xl = 28.0;
  static const sheetTop = 32.0;
  static const pill = 999.0;
}

@immutable
class XpertTypography {
  const XpertTypography._();

  /// Canvas-only styles. There is no bundled brand face — an auth screen that
  /// waits on a webfont would undercut the one thing the brand promises — so
  /// character comes from scale and tracking: a tight, heavy display against a
  /// wide, small eyebrow.
  static const display = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.9,
    color: XpertColors.onCanvas,
  );

  static const eyebrow = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 1.6,
    color: XpertColors.primary,
  );

  /// Numbers that change while you look at them — a running shift clock, the
  /// day's earnings. Tabular figures so digits keep their column and the value
  /// stops jittering as it ticks.
  static const metric = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1,
    letterSpacing: -0.8,
    color: XpertColors.onSurface,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: XpertColors.onSurface,
  );

  static const body = TextStyle(
    fontSize: 16,
    height: 1.45,
    color: XpertColors.onSurface,
  );

  static const label = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: XpertColors.onSurface,
  );

  static const caption = TextStyle(
    fontSize: 13,
    height: 1.35,
    color: XpertColors.muted,
  );

  static const button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: XpertColors.onPrimary,
  );
}
