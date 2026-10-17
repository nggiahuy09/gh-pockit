import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/theme/tokens/dimensions.dart';
import 'package:ghpockit/core/widgets/field.dart';
import 'package:ghpockit/core/widgets/sheet.dart';

@immutable
class GPSelectOption<T> {
  const GPSelectOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Picks one of [options]. Up to [menuLimit] open as a menu right under the field, more as a bottom sheet titled by [label].
class GPSelect<T> extends StatefulWidget {
  const GPSelect({required this.options, required this.value, required this.onChanged, this.label, this.placeholder, this.helperText, this.errorText, this.focusNode, super.key});

  static const int menuLimit = 5;

  final List<GPSelectOption<T>> options;

  /// Null shows [placeholder].
  final T? value;

  /// Null disables the field.
  final ValueChanged<T>? onChanged;

  final String? label;
  final String? placeholder;
  final String? helperText;
  final String? errorText;
  final FocusNode? focusNode;

  @override
  State<GPSelect<T>> createState() => _GPSelectState<T>();
}

class _GPSelectState<T> extends State<GPSelect<T>> {
  bool _isOpen = false;

  GPSelectOption<T>? get _selected {
    for (final option in widget.options) {
      if (option.value == widget.value) return option;
    }
    return null;
  }

  Future<void> _open() async {
    setState(() => _isOpen = true);
    final picked = widget.options.length <= GPSelect.menuLimit ? await _openMenu() : await _openSheet();
    if (!mounted) return;

    setState(() => _isOpen = false);
    if (picked != null && picked.value != widget.value) widget.onChanged?.call(picked.value);
  }

  Future<GPSelectOption<T>?> _openMenu() {
    final box = context.findRenderObject()! as RenderBox;
    // The whole field, help line included: the menu never covers the error it is about to fix.
    final anchor = box.localToGlobal(Offset.zero) & box.size;

    return Navigator.of(context).push(
      _GPSelectMenuRoute<T>(
        anchor: anchor,
        options: widget.options,
        selected: widget.value,
        label: widget.label,
        barrierLabel: context.l10n.widgets.dismiss,
        capturedThemes: InheritedTheme.capture(from: context, to: Navigator.of(context).context),
      ),
    );
  }

  Future<GPSelectOption<T>?> _openSheet() => showGPSheet<GPSelectOption<T>>(
    context: context,
    title: widget.label,
    builder: (BuildContext context) => _GPSelectList<T>(options: widget.options, selected: widget.value, inSheet: true, label: widget.label),
  );

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return GPPickerField(
      onTap: widget.onChanged == null ? null : _open,
      label: widget.label,
      value: selected?.label,
      placeholder: widget.placeholder,
      leading: selected?.icon,
      isOpen: _isOpen,
      helperText: widget.helperText,
      errorText: widget.errorText,
      focusNode: widget.focusNode,
    );
  }
}

class _GPSelectMenuRoute<T> extends PopupRoute<GPSelectOption<T>> {
  _GPSelectMenuRoute({required this.anchor, required this.options, required this.selected, required this.label, required this.barrierLabel, required this.capturedThemes});

  final Rect anchor;
  final List<GPSelectOption<T>> options;
  final T? selected;
  final String? label;
  final CapturedThemes capturedThemes;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => GPDurationTokens.fast;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => capturedThemes.wrap(
    FadeTransition(
      opacity: animation,
      child: CustomSingleChildLayout(
        delegate: _GPSelectMenuLayout(anchor: anchor, padding: MediaQuery.paddingOf(context) + MediaQuery.viewInsetsOf(context)),
        child: _GPSelectMenu<T>(options: options, selected: selected, label: label),
      ),
    ),
  );
}

/// Under the field and as wide as it, never over it: flips above when the space below is too short.
class _GPSelectMenuLayout extends SingleChildLayoutDelegate {
  _GPSelectMenuLayout({required this.anchor, required this.padding});

  static const double gap = 8;

  final Rect anchor;
  final EdgeInsets padding;

  double _below(Size size) => size.height - padding.bottom - anchor.bottom - gap;
  double _above(Size size) => anchor.top - padding.top - gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    return BoxConstraints.tightFor(width: anchor.width).copyWith(minHeight: 0, maxHeight: math.max(0, math.max(_below(size), _above(size))));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final fitsBelow = childSize.height <= _below(size) || _below(size) >= _above(size);
    return Offset(anchor.left, fitsBelow ? anchor.bottom + gap : anchor.top - gap - childSize.height);
  }

  @override
  bool shouldRelayout(_GPSelectMenuLayout oldDelegate) => anchor != oldDelegate.anchor || padding != oldDelegate.padding;
}

class _GPSelectMenu<T> extends StatelessWidget {
  const _GPSelectMenu({required this.options, required this.selected, required this.label});

  final List<GPSelectOption<T>> options;
  final T? selected;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Dark has no shadow to lift the menu: it sits a step lighter than the surface, edged in outline.
    final dark = context.isDark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? colors.surfaceVariant : colors.surface,
        borderRadius: context.radii.borderLg,
        border: Border.all(color: dark ? colors.outline : colors.outlineVariant),
        boxShadow: context.shadows.large,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: _GPSelectList<T>(options: options, selected: selected, inSheet: false, label: label),
        ),
      ),
    );
  }
}

class _GPSelectList<T> extends StatelessWidget {
  const _GPSelectList({required this.options, required this.selected, required this.inSheet, required this.label});

  final List<GPSelectOption<T>> options;
  final T? selected;
  final bool inSheet;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    explicitChildNodes: true,
    child: ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: options.length,
      separatorBuilder: (_, _) => SizedBox(height: context.spacing.xxs),
      itemBuilder: (BuildContext context, int index) {
        final option = options[index];
        return _GPSelectOptionTile<T>(option: option, isSelected: option.value == selected, inSheet: inSheet);
      },
    ),
  );
}

class _GPSelectOptionTile<T> extends StatelessWidget {
  const _GPSelectOptionTile({required this.option, required this.isSelected, required this.inSheet});

  final GPSelectOption<T> option;
  final bool isSelected;
  final bool inSheet;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final iconColor = isSelected ? colors.onAccentContainer : colors.onSurfaceVariant;

    return Semantics(
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: isSelected ? colors.accentContainer : Colors.transparent,
        borderRadius: context.radii.borderMd,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(option),
          borderRadius: context.radii.borderMd,
          overlayColor: WidgetStatePropertyAll<Color>(colors.onSurface.withValues(alpha: 0.06)),
          child: Container(
            constraints: BoxConstraints(minHeight: inSheet ? 52 : 48),
            padding: EdgeInsets.symmetric(horizontal: inSheet ? context.spacing.md : context.spacing.smd),
            child: Row(
              children: <Widget>[
                if (option.icon != null) ...<Widget>[
                  Icon(option.icon, size: 20, color: iconColor),
                  SizedBox(width: context.spacing.smd),
                ],
                Expanded(
                  child: Text(
                    option.label,
                    style: context.text.bodyLarge.copyWith(color: colors.onSurface, fontWeight: isSelected ? FontWeight.w500 : null),
                  ),
                ),
                SizedBox(width: context.spacing.smd),
                // Kept in the layout when hidden, so a row's text does not move when it becomes the selected one.
                Visibility.maintain(
                  visible: isSelected,
                  child: Icon(Icons.check, size: 20, color: colors.onAccentContainer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
