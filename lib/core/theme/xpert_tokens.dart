import 'package:flutter/material.dart';

/// Turanta Xpert design tokens (standalone — no shared_ui_kit).
@immutable
class XpertColors {
  const XpertColors._();

  static const primary = Color(0xFF00CCFF);
  static const onPrimary = Color(0xFF000000);
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
  static const pill = 999.0;
}

@immutable
class XpertTypography {
  const XpertTypography._();

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
