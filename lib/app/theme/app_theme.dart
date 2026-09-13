import 'package:flutter/material.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/core/theme/dimensions.dart';
import 'package:ghpockit/core/theme/shadows.dart';
import 'package:ghpockit/core/theme/typography.dart';

abstract final class GPAppTheme {
  /// The light theme.
  static ThemeData light() => _build(colors: const GPColors.light(), shadows: const GPShadows.light());

  /// The dark theme.
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
      extensions: <ThemeExtension<dynamic>>[colors, typography, spacing, radii, shadows],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.onBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: typography.headlineMedium.copyWith(color: colors.onBackground),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.accentContainer,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(typography.labelMedium.copyWith(color: colors.onSurfaceVariant)),
        iconTheme: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => IconThemeData(size: 24, color: states.contains(WidgetState.selected) ? colors.onAccentContainer : colors.onSurfaceVariant),
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.outlineVariant, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
