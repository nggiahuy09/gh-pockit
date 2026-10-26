import 'package:flutter/material.dart';

import '../localization/localization_scope.dart';
import '../money/money.dart';
import '../money/money_formatter.dart';
import '../theme/colors.dart';
import '../theme/theme_context.dart';

/// The sign carries the meaning, the color only repeats it (WCAG 1.4.1).
enum GPMoneyTone {
  /// `-45.000 ₫`.
  expense,

  /// `+45.000 ₫`.
  income,

  /// Printed as is, so a negative balance keeps its own sign.
  neutral,
}

/// Adds sign, color and tabular digits; size and weight come from [style]. Never truncated: a cut amount reads as a different amount.
final class GPMoneyText extends StatelessWidget {
  const GPMoneyText({super.key, this.style, required this.amount, this.tone = GPMoneyTone.neutral});

  final TextStyle? style;

  /// Positive for [GPMoneyTone.expense] and [GPMoneyTone.income]: the tone gives the direction.
  final Money amount;

  final GPMoneyTone tone;

  static String label(Money amount, GPMoneyFormatter formatter, GPMoneyTone tone) => switch (tone) {
    GPMoneyTone.expense => formatter.format(-amount),
    GPMoneyTone.income => '+${formatter.format(amount)}',
    GPMoneyTone.neutral => formatter.format(amount),
  };

  static Color? colorOf(GPColors colors, GPMoneyTone tone) => switch (tone) {
    GPMoneyTone.expense => colors.expense,
    GPMoneyTone.income => colors.income,
    GPMoneyTone.neutral => null,
  };

  @override
  Widget build(BuildContext context) => Text(
    label(amount, GPMoneyFormatter(context.l10n.locale), tone),
    style: (style ?? const TextStyle()).copyWith(color: colorOf(context.colors, tone), fontFeatures: const [FontFeature.tabularFigures()]),
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.visible,
  );
}
