import 'package:flutter/material.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/theme/tokens/dimensions.dart';

enum GPProgressKind {
  /// A credit limit, a budget: fuller is closer to the limit.
  spending,

  /// A savings target: fuller is better.
  goal,
}

enum GPProgressTone {
  normal,
  warning,
  over,
  goal;

  /// Integer comparisons on the minor units: no ratio is ever rounded across a threshold.
  static GPProgressTone of({required int value, required int max, required GPProgressKind kind}) {
    if (kind == GPProgressKind.goal) return GPProgressTone.goal;
    if (max <= 0) return value > 0 ? GPProgressTone.over : GPProgressTone.normal;
    if (value >= max) return GPProgressTone.over;
    if (value * 100 >= max * warningPercent) return GPProgressTone.warning;
    return GPProgressTone.normal;
  }

  static const int warningPercent = 85;

  Color barColor(GPColors colors) => switch (this) {
    GPProgressTone.normal => colors.primary,
    GPProgressTone.warning => colors.warning,
    GPProgressTone.over => colors.danger,
    GPProgressTone.goal => colors.success,
  };
}

enum GPProgressSize {
  /// 8, in a list or a card.
  regular,

  /// 12, on a detail screen.
  large,
}

/// How far [value] has come toward [max]. Color never stands alone: put the amounts and a [GPProgressStatus] next to it.
class GPProgressBar extends StatelessWidget {
  const GPProgressBar({required this.value, required this.max, this.kind = GPProgressKind.spending, this.size = GPProgressSize.regular, this.semanticLabel, super.key});

  /// Same unit as [max], typically minor units.
  final int value;
  final int max;
  final GPProgressKind kind;
  final GPProgressSize size;
  final String? semanticLabel;

  /// Whole percent, unclamped: a budget can be at 115%.
  static int percentOf({required int value, required int max}) => max <= 0 ? (value > 0 ? 100 : 0) : value * 100 ~/ max;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = GPProgressTone.of(value: value, max: max, kind: kind);
    final percent = percentOf(value: value, max: max);
    final fraction = (percent.clamp(0, 100)) / 100;
    final height = size == GPProgressSize.large ? 12.0 : 8.0;

    return Semantics(
      label: semanticLabel,
      value: '$percent%',
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        // The ground, ringed in outlineVariant: every bar color clears 3:1 against it, which a surfaceVariant track would not.
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: context.radii.borderFull,
          border: Border.all(color: colors.outlineVariant),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: fraction),
          duration: GPDurationTokens.slow,
          curve: Curves.easeOut,
          builder: (BuildContext context, double t, Widget? _) => FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: t,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: tone.barColor(colors), borderRadius: context.radii.borderFull),
            ),
          ),
        ),
      ),
    );
  }
}

/// The line under a [GPProgressBar]: an icon and a short sentence in the bar's tone.
class GPProgressStatus extends StatelessWidget {
  const GPProgressStatus({required this.tone, required this.icon, required this.text, super.key});

  final GPProgressTone tone;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Warning text stays ink: amber is a fill color, under 4.5:1 as text on the light ground.
    final (Color textColor, Color iconColor) = switch (tone) {
      GPProgressTone.normal => (colors.onSurfaceVariant, colors.onSurfaceVariant),
      GPProgressTone.warning => (colors.onSurface, colors.warning),
      GPProgressTone.over => (colors.danger, colors.danger),
      GPProgressTone.goal => (colors.success, colors.success),
    };

    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: context.text.bodySmall.copyWith(color: textColor, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
