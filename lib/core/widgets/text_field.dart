import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/widgets/field.dart';
import 'package:ghpockit/core/widgets/utf16_length_limit.dart';

class GPTextField extends StatefulWidget {
  const GPTextField({
    this.controller,
    this.initialValue,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.leading,
    this.prefixText,
    this.suffixText,
    this.maxLength,
    this.clearable = false,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.textAlign = TextAlign.start,
    this.tabularFigures = false,
    this.maxLines = 1,
    this.enableInteractiveSelection = true,
    this.onChanged,
    this.onSubmitted,
    super.key,
  }) : assert(controller == null || initialValue == null, 'Pass a controller or an initialValue, not both.');

  final TextEditingController? controller;

  /// Read once, when the field builds its own controller.
  final String? initialValue;

  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final IconData? leading;

  /// Before and after the text, in the hint color: a currency symbol, a unit.
  final String? prefixText;
  final String? suffixText;

  /// In UTF-16 code units, the unit the entities count in; also turns on the counter.
  final int? maxLength;

  /// Shows a clear button while focused and not empty.
  final bool clearable;

  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final TextAlign textAlign;
  final bool tabularFigures;

  /// Null grows with the text.
  final int? maxLines;

  final bool enableInteractiveSelection;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<GPTextField> createState() => _GPTextFieldState();
}

class _GPTextFieldState extends State<GPTextField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;

  TextEditingController get _controller => widget.controller ?? (_ownController ??= TextEditingController(text: widget.initialValue));
  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    _focusNode.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(GPTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_rebuild);
      _controller.addListener(_rebuild);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_rebuild);
      _focusNode.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _focusNode.removeListener(_rebuild);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final enabled = widget.enabled;
    final state = !enabled
        ? GPFieldState.disabled
        : widget.errorText != null
        ? GPFieldState.error
        : _focusNode.hasFocus
        ? GPFieldState.active
        : GPFieldState.idle;
    final showClear = widget.clearable && enabled && _focusNode.hasFocus && _controller.text.isNotEmpty;
    final maxLength = widget.maxLength;
    final style = text.bodyLarge.copyWith(
      color: enabled ? colors.onSurface : colors.onSurfaceVariant,
      fontFeatures: widget.tabularFigures ? const <FontFeature>[FontFeature.tabularFigures()] : null,
    );

    return GPField(
      label: widget.label,
      helperText: widget.helperText,
      errorText: widget.errorText,
      counterText: maxLength == null ? null : '${_controller.text.length}/$maxLength',
      mergeSemantics: true,
      child: GestureDetector(
        // The box is taller than the line of text; a tap on its padding still lands in the field.
        onTap: enabled ? _focusNode.requestFocus : null,
        child: GPFieldBox(
          state: state,
          child: Row(
            children: <Widget>[
              if (widget.leading != null) ...<Widget>[
                Icon(widget.leading, size: 20, color: colors.onSurfaceVariant),
                SizedBox(width: context.spacing.smd),
              ],
              if (widget.prefixText != null) ...<Widget>[
                Text(widget.prefixText!, style: text.bodyLarge.copyWith(color: colors.onSurfaceVariant)),
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
                  inputFormatters: <TextInputFormatter>[...?widget.inputFormatters, if (maxLength != null) GPUtf16LengthLimitingFormatter(maxLength)],
                  style: style,
                  cursorColor: colors.accentInk,
                  onTapOutside: (_) => _focusNode.unfocus(),
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  decoration: InputDecoration.collapsed(
                    hintText: widget.hintText,
                    hintStyle: text.bodyLarge.copyWith(color: colors.onSurfaceVariant),
                    // 52 of content plus a 2px edge on each side is the box's 56, so the active edge does not grow it.
                  ).copyWith(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              if (widget.suffixText != null) ...<Widget>[
                SizedBox(width: context.spacing.smd),
                Text(widget.suffixText!, style: text.bodyLarge.copyWith(color: colors.onSurfaceVariant)),
              ],
              if (showClear)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4),
                  child: SizedBox.square(
                    dimension: 40,
                    child: IconButton(
                      onPressed: _clear,
                      tooltip: context.l10n.widgets.clearText,
                      padding: EdgeInsets.zero,
                      iconSize: 20,
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
