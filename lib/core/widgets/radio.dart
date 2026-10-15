import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/theme/tokens/dimensions.dart';

/// A 20 circle in a 40 touch ring. Prefer [GPRadioList], whose rows are the target; in a form, `GPSelect` picks one of several instead.
class GPRadio<T> extends StatefulWidget {
  const GPRadio({required this.value, required this.groupValue, required this.onChanged, this.semanticLabel, super.key});

  final T value;
  final T? groupValue;

  /// Null disables the radio.
  final ValueChanged<T>? onChanged;

  final String? semanticLabel;

  @override
  State<GPRadio<T>> createState() => _GPRadioState<T>();
}

class _GPRadioState<T> extends State<GPRadio<T>> {
  bool _pressed = false;
  bool _showFocus = false;

  bool get _enabled => widget.onChanged != null;

  void _select() => widget.onChanged?.call(widget.value);

  @override
  Widget build(BuildContext context) {
    final selected = widget.value == widget.groupValue;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: _enabled,
        onShowFocusHighlight: (bool value) => setState(() => _showFocus = value),
        actions: <Type, Action<Intent>>{ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _select())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _enabled ? _select : null,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
          child: GPRadioMark(selected: selected, enabled: _enabled, pressed: _pressed, showFocus: _showFocus),
        ),
      ),
    );
  }
}

@immutable
class GPRadioOption<T> {
  const GPRadioOption({required this.value, required this.label, this.description, this.enabled = true, this.locale});

  final T value;
  final String label;
  final String? description;
  final bool enabled;

  /// The label's own language, when it is not the UI's: a language picker names each language in itself.
  final Locale? locale;
}

/// Two to five choices that should all be in view, picked by a tap anywhere on a row and applied at once: there is no Save. A card of rows, with an
/// optional [title] above and [helperText] below. The arrow keys move the choice, as they do in any radio group.
class GPRadioList<T> extends StatefulWidget {
  const GPRadioList({required this.label, required this.options, required this.value, required this.onChanged, this.title, this.helperText, super.key});

  /// The group's name for a screen reader; [title] shows it, when given.
  final String label;
  final String? title;
  final List<GPRadioOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String? helperText;

  @override
  State<GPRadioList<T>> createState() => _GPRadioListState<T>();
}

class _GPRadioListState<T> extends State<GPRadioList<T>> {
  late List<FocusNode> _nodes = _makeNodes();

  List<FocusNode> _makeNodes() => <FocusNode>[for (final option in widget.options) FocusNode(debugLabel: 'radio ${option.label}')];

  @override
  void didUpdateWidget(GPRadioList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.options.length != widget.options.length) {
      for (final node in _nodes) {
        node.dispose();
      }
      _nodes = _makeNodes();
    }
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  bool _isEnabled(int index) => widget.onChanged != null && widget.options[index].enabled;

  /// Steps over disabled options and wraps at either end.
  void _move(int from, int step) {
    final count = widget.options.length;
    for (var i = 1; i < count; i++) {
      final index = (from + step * i) % count;
      if (_isEnabled(index)) {
        widget.onChanged!(widget.options[index].value);
        _nodes[index].requestFocus();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    final rows = <Widget>[
      for (var i = 0; i < widget.options.length; i++) ...<Widget>[
        // Inset to the text, so the divider does not cross the column of circles.
        if (i > 0) Divider(height: 1, thickness: 1, indent: 56, color: colors.outlineVariant),
        _GPRadioRow<T>(
          option: widget.options[i],
          selected: widget.options[i].value == widget.value,
          enabled: _isEnabled(i),
          focusNode: _nodes[i],
          onSelect: () => widget.onChanged?.call(widget.options[i].value),
          onMove: (int step) => _move(i, step),
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.title != null)
          Padding(
            padding: EdgeInsets.fromLTRB(spacing.xs, 0, spacing.xs, spacing.sm),
            child: Semantics(
              header: true,
              child: Text(widget.title!, style: context.text.titleSmall.copyWith(color: colors.onSurfaceVariant)),
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
              child: FocusTraversalGroup(child: Column(children: rows)),
            ),
          ),
        ),
        if (widget.helperText != null)
          Padding(
            padding: EdgeInsets.fromLTRB(spacing.xs, spacing.sm, spacing.xs, 0),
            child: Text(widget.helperText!, style: context.text.bodySmall.copyWith(color: colors.onSurfaceVariant)),
          ),
      ],
    );
  }
}

class _GPRadioRow<T> extends StatefulWidget {
  const _GPRadioRow({required this.option, required this.selected, required this.enabled, required this.focusNode, required this.onSelect, required this.onMove});

  final GPRadioOption<T> option;
  final bool selected;
  final bool enabled;
  final FocusNode focusNode;
  final VoidCallback onSelect;
  final ValueChanged<int> onMove;

  @override
  State<_GPRadioRow<T>> createState() => _GPRadioRowState<T>();
}

class _GPRadioRowState<T> extends State<_GPRadioRow<T>> {
  bool _pressed = false;
  bool _hovered = false;
  bool _showFocus = false;

  static const Map<ShortcutActivator, Intent> _arrows = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowDown): _GPRadioMoveIntent(1),
    SingleActivator(LogicalKeyboardKey.arrowRight): _GPRadioMoveIntent(1),
    SingleActivator(LogicalKeyboardKey.arrowUp): _GPRadioMoveIntent(-1),
    SingleActivator(LogicalKeyboardKey.arrowLeft): _GPRadioMoveIntent(-1),
  };

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final option = widget.option;
    final enabled = widget.enabled;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: widget.selected,
      enabled: enabled,
      label: option.label,
      hint: option.description,
      excludeSemantics: true,
      // Excluding the subtree drops the gesture's tap and the detector's focus: both are put back here.
      onTap: enabled ? widget.onSelect : null,
      focusable: enabled,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: widget.focusNode,
        shortcuts: _arrows,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (bool value) => setState(() => _showFocus = value),
        onShowHoverHighlight: (bool value) => setState(() => _hovered = value),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onSelect()),
          _GPRadioMoveIntent: CallbackAction<_GPRadioMoveIntent>(onInvoke: (_GPRadioMoveIntent intent) => widget.onMove(intent.step)),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? widget.onSelect : null,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          child: AnimatedContainer(
            duration: GPDurationTokens.fast,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            color: _hovered && enabled ? colors.onSurface.withValues(alpha: 0.04) : Colors.transparent,
            child: Row(
              children: <Widget>[
                GPRadioMark(selected: widget.selected, enabled: enabled, pressed: _pressed, showFocus: _showFocus),
                SizedBox(width: context.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        option.label,
                        locale: option.locale,
                        // Weight, not a fill: a tinted row would read as the selected item of a GPSelect.
                        style: context.text.bodyLarge.copyWith(
                          color: enabled ? colors.onSurface : colors.onSurfaceVariant,
                          fontWeight: widget.selected ? FontWeight.w500 : null,
                        ),
                      ),
                      if (option.description != null) ...<Widget>[
                        SizedBox(height: context.spacing.xxs),
                        Text(option.description!, style: context.text.bodySmall.copyWith(color: colors.onSurfaceVariant)),
                      ],
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

class _GPRadioMoveIntent extends Intent {
  const _GPRadioMoveIntent(this.step);

  final int step;
}

/// The painted part only: the 40 ring that carries the press overlay and the focus ring, and the 20 circle inside it.
class GPRadioMark extends StatelessWidget {
  const GPRadioMark({required this.selected, required this.enabled, this.pressed = false, this.showFocus = false, super.key});

  final bool selected;
  final bool enabled;
  final bool pressed;
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: pressed && enabled ? colors.onSurface.withValues(alpha: 0.08) : Colors.transparent,
        boxShadow: showFocus ? <BoxShadow>[BoxShadow(color: colors.accentInk, spreadRadius: 2)] : const <BoxShadow>[],
      ),
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: GPDurationTokens.fast,
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: edge, width: 2),
        ),
        alignment: Alignment.center,
        child: AnimatedScale(
          scale: selected ? 1 : 0,
          duration: GPDurationTokens.fast,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: edge),
          ),
        ),
      ),
    );
  }
}
