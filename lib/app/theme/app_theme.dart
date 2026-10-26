import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/shadows.dart';
import '../../core/theme/typography.dart';

abstract final class GPAppTheme {
  static ThemeData light() => _build(colors: const GPColors.light(), shadows: const GPShadows.light());

  static ThemeData dark() => _build(colors: const GPColors.dark(), shadows: const GPShadows.dark());

  static ThemeData _build({required GPColors colors, required GPShadows shadows}) {
    const typography = GPTypography.standard();
    const spacing = GPSpacing.standard();
    const radii = GPRadii.standard();

    final base = ThemeData(
      brightness: colors.brightness,
      colorScheme: colors.toColorScheme(),
      textTheme: typography.toTextTheme(),
      scaffoldBackgroundColor: colors.background,
      fontFamily: typography.bodyMedium.fontFamily,
      splashFactory: NoSplash.splashFactory,
    );

    return base.copyWith(
      extensions: [colors, typography, spacing, radii, shadows],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.onBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0.0,
        scrolledUnderElevation: 0.0,
        centerTitle: false,
        titleTextStyle: typography.headlineMedium.copyWith(color: colors.onBackground),
      ),
      dividerTheme: DividerThemeData(color: colors.outlineVariant, thickness: 1.0, space: 1.0),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0.0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radii.borderLg),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.primary,
        contentTextStyle: typography.bodyMedium.copyWith(color: colors.onPrimary),
        actionTextColor: colors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radii.borderMd),
      ),
    );
  }
}
