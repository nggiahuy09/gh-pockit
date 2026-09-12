import 'dart:ui' show Color;

/// Raw color values. The only file in the app allowed to hold a hex literal.
///
/// These are **primitives, not roles**: nothing outside `core/theme/` may read them. A widget that wants "the color of a disabled border" asks
/// `context.colors.outlineVariant`, not `GPColorTokens.warmGrey300` — otherwise re-theming means grepping the whole app instead of editing one file.
///
/// ## Where the values come from
///
/// The palette follows the Claude / Anthropic look: a warm off-white ground instead of pure white, near-black warm text instead of pure black, and a
/// single terracotta accent. The warmth is the point — every neutral here carries a yellow-red bias, so the UI reads as paper rather than as the
/// blue-grey Material hands out by default.
///
/// Values were sampled from the Claude interface and Anthropic's brand palette. They reproduce the *look*; they are not an official token export,
/// because none is published. Treat them as Pockit's palette.
///
/// ## Two things were changed rather than copied
///
/// 1. **Terracotta is the accent, not the action color.** Anthropic's own call-to-action buttons are near-black; the orange is reserved for brand and
///    accent. That is also the accessible choice: white on `clay500` is 3.1:1, which fails WCAG AA for body text, while white on `ink` is 17:1.
/// 2. **Status fills are darkened from their obvious values** so their `on*` color clears 4.5:1. `test/core/theme/contrast_test.dart` is the guard —
///    it recomputes every pairing and fails if a future tweak drops one below AA.
abstract final class GPColorTokens {
  // ── Warm neutrals ────────────────────────────────────────────────────────
  // The spine of the palette. Every step is warm (hue ≈ 40-50°) rather than neutral grey, which separates this from a stock Material theme more than
  // the accent does.

  /// Pure white — card surfaces in light mode, floating on [ivory50].
  static const Color white = Color(0xFFFFFFFF);

  /// The lightest ground — the app background in light mode.
  static const Color ivory50 = Color(0xFFFAF9F5);

  /// One step down: a surface that must separate from [ivory50] without a border.
  static const Color ivory100 = Color(0xFFF5F4EF);

  /// Quiet fills — code blocks, unselected segments, disabled inputs.
  static const Color ivory200 = Color(0xFFF0EEE6);

  /// Hairlines and dividers in light mode.
  static const Color warmGrey200 = Color(0xFFE8E6DC);

  /// Default border in light mode.
  static const Color warmGrey300 = Color(0xFFDEDCD1);

  /// Disabled content and placeholder text.
  static const Color warmGrey400 = Color(0xFFB8B5AC);

  /// Tertiary text.
  static const Color warmGrey500 = Color(0xFF828179);

  /// Secondary text in light mode.
  static const Color warmGrey600 = Color(0xFF6B6862);

  /// Borders in dark mode.
  static const Color warmGrey700 = Color(0xFF43423E);

  /// Hairlines in dark mode — one step below [warmGrey700] so a divider inside a card still reads.
  static const Color warmGrey750 = Color(0xFF3A3937);

  /// Raised surface in dark mode — cards, sheets, menus.
  static const Color warmGrey800 = Color(0xFF30302E);

  /// The dark-mode ground.
  static const Color warmGrey900 = Color(0xFF262624);

  /// Below the ground: scrims, insets, and the `on*` color for bright fills in dark mode.
  static const Color warmGrey950 = Color(0xFF1F1E1D);

  /// Primary text in light mode. Deliberately not `0xFF000000`: pure black on a warm ground reads as a hole punched in the paper.
  static const Color ink = Color(0xFF141413);

  /// Primary text in dark mode. Equally deliberately not pure white.
  static const Color paper = Color(0xFFF5F4EF);

  // ── Accent ───────────────────────────────────────────────────────────────

  /// Tonal accent fill in light mode — selected chips, accent banners.
  static const Color clay100 = Color(0xFFF6E5DC);

  /// The accent on dark surfaces, lifted so it does not muddy against [warmGrey900].
  static const Color clay400 = Color(0xFFE0906F);

  /// The terracotta accent — Claude's signature color, and the only saturated hue in normal use.
  ///
  /// Exactly one accent is the discipline: a second brand color would compete with the status ramp below, and in a finance app that ramp is the one
  /// thing that must never be ambiguous.
  static const Color clay500 = Color(0xFFD97757);

  /// Pressed and hovered accent.
  static const Color clay600 = Color(0xFFC15F3C);

  /// The accent as *text or an icon* on a light ground.
  ///
  /// [clay500] cannot do that job: on [ivory50] it lands at 2.96:1, which misses even the 3:1 that non-text UI owes, let alone the 4.5:1 body text
  /// owes. A brand color that works as a fill and fails as a label is the single most common accessibility hole in a warm palette, so the two cases
  /// get two tokens instead of one compromise.
  static const Color clay700 = Color(0xFFA84F2E);

  /// Accent text on a [clay100] fill.
  static const Color clay800 = Color(0xFF7A3A22);

  /// Tonal accent fill in dark mode.
  static const Color clay900 = Color(0xFF4A2D22);

  // ── Status ───────────────────────────────────────────────────────────────
  // Muted on purpose. A saturated web-red beside the terracotta accent makes both look like errors; these are desaturated enough to sit inside the warm
  // palette while staying unmistakably green / amber / red.

  /// Success and income, lifted for dark surfaces.
  static const Color green400 = Color(0xFF5FA681);

  /// Success and income fill in light mode. Darker than it looks like it should be, so white clears 4.5:1 on it.
  static const Color green600 = Color(0xFF2F6E4E);

  /// Success text on a light tonal green fill.
  static const Color green700 = Color(0xFF23593E);

  /// Warning, lifted for dark surfaces.
  static const Color amber400 = Color(0xFFD9A445);

  /// Warning fill. Takes dark content, not white — no amber that still reads as amber can clear 4.5:1 against white.
  static const Color amber500 = Color(0xFFB8821F);

  /// Warning text on a light tonal amber fill.
  static const Color amber700 = Color(0xFF7A5512);

  /// Danger and expense, lifted for dark surfaces.
  ///
  /// Lighter than it looks like it needs to be. The obvious `#C85A50` reaches only 3.6:1 against [warmGrey900], and an expense amount is body-sized
  /// text, so it owes the full 4.5:1 — not the 3:1 a large figure or an icon would.
  static const Color red400 = Color(0xFFE27A70);

  /// Danger and expense fill in light mode. Pushed redder than the terracotta accent on purpose: at a glance a destructive action must not be
  /// mistakable for a primary one.
  static const Color red500 = Color(0xFFA8332A);

  /// Danger text on a light tonal red fill.
  static const Color red700 = Color(0xFF6E211B);

  // ── Utility ──────────────────────────────────────────────────────────────

  /// Fully transparent, for variants that draw no fill.
  static const Color transparent = Color(0x00000000);

  /// Shadow base. Warm and very soft: a neutral black shadow on an ivory ground turns grey and reads as dirt.
  static const Color shadowWarm = Color(0xFF3D3A32);
}
