import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:ghpockit/core/theme/tokens/dimensions.dart';

/// The spacing scale, as a [ThemeExtension].
///
/// Read through `context.spacing`. A `ThemeExtension` rather than plain constants so a future density setting — a "compact list" toggle, or a
/// tablet layout — can hand down a tighter scale without touching a single widget.
@immutable
class GPSpacing extends ThemeExtension<GPSpacing> {
  const GPSpacing({required this.xxs, required this.xs, required this.sm, required this.smd, required this.md, required this.lg, required this.xl, required this.xxl});

  /// The default 4pt scale.
  const GPSpacing.standard()
    : xxs = GPSpacingTokens.xxs,
      xs = GPSpacingTokens.xs,
      sm = GPSpacingTokens.sm,
      smd = GPSpacingTokens.smd,
      md = GPSpacingTokens.md,
      lg = GPSpacingTokens.lg,
      xl = GPSpacingTokens.xl,
      xxl = GPSpacingTokens.xxl;

  /// 2 — hairline separation, e.g. a label and its helper text.
  final double xxs;

  /// 4.
  final double xs;

  /// 8.
  final double sm;

  /// 12.
  final double smd;

  /// 16 — the default unit.
  final double md;

  /// 24 — between sections of a screen.
  final double lg;

  /// 32.
  final double xl;

  /// 48 — around an empty state or a hero number.
  final double xxl;

  @override
  GPSpacing copyWith({double? xxs, double? xs, double? sm, double? smd, double? md, double? lg, double? xl, double? xxl}) => GPSpacing(
    xxs: xxs ?? this.xxs,
    xs: xs ?? this.xs,
    sm: sm ?? this.sm,
    smd: smd ?? this.smd,
    md: md ?? this.md,
    lg: lg ?? this.lg,
    xl: xl ?? this.xl,
    xxl: xxl ?? this.xxl,
  );

  @override
  GPSpacing lerp(ThemeExtension<GPSpacing>? other, double t) {
    if (other is! GPSpacing) return this;

    return GPSpacing(
      xxs: lerpDouble(xxs, other.xxs, t)!,
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      smd: lerpDouble(smd, other.smd, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
      xxl: lerpDouble(xxl, other.xxl, t)!,
    );
  }
}

/// The corner-radius scale, as a [ThemeExtension].
///
/// Read through `context.radii`. Exposes both the raw doubles and ready-made [BorderRadius] values, because almost every call site wants the latter
/// and `BorderRadius.circular(context.radii.md)` allocates a new object on every build.
@immutable
class GPRadii extends ThemeExtension<GPRadii> {
  const GPRadii({required this.sm, required this.md, required this.lg, required this.xl, required this.full});

  /// The default scale.
  const GPRadii.standard() : sm = GPRadiusTokens.sm, md = GPRadiusTokens.md, lg = GPRadiusTokens.lg, xl = GPRadiusTokens.xl, full = GPRadiusTokens.full;

  /// 6 — chips, badges, small inputs.
  final double sm;

  /// 10 — the default. Buttons, text fields, list tiles.
  final double md;

  /// 16 — cards, sheets, dialogs.
  final double lg;

  /// 24 — the top corners of a bottom sheet.
  final double xl;

  /// Pill or circle.
  final double full;

  /// [sm] as a [BorderRadius].
  BorderRadius get borderSm => BorderRadius.circular(sm);

  /// [md] as a [BorderRadius].
  BorderRadius get borderMd => BorderRadius.circular(md);

  /// [lg] as a [BorderRadius].
  BorderRadius get borderLg => BorderRadius.circular(lg);

  /// [xl] as a [BorderRadius].
  BorderRadius get borderXl => BorderRadius.circular(xl);

  /// [full] as a [BorderRadius].
  BorderRadius get borderFull => BorderRadius.circular(full);

  @override
  GPRadii copyWith({double? sm, double? md, double? lg, double? xl, double? full}) =>
      GPRadii(sm: sm ?? this.sm, md: md ?? this.md, lg: lg ?? this.lg, xl: xl ?? this.xl, full: full ?? this.full);

  @override
  GPRadii lerp(ThemeExtension<GPRadii>? other, double t) {
    if (other is! GPRadii) return this;

    return GPRadii(
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
      full: lerpDouble(full, other.full, t)!,
    );
  }
}
