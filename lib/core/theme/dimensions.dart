import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:ghpockit/core/theme/tokens/dimensions.dart';

/// A `ThemeExtension`, not constants, so a density setting can hand down another scale without touching a widget (ADR-0005).
@immutable
class GPSpacing extends ThemeExtension<GPSpacing> {
  const GPSpacing({required this.xxs, required this.xs, required this.sm, required this.smd, required this.md, required this.lg, required this.xl, required this.xxl});

  const GPSpacing.standard()
    : xxs = GPSpacingTokens.xxs,
      xs = GPSpacingTokens.xs,
      sm = GPSpacingTokens.sm,
      smd = GPSpacingTokens.smd,
      md = GPSpacingTokens.md,
      lg = GPSpacingTokens.lg,
      xl = GPSpacingTokens.xl,
      xxl = GPSpacingTokens.xxl;

  final double xxs;
  final double xs;
  final double sm;
  final double smd;
  final double md;
  final double lg;
  final double xl;
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

@immutable
class GPRadii extends ThemeExtension<GPRadii> {
  const GPRadii({required this.sm, required this.md, required this.lg, required this.xl, required this.full});

  const GPRadii.standard() : sm = GPRadiusTokens.sm, md = GPRadiusTokens.md, lg = GPRadiusTokens.lg, xl = GPRadiusTokens.xl, full = GPRadiusTokens.full;

  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double full;

  BorderRadius get borderSm => BorderRadius.circular(sm);
  BorderRadius get borderMd => BorderRadius.circular(md);
  BorderRadius get borderLg => BorderRadius.circular(lg);
  BorderRadius get borderXl => BorderRadius.circular(xl);
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
