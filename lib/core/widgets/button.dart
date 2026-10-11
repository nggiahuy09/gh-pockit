import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/theme/tokens/dimensions.dart';

enum GPButtonVariant {
  primary,

  /// Terracotta, reserved for the one gesture that defines the screen, typically "add transaction".
  accent,

  tonal,
  outlined,
  text,
  danger,
}

enum GPButtonSize {
  /// 40 — under Android's 48 touch target, so only inside a row that is itself tappable.
  small,

  /// 48 — Android's minimum touch target.
  medium,

  large,
}

class GPButton extends StatefulWidget {
  const GPButton({
    required this.label,
    this.onPressed,
    this.variant = GPButtonVariant.primary,
    this.size = GPButtonSize.medium,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.expanded = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final GPButtonVariant variant;
  final GPButtonSize size;

  /// Replaced by the spinner while [isLoading]. Without one the button grows by the spinner's width, so make a form's submit button [expanded].
  final Widget? leading;

  /// Hidden while [isLoading].
  final Widget? trailing;

  /// Shows a spinner and refuses input.
  final bool isLoading;

  final bool expanded;

  @override
  State<GPButton> createState() => _GPButtonState();
}

class _GPButtonState extends State<GPButton> {
  // The Material button updates these during build, where setState throws: hence the post-frame listener and the deferred setState.
  final WidgetStatesController _statesController = WidgetStatesController();

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _statesController.addListener(_onStatesChanged) : null);
  }

  @override
  void dispose() {
    _statesController
      ..removeListener(_onStatesChanged)
      ..dispose();
    super.dispose();
  }

  void _onStatesChanged() {
    if (!mounted) return;

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() {}) : null);
    } else {
      setState(() {});
    }
  }

  double get _height => switch (widget.size) {
    GPButtonSize.small => 40,
    GPButtonSize.medium => 48,
    GPButtonSize.large => 56,
  };

  double get _horizontalPadding => switch (widget.size) {
    GPButtonSize.small => 14,
    GPButtonSize.medium => 20,
    GPButtonSize.large => 24,
  };

  double get _iconSize => switch (widget.size) {
    GPButtonSize.small => 16,
    GPButtonSize.medium || GPButtonSize.large => 20,
  };

  double get _gap => widget.size == GPButtonSize.small ? 6 : 8;

  /// Heavier than the title roles: at their weight a 14sp label inside a filled shape loses against its own background.
  TextStyle _labelStyle(BuildContext context) => switch (widget.size) {
    GPButtonSize.small => context.text.titleSmall,
    GPButtonSize.medium || GPButtonSize.large => context.text.titleMedium,
  }.copyWith(fontWeight: FontWeight.w600);

  Color _foreground(GPColors colors) => switch (widget.variant) {
    GPButtonVariant.primary => colors.onPrimary,
    GPButtonVariant.accent => colors.onAccent,
    GPButtonVariant.tonal => colors.onPrimaryContainer,
    GPButtonVariant.outlined || GPButtonVariant.text => colors.onBackground,
    GPButtonVariant.danger => colors.onDanger,
  };

  Color _background(GPColors colors) => switch (widget.variant) {
    GPButtonVariant.primary => colors.primary,
    GPButtonVariant.accent => colors.accent,
    GPButtonVariant.tonal => colors.primaryContainer,
    GPButtonVariant.outlined || GPButtonVariant.text => Colors.transparent,
    GPButtonVariant.danger => colors.danger,
  };

  /// Full opacity: WCAG 1.4.11 wants 3:1 and a soft halo lands near 1.5:1. A shadow, not a border, so focus does not resize the button.
  List<BoxShadow> _focusRing(GPColors colors) {
    if (!_isEnabled) return const <BoxShadow>[];

    final states = _statesController.value;
    if (!states.contains(WidgetState.focused) && !states.contains(WidgetState.pressed)) return const <BoxShadow>[];

    final color = switch (widget.variant) {
      GPButtonVariant.danger => colors.danger,
      GPButtonVariant.accent || GPButtonVariant.primary => colors.accentInk,
      _ => colors.onSurfaceVariant,
    };
    return <BoxShadow>[BoxShadow(color: color, spreadRadius: 2)];
  }

  ButtonStyle _style(BuildContext context) {
    final colors = context.colors;
    final foreground = _foreground(colors);
    final background = _background(colors);
    final isBare = widget.variant == GPButtonVariant.outlined || widget.variant == GPButtonVariant.text;

    return ButtonStyle(
      animationDuration: GPDurationTokens.fast,
      elevation: const WidgetStatePropertyAll<double>(0),
      minimumSize: WidgetStatePropertyAll<Size>(Size(0, _height)),
      fixedSize: WidgetStatePropertyAll<Size?>(Size.fromHeight(_height)),
      padding: WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: _horizontalPadding)),
      foregroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) => states.contains(WidgetState.disabled) ? colors.onSurfaceVariant : foreground),
      backgroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) => states.contains(WidgetState.disabled) && !isBare ? colors.surfaceVariant : background),
      overlayColor: WidgetStatePropertyAll<Color>(foreground.withValues(alpha: 0.08)),
      side: widget.variant == GPButtonVariant.outlined
          ? WidgetStateProperty.resolveWith((Set<WidgetState> states) => BorderSide(color: states.contains(WidgetState.disabled) ? colors.outlineVariant : colors.outline))
          : null,
      shape: WidgetStatePropertyAll<OutlinedBorder>(RoundedRectangleBorder(borderRadius: context.radii.borderMd)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    final content = _GPButtonContent(
      label: widget.label,
      labelStyle: _labelStyle(context),
      leading: widget.leading,
      trailing: widget.trailing,
      isLoading: widget.isLoading,
      iconSize: _iconSize,
      gap: _gap,
      spinnerColor: _foreground(context.colors),
    );
    final onPressed = _isEnabled ? widget.onPressed : null;

    Widget button = switch (widget.variant) {
      GPButtonVariant.outlined => OutlinedButton(onPressed: onPressed, style: style, statesController: _statesController, child: content),
      GPButtonVariant.text => TextButton(onPressed: onPressed, style: style, statesController: _statesController, child: content),
      _ => FilledButton(onPressed: onPressed, style: style, statesController: _statesController, child: content),
    };

    if (widget.expanded) button = SizedBox(width: double.infinity, child: button);

    final ring = _focusRing(context.colors);
    if (ring.isEmpty) return button;

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: context.radii.borderMd, boxShadow: ring),
      child: button,
    );
  }
}

class _GPButtonContent extends StatelessWidget {
  const _GPButtonContent({
    required this.label,
    required this.labelStyle,
    required this.leading,
    required this.trailing,
    required this.isLoading,
    required this.iconSize,
    required this.gap,
    required this.spinnerColor,
  });

  final String label;
  final TextStyle labelStyle;
  final Widget? leading;
  final Widget? trailing;
  final bool isLoading;
  final double iconSize;
  final double gap;
  final Color spinnerColor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      if (isLoading)
        SizedBox(
          width: iconSize,
          height: iconSize,
          child: CircularProgressIndicator(strokeWidth: 2, color: spinnerColor),
        )
      else if (leading != null)
        IconTheme.merge(
          data: IconThemeData(size: iconSize),
          child: leading!,
        ),
      if (isLoading || leading != null) SizedBox(width: gap),
      Flexible(
        child: Text(label, style: labelStyle, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
      ),
      if (!isLoading && trailing != null) ...<Widget>[
        SizedBox(width: gap),
        IconTheme.merge(
          data: IconThemeData(size: iconSize),
          child: trailing!,
        ),
      ],
    ],
  );
}
