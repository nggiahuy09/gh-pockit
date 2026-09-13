import 'package:flutter/material.dart';
import 'package:ghpockit/core/theme/tokens/colors.dart';

/// Semantic color roles, as a [ThemeExtension].
///
/// Widgets read these through `context.colors`; they never touch [GPColorTokens]. That indirection is the whole design system: a role says what a
/// color is *for*, so swapping the palette is one file and not a grep.
///
/// Roles come in `x` / `onX` pairs — a fill and the content legible on it. Every pair is checked against WCAG AA in
/// `test/core/theme/contrast_test.dart`, so picking a prettier hue that fails contrast breaks the build rather than shipping.
@immutable
class GPColors extends ThemeExtension<GPColors> {
  const GPColors({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.accentInk,
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.onSurface,
    required this.surfaceVariant,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.onDanger,
    required this.income,
    required this.expense,
  });

  const GPColors.light()
    : brightness = Brightness.light,
      primary = GPColorTokens.ink,
      onPrimary = GPColorTokens.ivory50,
      primaryContainer = GPColorTokens.ivory200,
      onPrimaryContainer = GPColorTokens.ink,
      accent = GPColorTokens.clay500,
      onAccent = GPColorTokens.ink,
      accentContainer = GPColorTokens.clay100,
      onAccentContainer = GPColorTokens.clay800,
      accentInk = GPColorTokens.clay700,
      background = GPColorTokens.ivory50,
      onBackground = GPColorTokens.ink,
      surface = GPColorTokens.white,
      onSurface = GPColorTokens.ink,
      surfaceVariant = GPColorTokens.ivory200,
      onSurfaceVariant = GPColorTokens.warmGrey600,
      outline = GPColorTokens.warmGrey300,
      outlineVariant = GPColorTokens.warmGrey200,
      success = GPColorTokens.green600,
      onSuccess = GPColorTokens.ivory50,
      warning = GPColorTokens.amber500,
      onWarning = GPColorTokens.ink,
      danger = GPColorTokens.red500,
      onDanger = GPColorTokens.ivory50,
      income = GPColorTokens.green600,
      expense = GPColorTokens.red500;

  const GPColors.dark()
    : brightness = Brightness.dark,
      primary = GPColorTokens.paper,
      onPrimary = GPColorTokens.warmGrey950,
      primaryContainer = GPColorTokens.warmGrey700,
      onPrimaryContainer = GPColorTokens.paper,
      accent = GPColorTokens.clay400,
      onAccent = GPColorTokens.warmGrey950,
      accentContainer = GPColorTokens.clay900,
      onAccentContainer = GPColorTokens.clay400,
      accentInk = GPColorTokens.clay400,
      background = GPColorTokens.warmGrey900,
      onBackground = GPColorTokens.paper,
      surface = GPColorTokens.warmGrey800,
      onSurface = GPColorTokens.paper,
      surfaceVariant = GPColorTokens.warmGrey750,
      onSurfaceVariant = GPColorTokens.warmGrey400,
      outline = GPColorTokens.warmGrey700,
      outlineVariant = GPColorTokens.warmGrey750,
      success = GPColorTokens.green400,
      onSuccess = GPColorTokens.warmGrey950,
      warning = GPColorTokens.amber400,
      onWarning = GPColorTokens.warmGrey950,
      danger = GPColorTokens.red400,
      onDanger = GPColorTokens.warmGrey950,
      income = GPColorTokens.green400,
      expense = GPColorTokens.red400;

  final Brightness brightness;

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color accent;
  final Color onAccent;
  final Color accentContainer;
  final Color onAccentContainer;
  final Color accentInk;
  final Color background;
  final Color onBackground;
  final Color surface;
  final Color onSurface;
  final Color surfaceVariant;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color danger;
  final Color onDanger;
  final Color income;
  final Color expense;

  ColorScheme toColorScheme() => ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: accent,
    onSecondary: onAccent,
    secondaryContainer: accentContainer,
    onSecondaryContainer: onAccentContainer,
    error: danger,
    onError: onDanger,
    surface: surface,
    onSurface: onSurface,
    surfaceContainerHighest: surfaceVariant,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
  );

  @override
  GPColors copyWith({
    Brightness? brightness,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? accent,
    Color? onAccent,
    Color? accentContainer,
    Color? onAccentContainer,
    Color? accentInk,
    Color? background,
    Color? onBackground,
    Color? surface,
    Color? onSurface,
    Color? surfaceVariant,
    Color? onSurfaceVariant,
    Color? outline,
    Color? outlineVariant,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? danger,
    Color? onDanger,
    Color? income,
    Color? expense,
  }) => GPColors(
    brightness: brightness ?? this.brightness,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    primaryContainer: primaryContainer ?? this.primaryContainer,
    onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    accentContainer: accentContainer ?? this.accentContainer,
    onAccentContainer: onAccentContainer ?? this.onAccentContainer,
    accentInk: accentInk ?? this.accentInk,
    background: background ?? this.background,
    onBackground: onBackground ?? this.onBackground,
    surface: surface ?? this.surface,
    onSurface: onSurface ?? this.onSurface,
    surfaceVariant: surfaceVariant ?? this.surfaceVariant,
    onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
    outline: outline ?? this.outline,
    outlineVariant: outlineVariant ?? this.outlineVariant,
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    danger: danger ?? this.danger,
    onDanger: onDanger ?? this.onDanger,
    income: income ?? this.income,
    expense: expense ?? this.expense,
  );

  @override
  GPColors lerp(ThemeExtension<GPColors>? other, double t) {
    if (other is! GPColors) return this;

    return GPColors(
      // Brightness is a mode, not a value: half a Brightness does not exist, so it flips at the midpoint instead of interpolating.
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t)!,
      onPrimaryContainer: Color.lerp(onPrimaryContainer, other.onPrimaryContainer, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
      onAccentContainer: Color.lerp(onAccentContainer, other.onAccentContainer, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      background: Color.lerp(background, other.background, t)!,
      onBackground: Color.lerp(onBackground, other.onBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      onSurfaceVariant: Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
    );
  }
}
