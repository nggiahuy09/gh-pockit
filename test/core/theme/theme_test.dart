import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/theme/app_theme.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/core/theme/dimensions.dart';
import 'package:ghpockit/core/theme/shadows.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/theme/tokens/typography.dart';
import 'package:ghpockit/core/theme/typography.dart';

void main() {
  group('GPAppTheme', () {
    for (final (String name, ThemeData theme) in <(String, ThemeData)>[('light', GPAppTheme.light()), ('dark', GPAppTheme.dark())]) {
      group(name, () {
        test('registers every extension', () {
          // `context.colors` and friends end in a `!`. If an extension is ever dropped from the list in GPAppTheme, that bang throws at runtime in
          // whichever screen happens to read it first. This is the test that turns that into a build failure instead.
          expect(theme.extension<GPColors>(), isNotNull);
          expect(theme.extension<GPTypography>(), isNotNull);
          expect(theme.extension<GPSpacing>(), isNotNull);
          expect(theme.extension<GPRadii>(), isNotNull);
          expect(theme.extension<GPShadows>(), isNotNull);
        });

        test('projects the palette onto Material, so built-in widgets do not fall back to purple', () {
          final colors = theme.extension<GPColors>()!;

          expect(theme.colorScheme.primary, colors.primary);
          expect(theme.colorScheme.secondary, colors.accent, reason: 'Material has no accent role; ours maps onto secondary');
          expect(theme.colorScheme.error, colors.danger);
          expect(theme.colorScheme.surface, colors.surface);
          expect(theme.scaffoldBackgroundColor, colors.background);
        });

        test('projects the type scale onto Material and uses the bundled family', () {
          final text = theme.extension<GPTypography>()!;
          final body = theme.textTheme.bodyMedium!;

          // Compared field by field rather than with `==`: ThemeData runs the TextTheme through `.apply()` to stamp a default text color on it, so
          // the style Material ends up with is deliberately *not* identical to ours. The metrics are what must survive that pass.
          expect(body.fontSize, text.bodyMedium.fontSize);
          expect(body.fontWeight, text.bodyMedium.fontWeight);
          expect(body.height, text.bodyMedium.height);
          expect(theme.textTheme.titleMedium?.fontFamily, GPTypographyTokens.fontFamily);
          // Not the platform default: if this ever reads 'Roboto', the fonts block in pubspec.yaml is broken and every screen silently changed shape.
          expect(body.fontFamily, 'Inter');
        });

        test('Material stamps the palette text color onto the projected TextTheme', () {
          // The reason GPTypography carries no color of its own: the styles arrive uncolored and ThemeData colors them from the scheme. If this ever
          // stops holding, every `Text` in the app falls back to Material's own black regardless of the palette.
          expect(theme.textTheme.bodyMedium?.color, theme.extension<GPColors>()!.onSurface);
        });

        test('brightness agrees between the palette and the ThemeData', () {
          // These are set in two different places and a mismatch is silent — the app renders a light palette while Material picks dark defaults for
          // everything the palette does not cover.
          expect(theme.brightness, theme.extension<GPColors>()!.brightness);
        });
      });
    }

    test('light and dark are actually different palettes', () {
      final light = GPAppTheme.light().extension<GPColors>()!;
      final dark = GPAppTheme.dark().extension<GPColors>()!;

      expect(light.background, isNot(dark.background));
      expect(light.onBackground, isNot(dark.onBackground));
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
    });

    test('dark mode carries no ambient shadow', () {
      // Documented behaviour, not an oversight: a shadow darkens what is behind it, and on a near-black ground there is nothing left to darken.
      final dark = GPAppTheme.dark().extension<GPShadows>()!;

      expect(dark.medium, isEmpty);
      expect(dark.extraLarge, isEmpty);
      expect(GPAppTheme.light().extension<GPShadows>()!.medium, isNotEmpty);
    });
  });

  group('lerp', () {
    test('GPColors flips brightness at the midpoint rather than interpolating it', () {
      const light = GPColors.light();
      const dark = GPColors.dark();

      expect(light.lerp(dark, 0).brightness, Brightness.light);
      expect(light.lerp(dark, 0.49).brightness, Brightness.light);
      expect(light.lerp(dark, 0.5).brightness, Brightness.dark);
      expect(light.lerp(dark, 1).brightness, Brightness.dark);
    });

    test('every extension returns itself when handed a foreign extension', () {
      // Flutter calls `lerp` with whatever sits in the same slot of the other theme. Returning `this` is the only safe answer, and getting it wrong
      // means a null-cast crash mid-animation.
      const colors = GPColors.light();
      const spacing = GPSpacing.standard();

      expect(colors.lerp(null, 0.5), same(colors));
      expect(spacing.lerp(null, 0.5), same(spacing));
    });

    test('GPColors interpolates the colors themselves', () {
      const light = GPColors.light();
      const dark = GPColors.dark();
      final half = light.lerp(dark, 0.5);

      expect(half.background, isNot(light.background));
      expect(half.background, isNot(dark.background));
      expect(half.background, Color.lerp(light.background, dark.background, 0.5));
    });
  });

  group('context accessors', () {
    testWidgets('resolve against the active theme', (WidgetTester tester) async {
      late GPColors colors;
      late double md;

      await tester.pumpWidget(
        MaterialApp(
          theme: GPAppTheme.light(),
          home: Builder(
            builder: (BuildContext context) {
              colors = context.colors;
              md = context.spacing.md;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(colors.background, const GPColors.light().background);
      expect(md, 16);
    });

    testWidgets('follow the theme when it switches to dark', (WidgetTester tester) async {
      late Brightness seen;

      Widget app(ThemeData theme) => MaterialApp(
        theme: theme,
        home: Builder(
          builder: (BuildContext context) {
            seen = context.colors.brightness;
            return const SizedBox.shrink();
          },
        ),
      );

      await tester.pumpWidget(app(GPAppTheme.light()));
      expect(seen, Brightness.light);

      await tester.pumpWidget(app(GPAppTheme.dark()));
      await tester.pumpAndSettle();
      expect(seen, Brightness.dark);
    });
  });
}
