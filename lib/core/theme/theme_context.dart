import 'package:flutter/material.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/core/theme/dimensions.dart';
import 'package:ghpockit/core/theme/shadows.dart';
import 'package:ghpockit/core/theme/tokens/dimensions.dart';
import 'package:ghpockit/core/theme/typography.dart';

/// Short reads for the theme extensions.
///
/// Turns `Theme.of(context).extension<GPColors>()!` into `context.colors`. Without this the `!` gets typed a hundred times and eventually somebody
/// avoids the ceremony by hardcoding a `Color(0xFF...)` in a widget, which is the failure this whole layer exists to prevent.
///
/// The bang is safe because `GPAppTheme` registers every extension on both themes, and a widget only builds under a `MaterialApp` that used it. A
/// widget test that pumps a bare `MaterialApp` with no theme will throw here — deliberately, and immediately, rather than rendering in Material
/// purple and passing.
extension GPThemeContext on BuildContext {
  GPColors get colors => Theme.of(this).extension<GPColors>()!;

  GPSpacing get spacing => Theme.of(this).extension<GPSpacing>()!;

  GPRadii get radii => Theme.of(this).extension<GPRadii>()!;

  GPShadows get shadows => Theme.of(this).extension<GPShadows>()!;

  GPTypography get text => Theme.of(this).extension<GPTypography>()!;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// Layout reads.
///
/// Kept apart from [GPThemeContext] because these depend on `MediaQuery`, not on `Theme`: a widget that reads [isPhone] rebuilds when the window
/// resizes or the keyboard opens, and mixing that dependency into the color accessors would make every themed widget do the same.
extension GPLayoutContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isPhone => screenWidth < GPBreakpointTokens.tablet;

  bool get isTablet => screenWidth >= GPBreakpointTokens.tablet && screenWidth < GPBreakpointTokens.desktop;
}
