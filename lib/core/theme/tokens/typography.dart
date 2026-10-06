import 'dart:ui' show FontWeight;

/// Primitives; widgets read `context.text`.
abstract final class GPTypographyTokens {
  /// Bundled under `assets/fonts/` as a Latin + Vietnamese subset that `font_coverage_test.dart` guards (ADR-0008).
  static const String fontFamily = 'Inter';

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  static const double sizeDisplayLarge = 40;
  static const double sizeDisplayMedium = 32;
  static const double sizeDisplaySmall = 28;
  static const double sizeHeadlineLarge = 24;
  static const double sizeHeadlineMedium = 22;
  static const double sizeHeadlineSmall = 20;
  static const double sizeTitleLarge = 18;
  static const double sizeTitleMedium = 16;
  static const double sizeTitleSmall = 14;
  static const double sizeBodyLarge = 16;
  static const double sizeBodyMedium = 14;
  static const double sizeBodySmall = 13;
  static const double sizeLabelLarge = 14;
  static const double sizeLabelMedium = 12;

  /// The floor: below 11, Inter stops being legible on a low-DPI Android panel.
  static const double sizeLabelSmall = 11;

  static const double heightTight = 1.1;
  static const double heightSnug = 1.25;
  static const double heightRelaxed = 1.45;
  static const double heightLabel = 1.35;

  static const double trackingDisplay = -0.6;
  static const double trackingHeadline = -0.2;
  static const double trackingBody = 0;
  static const double trackingLabel = 0.2;
}
