import 'package:flutter/material.dart';
import 'package:ghpockit/core/theme/tokens/shadows.dart';

@immutable
class GPShadows extends ThemeExtension<GPShadows> {
  const GPShadows({required this.small, required this.medium, required this.large, required this.extraLarge});

  const GPShadows.light() : small = GPShadowTokens.small, medium = GPShadowTokens.medium, large = GPShadowTokens.large, extraLarge = GPShadowTokens.extraLarge;

  /// No shadows: a dark ground has nothing left to darken, so surfaces separate by lightness instead.
  const GPShadows.dark() : small = GPShadowTokens.none, medium = GPShadowTokens.none, large = GPShadowTokens.none, extraLarge = GPShadowTokens.none;

  final List<BoxShadow> small;
  final List<BoxShadow> medium;
  final List<BoxShadow> large;
  final List<BoxShadow> extraLarge;

  @override
  GPShadows copyWith({List<BoxShadow>? small, List<BoxShadow>? medium, List<BoxShadow>? large, List<BoxShadow>? extraLarge}) => GPShadows(
    small: small ?? this.small,
    medium: medium ?? this.medium,
    large: large ?? this.large,
    extraLarge: extraLarge ?? this.extraLarge,
  );

  @override
  GPShadows lerp(ThemeExtension<GPShadows>? other, double t) {
    if (other is! GPShadows) return this;

    return GPShadows(
      small: BoxShadow.lerpList(small, other.small, t)!,
      medium: BoxShadow.lerpList(medium, other.medium, t)!,
      large: BoxShadow.lerpList(large, other.large, t)!,
      extraLarge: BoxShadow.lerpList(extraLarge, other.extraLarge, t)!,
    );
  }
}
