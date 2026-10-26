/// The frosted chrome that floats over content: the navigation dock and its add button. Tint colors are roles, applied at these opacities.
abstract final class GPGlassTokens {
  /// CSS `blur()` takes a standard deviation, as `ImageFilter.blur` does, so the design's 24px carries over unchanged.
  static const double blurSigma = 24.0;

  /// Puts back the color the blur washes out of whatever scrolls underneath.
  static const double saturation = 1.8;

  static const double fillOpacity = 0.62;
  static const double accentFillOpacity = 0.9;

  /// The 1px white rim that separates the glass from content of a similar tone.
  static const double rimOpacityLight = 0.55;
  static const double rimOpacityDark = 0.08;
}
