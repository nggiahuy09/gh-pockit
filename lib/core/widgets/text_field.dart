import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/localization_scope.dart';
import '../theme/theme_context.dart';
import 'field.dart';
import 'utf16_length_limit.dart';

final class GPTextField extends StatefulWidget {
  const GPTextField({
    super.key,
    this.inputFormatters,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.leading,
    this.textAlign = TextAlign.start,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.errorText,
    this.helperText,
    this.hintText,
    this.initialValue,
    this.label,
    this.prefixText,
    this.suffixText,
    this.maxLength,
    this.maxLines = 1,
    this.autofocus = false,
    this.clearable = false,
    this.enabled = true,
    this.enableInteractiveSelection = true,
    this.tabularFigures = false,
    this.onChanged,
    this.onSubmitted,
  }) : assert(controller == null || initialValue == null, 'Pass a controller or an initialValue, not both.');

  final List<TextInputFormatter>? inputFormatters;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final IconData? leading;
  final TextAlign textAlign;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final String? errorText;
  final String? helperText;
  final String? hintText;

  /// Read once, when the field builds its own controller.
  final String? initialValue;

  final String? label;

  /// Before and after the text, in the hint color: a currency symbol, a unit.
  final String? prefixText;

  final String? suffixText;

  /// In UTF-16 code units, the unit the entities count in; also turns on the counter.
  final int? maxLength;

  /// Null grows with the text.
  final int? maxLines;

  final bool autofocus;

  /// Shows a clear button while focused and not empty.
  final bool clearable;

  final bool enabled;
  final bool enableInteractiveSelection;
  final bool tabularFigures;
  final void Function(String text)? onChanged;
  final void Function(String text)? onSubmitted;

  @override
  State<GPTextField> createState() => _GPTextFieldState();
}

final class _GPTextFieldState extends State<GPTextField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;

  TextEditingController get _controller => widget.controller ?? (_ownController ??= TextEditingController(text: widget.initialValue));

  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleChange);
    _focusNode.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(GPTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_handleChange);
      _controller.addListener(_handleChange);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_handleChange);
      _focusNode.addListener(_handleChange);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChange);
    _focusNode.removeListener(_handleChange);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _handleChange() => setState(() {});

  void _handleClear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final enabled = widget.enabled;
    final leading = widget.leading;
    final prefixText = widget.prefixText;
    final suffixText = widget.suffixText;
    final maxLength = widget.maxLength;
    final state = !enabled
        ? GPFieldState.disabled
        : widget.errorText != null
        ? GPFieldState.error
        : _focusNode.hasFocus
        ? GPFieldState.active
        : GPFieldState.idle;
    final showsClear = widget.clearable && enabled && _focusNode.hasFocus && _controller.text.isNotEmpty;
    final affixStyle = text.bodyLarge.copyWith(color: colors.onSurfaceVariant);

    return GPField(
      counterText: maxLength == null ? null : '${_controller.text.length}/$maxLength',
      errorText: widget.errorText,
      helperText: widget.helperText,
      label: widget.label,
      mergeSemantics: true,
      child: GestureDetector(
        // The box is taller than the line of text; a tap on its padding still lands in the field.
        onTap: enabled ? _focusNode.requestFocus : null,
        child: GPFieldBox(
          state: state,
          child: Row(
            children: [
              if (leading != null) ...[
                Icon(leading, size: 20.0, color: colors.onSurfaceVariant),
                SizedBox(width: context.spacing.smd),
              ],
              if (prefixText != null) ...[
                Text(prefixText, style: affixStyle),
                SizedBox(width: context.spacing.xs),
              ],
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: enabled,
                  autofocus: widget.autofocus,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  textCapitalization: widget.textCapitalization,
                  textAlign: widget.textAlign,
                  maxLines: widget.maxLines,
                  enableInteractiveSelection: widget.enableInteractiveSelection,
                  inputFormatters: [...?widget.inputFormatters, if (maxLength != null) GPUtf16LengthLimitingFormatter(maxLength)],
                  style: text.bodyLarge.copyWith(
                    color: enabled ? colors.onSurface : colors.onSurfaceVariant,
                    fontFeatures: widget.tabularFigures ? const [FontFeature.tabularFigures()] : null,
                  ),
                  cursorColor: colors.accentInk,
                  onTapOutside: (_) => _focusNode.unfocus(),
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  // 52 of content plus a 2px edge on each side is the box's 56, so the active edge does not grow it.
                  decoration: InputDecoration.collapsed(
                    hintText: widget.hintText,
                    hintStyle: affixStyle,
                  ).copyWith(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 14.0)),
                ),
              ),
              if (suffixText != null) ...[
                SizedBox(width: context.spacing.smd),
                Text(suffixText, style: affixStyle),
              ],
              if (showsClear)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4.0),
                  child: SizedBox.square(
                    dimension: 40.0,
                    child: IconButton(
                      onPressed: _handleClear,
                      tooltip: context.l10n.widgets.clearText,
                      padding: EdgeInsets.zero,
                      iconSize: 20.0,
                      color: colors.onSurfaceVariant,
                      icon: const Icon(Icons.cancel_outlined),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
