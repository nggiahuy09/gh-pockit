import 'package:flutter/material.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/core/theme/dimensions.dart';
import 'package:ghpockit/core/theme/shadows.dart';
import 'package:ghpockit/core/theme/tokens/dimensions.dart';
import 'package:ghpockit/core/theme/typography.dart';

/// The `!` is deliberate: under a theme without the GP extensions (a bare `MaterialApp` in a widget test) it throws rather than render Material defaults.
extension GPThemeContext on BuildContext {
  GPColors get colors => Theme.of(this).extension<GPColors>()!;

  GPSpacing get spacing => Theme.of(this).extension<GPSpacing>()!;

  GPRadii get radii => Theme.of(this).extension<GPRadii>()!;

  GPShadows get shadows => Theme.of(this).extension<GPShadows>()!;

  GPTypography get text => Theme.of(this).extension<GPTypography>()!;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

extension GPLayoutContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isPhone => screenWidth < GPBreakpointTokens.tablet;

  bool get isTablet => screenWidth >= GPBreakpointTokens.tablet && screenWidth < GPBreakpointTokens.desktop;
}
