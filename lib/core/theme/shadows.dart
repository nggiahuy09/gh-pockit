import 'package:flutter/material.dart';
import 'package:ghpockit/core/theme/tokens/shadows.dart';

/// Semantic elevation, as a [ThemeExtension].
///
/// Read through `context.shadows`.
///
/// Dark mode drops every step to [GPShadowTokens.none] and separates surfaces by lightness instead. A shadow works by darkening what is behind it;
/// on a `#262624` ground there is nothing left to darken, so the shadow is cost with no effect.
///
/// Focus rings are not here — see [GPShadowTokens] for why they are built from the palette instead.
@immutable
class GPShadows extends ThemeExtension<GPShadows> {
  const GPShadows({required this.small, required this.medium, required this.large, required this.extraLarge});

  /// Elevation for a light UI.
  const GPShadows.light() : small = GPShadowTokens.small, medium = GPShadowTokens.medium, large = GPShadowTokens.large, extraLarge = GPShadowTokens.extraLarge;

  /// Elevation for a dark UI: nothing at all.
  const GPShadows.dark() : small = GPShadowTokens.none, medium = GPShadowTokens.none, large = GPShadowTokens.none, extraLarge = GPShadowTokens.none;

  /// A list item lifting off the ground without becoming a card.
  final List<BoxShadow> small;

  /// The default card.
  final List<BoxShadow> medium;

  /// Menus, popovers, the FAB.
  final List<BoxShadow> large;

  /// Bottom sheets and dialogs.
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
