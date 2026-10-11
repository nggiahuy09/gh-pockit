/// Primitives; widgets read `context.spacing`.
abstract final class GPSpacingTokens {
  static const double none = 0;
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double smd = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

abstract final class GPRadiusTokens {
  static const double none = 0;
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
  static const double xl = 24;

  /// Pill / circle.
  static const double full = 9999;
}

abstract final class GPDurationTokens {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 360);
}

abstract final class GPBreakpointTokens {
  static const double tablet = 600;
  static const double desktop = 1024;
}
