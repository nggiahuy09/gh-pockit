import 'package:flutter/material.dart';
import 'package:ghpockit/core/theme/tokens/typography.dart';

/// Styles carry no color: it comes from the enclosing `DefaultTextStyle` or an explicit `context.colors`.
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

  final TextStyle displayLarge;
  final TextStyle displayMedium;
  final TextStyle displaySmall;
  final TextStyle headlineLarge;
  final TextStyle headlineMedium;
  final TextStyle headlineSmall;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle titleSmall;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle labelLarge;
  final TextStyle labelMedium;
  final TextStyle labelSmall;

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
