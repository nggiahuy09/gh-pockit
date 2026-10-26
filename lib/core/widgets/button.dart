import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/dimensions.dart';

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
  /// 40: under Android's 48 touch target, so only inside a row that is itself tappable.
  small,

  medium,
  large,
}

final class GPButton extends StatefulWidget {
  const GPButton({
    super.key,
    this.leading,
    this.trailing,
    this.size = GPButtonSize.medium,
    this.variant = GPButtonVariant.primary,
    required this.label,
    this.autofocus = false,
    this.expanded = false,
    this.isLoading = false,
    this.onPressed,
  });

  /// Replaced by the spinner while [isLoading]. Without one the button grows by the spinner's width, so make a form's submit button [expanded].
  final Widget? leading;

  /// Hidden while [isLoading].
  final Widget? trailing;

  final GPButtonSize size;
  final GPButtonVariant variant;
  final String label;
  final bool autofocus;
  final bool expanded;

  /// Shows a spinner and refuses input.
  final bool isLoading;

  final void Function()? onPressed;

  @override
  State<GPButton> createState() => _GPButtonState();
}

final class _GPButtonState extends State<GPButton> {
  // The Material button updates these during build, where setState throws: hence the post-frame listener and the deferred setState.
  final _statesController = WidgetStatesController();

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  double get _height => switch (widget.size) {
    GPButtonSize.small => 40.0,
    GPButtonSize.medium => 48.0,
    GPButtonSize.large => 56.0,
  };

  double get _horizontalPadding => switch (widget.size) {
    GPButtonSize.small => 14.0,
    GPButtonSize.medium => 20.0,
    GPButtonSize.large => 24.0,
  };

  double get _iconSize => switch (widget.size) {
    GPButtonSize.small => 16.0,
    GPButtonSize.medium || GPButtonSize.large => 20.0,
  };

  double get _gap => widget.size == GPButtonSize.small ? 6.0 : 8.0;

  bool get _isBare => widget.variant == GPButtonVariant.outlined || widget.variant == GPButtonVariant.text;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _statesController.addListener(_handleStatesChange) : null);
  }

  @override
  void dispose() {
    _statesController
      ..removeListener(_handleStatesChange)
      ..dispose();
    super.dispose();
  }

  void _handleStatesChange() {
    if (!mounted) return;

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() {}) : null);
    } else {
      setState(() {});
    }
  }

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
    final states = _statesController.value;
    if (!_isEnabled || (!states.contains(WidgetState.focused) && !states.contains(WidgetState.pressed))) return const [];

    final color = switch (widget.variant) {
      GPButtonVariant.primary || GPButtonVariant.accent => colors.accentInk,
      GPButtonVariant.tonal || GPButtonVariant.outlined || GPButtonVariant.text => colors.onSurfaceVariant,
      GPButtonVariant.danger => colors.danger,
    };
    return [BoxShadow(color: color, spreadRadius: 2.0)];
  }

  ButtonStyle _style(BuildContext context) {
    final colors = context.colors;
    final foreground = _foreground(colors);
    final background = _background(colors);

    return ButtonStyle(
      animationDuration: GPDurationTokens.fast,
      elevation: const WidgetStatePropertyAll(0.0),
      minimumSize: WidgetStatePropertyAll(Size(0.0, _height)),
      fixedSize: WidgetStatePropertyAll(Size.fromHeight(_height)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: _horizontalPadding)),
      foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? colors.onSurfaceVariant : foreground),
      backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) && !_isBare ? colors.surfaceVariant : background),
      overlayColor: WidgetStatePropertyAll(foreground.withValues(alpha: 0.08)),
      side: widget.variant == GPButtonVariant.outlined
          ? WidgetStateProperty.resolveWith((states) => BorderSide(color: states.contains(WidgetState.disabled) ? colors.outlineVariant : colors.outline))
          : null,
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: context.radii.borderMd)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    final onPressed = _isEnabled ? widget.onPressed : null;
    final content = _GPButtonContent(
      labelStyle: _labelStyle(context),
      leading: widget.leading,
      spinnerColor: _foreground(context.colors),
      trailing: widget.trailing,
      label: widget.label,
      gap: _gap,
      iconSize: _iconSize,
      isLoading: widget.isLoading,
    );
    final button = switch (widget.variant) {
      GPButtonVariant.outlined => OutlinedButton(onPressed: onPressed, style: style, autofocus: widget.autofocus, statesController: _statesController, child: content),
      GPButtonVariant.text => TextButton(onPressed: onPressed, style: style, autofocus: widget.autofocus, statesController: _statesController, child: content),
      GPButtonVariant.primary || GPButtonVariant.accent || GPButtonVariant.tonal || GPButtonVariant.danger => FilledButton(
        onPressed: onPressed,
        style: style,
        autofocus: widget.autofocus,
        statesController: _statesController,
        child: content,
      ),
    };

    // Always wrapped, ring or not: inserting the box on press would remount the button and cancel the tap still in flight.
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: context.radii.borderMd, boxShadow: _focusRing(context.colors)),
      child: widget.expanded ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

final class _GPButtonContent extends StatelessWidget {
  const _GPButtonContent({
    required this.labelStyle,
    required this.leading,
    required this.spinnerColor,
    required this.trailing,
    required this.label,
    required this.gap,
    required this.iconSize,
    required this.isLoading,
  });

  final TextStyle labelStyle;
  final Widget? leading;
  final Color spinnerColor;
  final Widget? trailing;
  final String label;
  final double gap;
  final double iconSize;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    final trailing = this.trailing;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: gap,
      children: [
        if (isLoading)
          SizedBox.square(
            dimension: iconSize,
            child: CircularProgressIndicator(strokeWidth: 2.0, color: spinnerColor),
          )
        else if (leading != null)
          IconTheme.merge(
            data: IconThemeData(size: iconSize),
            child: leading,
          ),
        Flexible(
          child: Text(label, style: labelStyle, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        ),
        if (!isLoading && trailing != null)
          IconTheme.merge(
            data: IconThemeData(size: iconSize),
            child: trailing,
          ),
      ],
    );
  }
}
