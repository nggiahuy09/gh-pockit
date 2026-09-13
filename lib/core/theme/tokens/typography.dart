import 'dart:ui' show FontWeight;

/// Raw type values — family, weights, sizes, line heights.
///
/// Primitives; widgets read `context.text` instead (see `GPTypography`).
///
/// ## The scale
///
/// Rebuilt for a phone, not inherited from the kit. `ngh09_ui_kit` carries the Finesse web scale, which tops out at a 120px display size — a number
/// that cannot appear on a 390pt-wide screen. The steps below are sized for the two things this app actually renders: a balance figure large enough
/// to read at arm's length, and a dense transaction list.
///
/// Inter rather than Anthropic's own Styrene / Tiempos, which are licensed and not distributable. Inter is the closest open grotesque: same
/// neutral skeleton, same tall x-height, and it holds up at 12sp in a list — which matters more here than matching a display face exactly.
abstract final class GPTypographyTokens {
  /// The one family. Bundled locally under `assets/fonts/` — see the README there for why it is not `google_fonts`.
  static const String fontFamily = 'Inter';

  /// 400 — body copy.
  static const FontWeight regular = FontWeight.w400;

  /// 500 — list titles, emphasised body.
  static const FontWeight medium = FontWeight.w500;

  /// 600 — buttons, section headers, money.
  static const FontWeight semiBold = FontWeight.w600;

  /// 700 — the balance figure, and nothing else.
  static const FontWeight bold = FontWeight.w700;

  // ── Sizes (logical px) ───────────────────────────────────────────────────

  /// 40 — the account balance on the dashboard. The one genuinely large number.
  static const double sizeDisplayLarge = 40;

  /// 32 — a month total.
  static const double sizeDisplayMedium = 32;

  /// 28 — a screen title on a large header.
  static const double sizeDisplaySmall = 28;

  /// 24.
  static const double sizeHeadlineLarge = 24;

  /// 22 — the app-bar title.
  static const double sizeHeadlineMedium = 22;

  /// 20 — a section header.
  static const double sizeHeadlineSmall = 20;

  /// 18 — a card title.
  static const double sizeTitleLarge = 18;

  /// 16 — a list-item title, and the button label.
  static const double sizeTitleMedium = 16;

  /// 14 — a dense list-item title.
  static const double sizeTitleSmall = 14;

  /// 16 — body copy.
  static const double sizeBodyLarge = 16;

  /// 14 — the default body size. Most of the app is this.
  static const double sizeBodyMedium = 14;

  /// 13 — supporting text under a list item.
  static const double sizeBodySmall = 13;

  /// 14 — a label that shares a line with body text.
  static const double sizeLabelLarge = 14;

  /// 12 — a date header, a chip, a badge.
  static const double sizeLabelMedium = 12;

  /// 11 — the smallest thing allowed on screen. Below this, Inter stops being legible on a low-DPI Android panel.
  static const double sizeLabelSmall = 11;

  // ── Line heights (multipliers) ───────────────────────────────────────────
  // Tight for large type, loose for small: a 40px balance with 1.5 line height
  // floats; a 13px caption with 1.2 collides with the line under it.

  /// 1.1 — display steps.
  static const double heightTight = 1.1;

  /// 1.25 — headline and title steps.
  static const double heightSnug = 1.25;

  /// 1.45 — body steps.
  static const double heightRelaxed = 1.45;

  /// 1.35 — label steps.
  static const double heightLabel = 1.35;

  // ── Letter spacing ───────────────────────────────────────────────────────
  // Inter is drawn for UI at its default tracking; only the extremes need help.

  /// -0.6 — display steps, which look gappy at their default tracking.
  static const double trackingDisplay = -0.6;

  /// -0.2 — headline and title steps.
  static const double trackingHeadline = -0.2;

  /// 0 — body steps. Inter's default.
  static const double trackingBody = 0;

  /// 0.2 — small labels, which need air to stay readable.
  static const double trackingLabel = 0.2;
}
