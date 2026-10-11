import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/money/money_formatter.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/core/theme/theme_context.dart';

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
class GPMoneyText extends StatelessWidget {
  const GPMoneyText(this.amount, {this.tone = GPMoneyTone.neutral, this.style, super.key});

  /// Positive for [GPMoneyTone.expense] and [GPMoneyTone.income]: the tone gives the direction.
  final Money amount;
  final GPMoneyTone tone;
  final TextStyle? style;

  static String label(Money amount, GPMoneyTone tone, GPMoneyFormatter formatter) => switch (tone) {
    GPMoneyTone.expense => formatter.format(-amount),
    GPMoneyTone.income => '+${formatter.format(amount)}',
    GPMoneyTone.neutral => formatter.format(amount),
  };

  static Color? colorOf(GPMoneyTone tone, GPColors colors) => switch (tone) {
    GPMoneyTone.expense => colors.expense,
    GPMoneyTone.income => colors.income,
    GPMoneyTone.neutral => null,
  };

  @override
  Widget build(BuildContext context) {
    final text = label(amount, tone, GPMoneyFormatter(context.l10n.locale));
    final color = colorOf(tone, context.colors);

    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(color: color, fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
    );
  }
}
