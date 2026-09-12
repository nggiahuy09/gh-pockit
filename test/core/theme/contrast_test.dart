import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/theme/colors.dart';

/// WCAG 2.1 contrast ratio between two opaque colors.
///
/// `Color.computeLuminance()` already implements the WCAG relative-luminance formula, so this is only the ratio on top of it — no hand-rolled gamma
/// maths to get subtly wrong.
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
  // This file is the reason the palette's greens and reds are darker (light) and lighter (dark) than the values a designer would reach for first.
  //
  // It is a *unit* test of a design decision, which is unusual and deliberate. Contrast is the one visual property that is objectively checkable, and
  // the failure mode it guards is specific: somebody nudges a hue to taste six months from now, the app still looks fine on their laptop, and an
  // amount becomes unreadable in sunlight for everyone else. A golden test would not catch that — the golden would simply be regenerated.
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
        // The trap this catches: `onSurfaceVariant` is picked against `surfaceVariant`, then used for the subtitle line of a list item that sits
        // directly on `background`. Two different backgrounds, one color, and only one of them was ever checked.
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
        // The whole justification for the extra role. If a future edit collapses accentInk back into accent, this fails on the light palette.
        for (final (String ground, Color background) in <(String, Color)>[('background', colors.background), ('surface', colors.surface)]) {
          final ratio = _contrast(colors.accentInk, background);
          expect(ratio, greaterThanOrEqualTo(_aaText), reason: '$name accentInk on $ground is ${ratio.toStringAsFixed(2)}:1');
        }
      });

      test('income and expense separate by hue, which is the only axis they can separate on', () {
        // Deliberately *not* a contrast check. Contrast is a luminance ratio, and these two are tuned to sit at nearly the same luminance so both
        // clear 4.5:1 against the same ground — which puts their ratio against each other at ~1.0 by construction. Asserting contrast here would be
        // asserting that one of them is illegible.
        //
        // Hue distance is the real property. And it is still not a guarantee: WCAG 1.4.1 says color must never be the only carrier of meaning, so
        // the sign in front of the amount is what actually distinguishes income from expense for a red-green colorblind user. This test guards the
        // secondary signal, not the primary one.
        final income = HSLColor.fromColor(colors.income).hue;
        final expense = HSLColor.fromColor(colors.expense).hue;
        final distance = (income - expense).abs();
        final circular = math.min(distance, 360 - distance);

        expect(circular, greaterThanOrEqualTo(60), reason: '$name income and expense are only ${circular.toStringAsFixed(0)}° apart');
      });

      test('borders are visible, and outline is the louder of the two', () {
        // The 3:1 of WCAG 1.4.11 does not apply here: it covers the boundary a user needs to *identify a control*, not a decorative rule between
        // rows. No design system draws a 3:1 divider — it would look like a table from 1998. The floors below are "perceptible", and the ordering
        // assertion is the one that actually catches a mistake: swapping the two roles is silent otherwise.
        final outline = _contrast(colors.outline, colors.surface);
        final variant = _contrast(colors.outlineVariant, colors.surface);

        expect(outline, greaterThanOrEqualTo(1.25), reason: '$name outline on surface is ${outline.toStringAsFixed(2)}:1 — invisible');
        expect(variant, greaterThanOrEqualTo(1.1), reason: '$name outlineVariant on surface is ${variant.toStringAsFixed(2)}:1 — invisible');
        expect(outline, greaterThan(variant), reason: '$name outline must be stronger than outlineVariant');
      });

      test('every focus-ring color can be seen on the ground it is drawn over', () {
        // Squarely inside WCAG 1.4.11: a focus indicator is how a keyboard or switch-access user knows where they are, so 3:1 is the real bar.
        //
        // This is the assertion that rejected the obvious choice. `accent` — the terracotta itself — lands at 2.96:1 on the light ground, which is
        // why GPButton rings with `accentInk` instead. Three hundredths of a ratio point is not a rounding error worth waving through; it is the
        // difference between a ring a low-vision user can find and one they cannot.
        final ringColors = <String, Color>{'accent': colors.accentInk, 'neutral': colors.onSurfaceVariant, 'danger': colors.danger};

        for (final entry in ringColors.entries) {
          final ratio = _contrast(entry.value, colors.background);
          expect(ratio, greaterThanOrEqualTo(_aaLarge), reason: '$name ${entry.key} focus ring on background is ${ratio.toStringAsFixed(2)}:1');
        }
      });
    });
  }
}
