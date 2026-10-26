import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../theme/tokens/glass.dart';

/// Frosted chrome over scrolling content, as a pill or a circle. Without [tint] it takes the page's own ground.
final class GPGlass extends StatelessWidget {
  const GPGlass({super.key, this.tint, this.circle = false, required this.child});

  /// Applied at [GPGlassTokens.accentFillOpacity]: a tinted glass is a control and has to read as one.
  final Color? tint;

  final bool circle;
  final Widget child;

  /// Rec. 709 luma weights.
  static List<double> _saturationMatrix(double saturation) {
    const r = 0.2126;
    const g = 0.7152;
    const b = 0.0722;
    final t = 1.0 - saturation;

    return [
      r * t + saturation, g * t, b * t, 0.0, 0.0, //
      r * t, g * t + saturation, b * t, 0.0, 0.0,
      r * t, g * t, b * t + saturation, 0.0, 0.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ];
  }

  static final _filter = ImageFilter.compose(
    outer: ColorFilter.matrix(_saturationMatrix(GPGlassTokens.saturation)),
    inner: ImageFilter.blur(sigmaX: GPGlassTokens.blurSigma, sigmaY: GPGlassTokens.blurSigma),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    // Light glass is the page ground; dark glass is a surface, one step lighter than the ground it floats over.
    final fill = tint?.withValues(alpha: GPGlassTokens.accentFillOpacity) ?? (isDark ? colors.surface : colors.background).withValues(alpha: GPGlassTokens.fillOpacity);
    final rim = Colors.white.withValues(alpha: isDark ? GPGlassTokens.rimOpacityDark : GPGlassTokens.rimOpacityLight);
    final shape = circle ? const CircleBorder() : const StadiumBorder();

    return DecoratedBox(
      decoration: ShapeDecoration(shape: shape, shadows: context.shadows.large),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: _filter,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: fill,
              shape: circle ? CircleBorder(side: BorderSide(color: rim)) : StadiumBorder(side: BorderSide(color: rim)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
