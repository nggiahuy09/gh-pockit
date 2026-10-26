/// Primitives; widgets read `context.spacing`.
abstract final class GPSpacingTokens {
  static const double none = 0.0;
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double smd = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}

abstract final class GPRadiusTokens {
  static const double none = 0.0;
  static const double sm = 6.0;
  static const double md = 10.0;
  static const double lg = 16.0;
  static const double xl = 24.0;

  /// Pill / circle.
  static const double full = 9999.0;
}

abstract final class GPDurationTokens {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 360);
}

abstract final class GPBreakpointTokens {
  static const double tablet = 600.0;
  static const double desktop = 1024.0;
}
