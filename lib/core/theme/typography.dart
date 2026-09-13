import 'package:flutter/material.dart';
import 'package:ghpockit/core/theme/tokens/typography.dart';

/// Semantic text styles, as a [ThemeExtension].
///
/// Read through `context.text`. Fifteen roles, matching Material's names so [toTextTheme] can hand them straight to built-in widgets — but sized for
/// a phone rather than for Material's defaults.
///
/// Styles carry no color. Color comes from the enclosing `DefaultTextStyle` or from an explicit `context.colors.*`, because the same role renders in
/// three different colors depending on what it sits on, and baking one in would mean fifteen more roles.
///
/// Money is not a role here. It arrives in W3 with `Money` and `MoneyFormatter`, and it needs a tabular-figures font feature so digits do not shift
/// width as an amount changes — a decision that belongs with the value object, not ahead of it.
@immutable
class GPTypography extends ThemeExtension<GPTypography> {
  const GPTypography({
    required this.displayLarge,
    required this.displayMedium,
    required this.displaySmall,
    required this.headlineLarge,
    required this.headlineMedium,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
  });

  const GPTypography.standard()
    : displayLarge = const TextStyle(
        fontFamily: GPTypographyTokens.fontFamily,
        fontSize: GPTypographyTokens.sizeDisplayLarge,
        fontWeight: GPTypographyTokens.bold,
        height: GPTypographyTokens.heightTight,
        letterSpacing: GPTypographyTokens.trackingDisplay,
      ),
      displayMedium = const TextStyle(
        fontFamily: GPTypographyTokens.fontFamily,
        fontSize: GPTypographyTokens.sizeDisplayMedium,
        fontWeight: GPTypographyTokens.bold,
        height: GPTypographyTokens.heightTight,
        letterSpacing: GPTypographyTokens.trackingDisplay,
      ),
      displaySmall = const TextStyle(
        fontFamily: GPTypographyTokens.fontFamily,
        fontSize: GPTypographyTokens.sizeDisplaySmall,
        fontWeight: GPTypographyTokens.semiBold,
        height: GPTypographyTokens.heightTight,
        letterSpacing: GPTypographyTokens.trackingDisplay,
      ),
      headlineLarge = const TextStyle(
        fontFamily: GPTypographyTokens.fontFamily,
        fontSize: GPTypographyTokens.sizeHeadlineLarge,
        fontWeight: GPTypographyTokens.semiBold,
        height: GPTypographyTokens.heightSnug,
        letterSpacing: GPTypographyTokens.trackingHeadline,
      ),
      headlineMedium = const TextStyle(
        fontFamily: GPTypographyTokens.fontFamily,
        fontSize: GPTypographyTokens.sizeHeadlineMedium,
        fontWeight: GPTypographyTokens.semiBold,
        height: GPTypographyTokens.heightSnug,
        letterSpacing: GPTypographyTokens.trackingHeadline,
      ),
      headlineSmall = const TextStyle(
        fontFamily: GPTypographyTokens.fontFamily,
        fontSize: GPTypographyTokens.sizeHeadlineSmall,
        fontWeight: GPTypographyTokens.semiBold,
        height: GPTypographyTokens.heightSnug,
        letterSpacing: GPTypographyTokens.trackingHeadline,
      ),
      titleLarge = const TextStyle(
        fontFamily: GPTypographyTokens.fontFamily,
        fontSize: GPTypographyTokens.sizeTitleLarge,
        fontWeight: GPTypographyTokens.semiBold,
        height: GPTypographyTokens.heightSnug,
        letterSpacing: GPTypographyTokens.trackingHeadline,
      ),
      titleMedium = const TextStyle(
        fontFamily: GPTypographyTokens.fontFamily,
        fontSize: GPTypographyTokens.sizeTitleMedium,
        fontWeight: GPTypographyTokens.medium,
        height: GPTypographyTokens.heightSnug,
        letterSpacing: GPTypographyTokens.trackingHeadline,
      ),
      titleSmall = const TextStyle(
        fontFamily: GPTypographyTokens.fontFamily,
        fontSize: GPTypographyTokens.sizeTitleSmall,
        fontWeight: GPTypographyTokens.medium,
        height: GPTypographyTokens.heightSnug,
        letterSpacing: GPTypographyTokens.trackingHeadline,
      ),
      bodyLarge = const TextStyle(
        fontFamily: GPTypographyTokens.fontFamily,
        fontSize: GPTypographyTokens.sizeBodyLarge,
        fontWeight: GPTypographyTokens.regular,
        height: GPTypographyTokens.heightRelaxed,
        letterSpacing: GPTypographyTokens.trackingBody,
      ),
      bodyMedium = const TextStyle(
        fontFamily: GPTypographyTokens.fontFamily,
        fontSize: GPTypographyTokens.sizeBodyMedium,
        fontWeight: GPTypographyTokens.regular,
        height: GPTypographyTokens.heightRelaxed,
        letterSpacing: GPTypographyTokens.trackingBody,
      ),
      bodySmall = const TextStyle(
        fontFamily: GPTypographyTokens.fontFamily,
        fontSize: GPTypographyTokens.sizeBodySmall,
        fontWeight: GPTypographyTokens.regular,
        height: GPTypographyTokens.heightRelaxed,
        letterSpacing: GPTypographyTokens.trackingBody,
      ),
      labelLarge = const TextStyle(
        fontFamily: GPTypographyTokens.fontFamily,
        fontSize: GPTypographyTokens.sizeLabelLarge,
        fontWeight: GPTypographyTokens.medium,
        height: GPTypographyTokens.heightLabel,
        letterSpacing: GPTypographyTokens.trackingLabel,
      ),
      labelMedium = const TextStyle(
        fontFamily: GPTypographyTokens.fontFamily,
        fontSize: GPTypographyTokens.sizeLabelMedium,
        fontWeight: GPTypographyTokens.medium,
        height: GPTypographyTokens.heightLabel,
        letterSpacing: GPTypographyTokens.trackingLabel,
      ),
      labelSmall = const TextStyle(
        fontFamily: GPTypographyTokens.fontFamily,
        fontSize: GPTypographyTokens.sizeLabelSmall,
        fontWeight: GPTypographyTokens.medium,
        height: GPTypographyTokens.heightLabel,
        letterSpacing: GPTypographyTokens.trackingLabel,
      );

  /// The account balance on the dashboard. The one genuinely large number in the app.
  final TextStyle displayLarge;

  /// A month total.
  final TextStyle displayMedium;

  /// A large screen header.
  final TextStyle displaySmall;

  /// A screen title.
  final TextStyle headlineLarge;

  /// The app-bar title.
  final TextStyle headlineMedium;

  /// A section header.
  final TextStyle headlineSmall;

  /// A card title.
  final TextStyle titleLarge;

  /// A list-item title, and the button label.
  final TextStyle titleMedium;

  /// A dense list-item title.
  final TextStyle titleSmall;

  /// Body copy that carries a screen — an empty-state paragraph, a dialog body.
  final TextStyle bodyLarge;

  /// The default. Most text in the app is this.
  final TextStyle bodyMedium;

  /// Supporting text under a list item.
  final TextStyle bodySmall;

  /// A field label.
  final TextStyle labelLarge;

  /// A date header, a chip, a badge.
  final TextStyle labelMedium;

  /// The smallest text allowed. Below this Inter stops being legible on a low-DPI Android panel.
  final TextStyle labelSmall;

  /// Builds a Material [TextTheme] so built-in widgets inherit the same scale.
  TextTheme toTextTheme() => TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );

  @override
  GPTypography copyWith({
    TextStyle? displayLarge,
    TextStyle? displayMedium,
    TextStyle? displaySmall,
    TextStyle? headlineLarge,
    TextStyle? headlineMedium,
    TextStyle? headlineSmall,
    TextStyle? titleLarge,
    TextStyle? titleMedium,
    TextStyle? titleSmall,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? labelLarge,
    TextStyle? labelMedium,
    TextStyle? labelSmall,
  }) => GPTypography(
    displayLarge: displayLarge ?? this.displayLarge,
    displayMedium: displayMedium ?? this.displayMedium,
    displaySmall: displaySmall ?? this.displaySmall,
    headlineLarge: headlineLarge ?? this.headlineLarge,
    headlineMedium: headlineMedium ?? this.headlineMedium,
    headlineSmall: headlineSmall ?? this.headlineSmall,
    titleLarge: titleLarge ?? this.titleLarge,
    titleMedium: titleMedium ?? this.titleMedium,
    titleSmall: titleSmall ?? this.titleSmall,
    bodyLarge: bodyLarge ?? this.bodyLarge,
    bodyMedium: bodyMedium ?? this.bodyMedium,
    bodySmall: bodySmall ?? this.bodySmall,
    labelLarge: labelLarge ?? this.labelLarge,
    labelMedium: labelMedium ?? this.labelMedium,
    labelSmall: labelSmall ?? this.labelSmall,
  );

  @override
  GPTypography lerp(ThemeExtension<GPTypography>? other, double t) {
    if (other is! GPTypography) return this;

    return GPTypography(
      displayLarge: TextStyle.lerp(displayLarge, other.displayLarge, t)!,
      displayMedium: TextStyle.lerp(displayMedium, other.displayMedium, t)!,
      displaySmall: TextStyle.lerp(displaySmall, other.displaySmall, t)!,
      headlineLarge: TextStyle.lerp(headlineLarge, other.headlineLarge, t)!,
      headlineMedium: TextStyle.lerp(headlineMedium, other.headlineMedium, t)!,
      headlineSmall: TextStyle.lerp(headlineSmall, other.headlineSmall, t)!,
      titleLarge: TextStyle.lerp(titleLarge, other.titleLarge, t)!,
      titleMedium: TextStyle.lerp(titleMedium, other.titleMedium, t)!,
      titleSmall: TextStyle.lerp(titleSmall, other.titleSmall, t)!,
      bodyLarge: TextStyle.lerp(bodyLarge, other.bodyLarge, t)!,
      bodyMedium: TextStyle.lerp(bodyMedium, other.bodyMedium, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
      labelLarge: TextStyle.lerp(labelLarge, other.labelLarge, t)!,
      labelMedium: TextStyle.lerp(labelMedium, other.labelMedium, t)!,
      labelSmall: TextStyle.lerp(labelSmall, other.labelSmall, t)!,
    );
  }
}
