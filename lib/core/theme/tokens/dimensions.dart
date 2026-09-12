/// Spacing scale, on a 4pt grid.
///
/// Primitives; widgets read `context.spacing` instead (see `GPSpacing`).
abstract final class GPSpacingTokens {
  /// 0 — no gap.
  static const double none = 0;

  /// 2 — hairline separation, e.g. between a label and its helper text.
  static const double xxs = 2;

  /// 4.
  static const double xs = 4;

  /// 8.
  static const double sm = 8;

  /// 12.
  static const double smd = 12;

  /// 16 — the default unit. Screen padding, list-item padding, form gaps.
  static const double md = 16;

  /// 24 — between sections of a screen.
  static const double lg = 24;

  /// 32.
  static const double xl = 32;

  /// 48 — around an empty state or a hero number.
  static const double xxl = 48;

  /// 64.
  static const double xxxl = 64;
}

/// Corner-radius scale.
///
/// Softer than Material's default. The Claude look rounds generously but stops short of pills for anything holding text — [full] is for avatars, dots and
/// segmented controls only.
abstract final class GPRadiusTokens {
  /// Square.
  static const double none = 0;

  /// 6 — chips, badges, small inputs.
  static const double sm = 6;

  /// 10 — the default. Buttons, text fields, list tiles.
  static const double md = 10;

  /// 16 — cards, sheets, dialogs.
  static const double lg = 16;

  /// 24 — the bottom sheet's top corners.
  static const double xl = 24;

  /// Pill / circle.
  static const double full = 9999;
}

/// Animation durations.
///
/// Three steps, no more. A fourth would mean somebody is tuning a specific widget rather than following the system.
abstract final class GPDurationTokens {
  /// 120ms — state changes on a control the finger is already on: press, hover, toggle.
  static const Duration fast = Duration(milliseconds: 120);

  /// 220ms — the default. Expansion, fades, snackbars.
  static const Duration normal = Duration(milliseconds: 220);

  /// 360ms — large surfaces: sheets, page transitions.
  static const Duration slow = Duration(milliseconds: 360);
}

/// Responsive breakpoints, in logical pixels.
///
/// Present but barely used: Pockit is Android-first and phone-first (CLAUDE.md §1). These exist so a tablet layout has somewhere to hang later,
/// not because anything reads them today.
abstract final class GPBreakpointTokens {
  /// Below this width, lay out for a phone.
  static const double tablet = 600;

  /// Below this width, lay out for a tablet.
  static const double desktop = 1024;
}
