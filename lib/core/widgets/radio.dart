import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme_context.dart';
import '../theme/tokens/dimensions.dart';

/// A 20 circle in a 40 touch ring. Prefer [GPRadioList], whose rows are the target; in a form, `GPSelect` picks one of several instead.
final class GPRadio<T> extends StatefulWidget {
  const GPRadio({super.key, required this.groupValue, required this.value, this.semanticLabel, required this.onChanged});

  final T? groupValue;
  final T value;
  final String? semanticLabel;

  final void Function(T value)? onChanged;

  @override
  State<GPRadio<T>> createState() => _GPRadioState<T>();
}

final class _GPRadioState<T> extends State<GPRadio<T>> {
  var _isPressed = false;
  var _showsFocus = false;

  bool get _isEnabled => widget.onChanged != null;

  void _handleSelect() => widget.onChanged?.call(widget.value);

  @override
  Widget build(BuildContext context) {
    final selected = widget.value == widget.groupValue;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: _isEnabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: _isEnabled,
        onShowFocusHighlight: (value) => setState(() => _showsFocus = value),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _handleSelect())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _isEnabled ? _handleSelect : null,
          onTapDown: _isEnabled ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: _isEnabled ? (_) => setState(() => _isPressed = false) : null,
          onTapCancel: _isEnabled ? () => setState(() => _isPressed = false) : null,
          child: GPRadioMark(enabled: _isEnabled, pressed: _isPressed, selected: selected, showFocus: _showsFocus),
        ),
      ),
    );
  }
}

@immutable
final class GPRadioOption<T> {
  const GPRadioOption({this.locale, required this.value, this.description, required this.label, this.enabled = true});

  /// The label's own language, when it is not the UI's: a language picker names each language in itself.
  final Locale? locale;

  final T value;
  final String? description;
  final String label;
  final bool enabled;
}

/// Two to five choices that should all be in view, picked by a tap anywhere on a row and applied at once: there is no Save. The arrow keys move the
/// choice, as they do in any radio group.
final class GPRadioList<T> extends StatefulWidget {
  const GPRadioList({super.key, required this.options, required this.value, this.helperText, required this.label, this.title, required this.onChanged});

  final List<GPRadioOption<T>> options;
  final T? value;
  final String? helperText;

  /// The group's name for a screen reader; [title] shows it, when given.
  final String label;

  final String? title;
  final void Function(T value)? onChanged;

  @override
  State<GPRadioList<T>> createState() => _GPRadioListState<T>();
}

final class _GPRadioListState<T> extends State<GPRadioList<T>> {
  late List<FocusNode> _nodes = _makeNodes();

  @override
  void didUpdateWidget(GPRadioList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.options.length == widget.options.length) return;

    _disposeNodes();
    _nodes = _makeNodes();
  }

  @override
  void dispose() {
    _disposeNodes();
    super.dispose();
  }

  List<FocusNode> _makeNodes() => [for (final option in widget.options) FocusNode(debugLabel: 'radio ${option.label}')];

  void _disposeNodes() {
    for (final node in _nodes) {
      node.dispose();
    }
  }

  bool _isEnabled(int index) => widget.onChanged != null && widget.options[index].enabled;

  /// Steps over disabled options and wraps at either end.
  void _handleMove({required int from, required int step}) {
    final count = widget.options.length;
    for (var i = 1; i < count; i++) {
      final index = (from + step * i) % count;
      if (_isEnabled(index)) {
        widget.onChanged?.call(widget.options[index].value);
        _nodes[index].requestFocus();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final title = widget.title;
    final helperText = widget.helperText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: EdgeInsets.fromLTRB(spacing.xs, 0.0, spacing.xs, spacing.sm),
            child: Semantics(
              header: true,
              child: Text(title, style: context.text.titleSmall.copyWith(color: colors.onSurfaceVariant)),
            ),
          ),
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: widget.label,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: colors.surface, borderRadius: context.radii.borderLg, boxShadow: context.shadows.small),
            child: Material(
              type: MaterialType.transparency,
              child: FocusTraversalGroup(
                child: Column(
                  children: [
                    for (var i = 0; i < widget.options.length; i++) ...[
                      // Inset to the text, so the divider does not cross the column of circles.
                      if (i > 0) Divider(height: 1.0, thickness: 1.0, indent: 56.0, color: colors.outlineVariant),
                      _GPRadioRow(
                        focusNode: _nodes[i],
                        option: widget.options[i],
                        isEnabled: _isEnabled(i),
                        isSelected: widget.options[i].value == widget.value,
                        onSelect: () => widget.onChanged?.call(widget.options[i].value),
                        onMove: (step) => _handleMove(from: i, step: step),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (helperText != null)
          Padding(
            padding: EdgeInsets.fromLTRB(spacing.xs, spacing.sm, spacing.xs, 0.0),
            child: Text(helperText, style: context.text.bodySmall.copyWith(color: colors.onSurfaceVariant)),
          ),
      ],
    );
  }
}

final class _GPRadioRow<T> extends StatefulWidget {
  const _GPRadioRow({required this.focusNode, required this.option, required this.isEnabled, required this.isSelected, required this.onSelect, required this.onMove});

  final FocusNode focusNode;
  final GPRadioOption<T> option;
  final bool isEnabled;
  final bool isSelected;
  final void Function() onSelect;
  final void Function(int step) onMove;

  @override
  State<_GPRadioRow<T>> createState() => _GPRadioRowState<T>();
}

final class _GPRadioRowState<T> extends State<_GPRadioRow<T>> {
  static const _arrows = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowDown): _GPRadioMoveIntent(1),
    SingleActivator(LogicalKeyboardKey.arrowRight): _GPRadioMoveIntent(1),
    SingleActivator(LogicalKeyboardKey.arrowUp): _GPRadioMoveIntent(-1),
    SingleActivator(LogicalKeyboardKey.arrowLeft): _GPRadioMoveIntent(-1),
  };

  var _isHovered = false;
  var _isPressed = false;
  var _showsFocus = false;

  void _setPressed(bool isPressed) {
    if (_isPressed != isPressed) setState(() => _isPressed = isPressed);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final option = widget.option;
    final description = option.description;
    final enabled = widget.isEnabled;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: widget.isSelected,
      enabled: enabled,
      label: option.label,
      hint: description,
      excludeSemantics: true,
      // Excluding the subtree drops the gesture's tap and the detector's focus: both are put back here.
      onTap: enabled ? widget.onSelect : null,
      focusable: enabled,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: widget.focusNode,
        shortcuts: _arrows,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (value) => setState(() => _showsFocus = value),
        onShowHoverHighlight: (value) => setState(() => _isHovered = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onSelect.call()),
          _GPRadioMoveIntent: CallbackAction<_GPRadioMoveIntent>(onInvoke: (intent) => widget.onMove.call(intent.step)),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? widget.onSelect : null,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          child: AnimatedContainer(
            duration: GPDurationTokens.fast,
            constraints: const BoxConstraints(minHeight: 56.0),
            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 16.0, 8.0),
            color: _isHovered && enabled ? colors.onSurface.withValues(alpha: 0.04) : Colors.transparent,
            child: Row(
              spacing: context.spacing.sm,
              children: [
                GPRadioMark(enabled: enabled, pressed: _isPressed, selected: widget.isSelected, showFocus: _showsFocus),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: context.spacing.xxs,
                    children: [
                      Text(
                        option.label,
                        locale: option.locale,
                        // Weight, not a fill: a tinted row would read as the selected item of a GPSelect.
                        style: context.text.bodyLarge.copyWith(color: enabled ? colors.onSurface : colors.onSurfaceVariant, fontWeight: widget.isSelected ? FontWeight.w500 : null),
                      ),
                      if (description != null) Text(description, style: context.text.bodySmall.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _GPRadioMoveIntent extends Intent {
  const _GPRadioMoveIntent(this.step);

  final int step;
}

/// The painted part only: the 40 ring that carries the press overlay and the focus ring, and the 20 circle inside it.
final class GPRadioMark extends StatelessWidget {
  const GPRadioMark({super.key, required this.enabled, this.pressed = false, required this.selected, this.showFocus = false});

  final bool enabled;
  final bool pressed;
  final bool selected;
  final bool showFocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The 2px onSurfaceVariant edge is what clears 3:1 against the ground; selected takes the ink of a switch that is on.
    final edge = !enabled
        ? colors.outline
        : selected
        ? colors.primary
        : colors.onSurfaceVariant;

    return AnimatedContainer(
      duration: GPDurationTokens.fast,
      width: 40.0,
      height: 40.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: pressed && enabled ? colors.onSurface.withValues(alpha: 0.08) : Colors.transparent,
        boxShadow: showFocus ? [BoxShadow(color: colors.accentInk, spreadRadius: 2.0)] : const [],
      ),
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: GPDurationTokens.fast,
        width: 20.0,
        height: 20.0,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: edge, width: 2.0),
        ),
        alignment: Alignment.center,
        child: AnimatedScale(
          scale: selected ? 1.0 : 0.0,
          duration: GPDurationTokens.fast,
          child: SizedBox.square(
            dimension: 10.0,
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: edge),
            ),
          ),
        ),
      ),
    );
  }
}
