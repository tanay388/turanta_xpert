import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/xpert_tokens.dart';

abstract final class XpertTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: XpertColors.primary,
        onPrimary: XpertColors.onPrimary,
        secondary: XpertColors.secondary,
        onSecondary: XpertColors.onSecondary,
        surface: XpertColors.surface,
        onSurface: XpertColors.onSurface,
        error: XpertColors.danger,
      ),
      scaffoldBackgroundColor: XpertColors.background,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: XpertColors.surface,
        foregroundColor: XpertColors.onSurface,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: XpertColors.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: XpertColors.primary,
          foregroundColor: XpertColors.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(XpertRadius.md),
          ),
          textStyle: XpertTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: XpertColors.onSurface,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: XpertColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(XpertRadius.md),
          ),
          textStyle: XpertTypography.button.copyWith(
            color: XpertColors.onSurface,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: XpertColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: XpertSpacing.md,
          vertical: XpertSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XpertRadius.md),
          borderSide: const BorderSide(color: XpertColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XpertRadius.md),
          borderSide: const BorderSide(color: XpertColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XpertRadius.md),
          borderSide: const BorderSide(color: XpertColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XpertRadius.md),
          borderSide: const BorderSide(color: XpertColors.danger),
        ),
      ),
    );
  }
}
