import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/theme/colors.dart';

/// WCAG 2.1 contrast ratio. `Color.computeLuminance()` already implements the relative-luminance formula.
double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

/// WCAG AA for body-sized text.
const double _aaText = 4.5;

/// WCAG AA for large text and for non-text UI (icons, borders, focus rings).
const double _aaLarge = 3;

void main() {
  for (final (String name, GPColors colors) in const <(String, GPColors)>[('light', GPColors.light()), ('dark', GPColors.dark())]) {
    group('$name palette', () {
      test('every fill is legible under its own content color', () {
        final pairs = <String, (Color, Color)>{
          'onPrimary/primary': (colors.onPrimary, colors.primary),
          'onPrimaryContainer/primaryContainer': (colors.onPrimaryContainer, colors.primaryContainer),
          'onAccent/accent': (colors.onAccent, colors.accent),
          'onAccentContainer/accentContainer': (colors.onAccentContainer, colors.accentContainer),
          'onBackground/background': (colors.onBackground, colors.background),
          'onSurface/surface': (colors.onSurface, colors.surface),
          'onSurfaceVariant/surfaceVariant': (colors.onSurfaceVariant, colors.surfaceVariant),
          'onSuccess/success': (colors.onSuccess, colors.success),
          'onWarning/warning': (colors.onWarning, colors.warning),
          'onDanger/danger': (colors.onDanger, colors.danger),
        };

        for (final entry in pairs.entries) {
          final ratio = _contrast(entry.value.$1, entry.value.$2);
          expect(ratio, greaterThanOrEqualTo(_aaText), reason: '$name ${entry.key} is ${ratio.toStringAsFixed(2)}:1, below AA $_aaText:1');
        }
      });

      test('secondary text stays legible on the ground, not just on its own fill', () {
        final ratio = _contrast(colors.onSurfaceVariant, colors.background);

        expect(ratio, greaterThanOrEqualTo(_aaText), reason: '$name onSurfaceVariant on background is ${ratio.toStringAsFixed(2)}:1');
      });

      test('money colors are legible on every surface they can land on', () {
        // An amount is body-sized text, so it owes the full 4.5:1 — not the 3:1 a large figure would.
        for (final (String role, Color color) in <(String, Color)>[('income', colors.income), ('expense', colors.expense)]) {
          for (final (String ground, Color background) in <(String, Color)>[('background', colors.background), ('surface', colors.surface)]) {
            final ratio = _contrast(color, background);
            expect(ratio, greaterThanOrEqualTo(_aaText), reason: '$name $role on $ground is ${ratio.toStringAsFixed(2)}:1');
          }
        }
      });

      test('accentInk carries the accent as text, where accent itself cannot', () {
        for (final (String ground, Color background) in <(String, Color)>[('background', colors.background), ('surface', colors.surface)]) {
          final ratio = _contrast(colors.accentInk, background);
          expect(ratio, greaterThanOrEqualTo(_aaText), reason: '$name accentInk on $ground is ${ratio.toStringAsFixed(2)}:1');
        }
      });

      test('income and expense separate by hue, which is the only axis they can separate on', () {
        // Not a contrast check: the two are tuned to the same luminance, so their mutual ratio is ~1.0 by construction. Hue is the secondary signal —
        // the sign in front of the amount carries the meaning (WCAG 1.4.1).
        final income = HSLColor.fromColor(colors.income).hue;
        final expense = HSLColor.fromColor(colors.expense).hue;
        final distance = (income - expense).abs();
        final circular = math.min(distance, 360 - distance);

        expect(circular, greaterThanOrEqualTo(60), reason: '$name income and expense are only ${circular.toStringAsFixed(0)}° apart');
      });

      test('borders are visible, and outline is the louder of the two', () {
        // WCAG 1.4.11's 3:1 covers controls, not dividers, so these floors are only "perceptible"; the ordering check catches the two roles swapped.
        final outline = _contrast(colors.outline, colors.surface);
        final variant = _contrast(colors.outlineVariant, colors.surface);

        expect(outline, greaterThanOrEqualTo(1.25), reason: '$name outline on surface is ${outline.toStringAsFixed(2)}:1 — invisible');
        expect(variant, greaterThanOrEqualTo(1.1), reason: '$name outlineVariant on surface is ${variant.toStringAsFixed(2)}:1 — invisible');
        expect(outline, greaterThan(variant), reason: '$name outline must be stronger than outlineVariant');
      });

      test('every focus-ring color can be seen on the ground it is drawn over', () {
        // WCAG 1.4.11's 3:1 applies here. `accent` itself lands at 2.96:1 on the light ground, which is why GPButton rings with `accentInk`.
        final ringColors = <String, Color>{'accent': colors.accentInk, 'neutral': colors.onSurfaceVariant, 'danger': colors.danger};

        for (final entry in ringColors.entries) {
          final ratio = _contrast(entry.value, colors.background);
          expect(ratio, greaterThanOrEqualTo(_aaLarge), reason: '$name ${entry.key} focus ring on background is ${ratio.toStringAsFixed(2)}:1');
        }
      });
    });
  }
}
