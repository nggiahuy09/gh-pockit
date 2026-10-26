import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../localization/localization_scope.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/dimensions.dart';
import 'field.dart';
import 'sheet.dart';

@immutable
final class GPSelectOption<T> {
  const GPSelectOption({this.icon, required this.value, required this.label});

  final IconData? icon;
  final T value;
  final String label;
}

/// Up to [menuLimit] options open as a menu right under the field, more as a bottom sheet titled by [label].
final class GPSelect<T> extends StatefulWidget {
  const GPSelect({super.key, required this.options, this.focusNode, required this.value, this.errorText, this.helperText, this.label, this.placeholder, required this.onChanged});

  final List<GPSelectOption<T>> options;
  final FocusNode? focusNode;

  /// Null shows [placeholder].
  final T? value;

  final String? errorText;
  final String? helperText;
  final String? label;
  final String? placeholder;

  final void Function(T value)? onChanged;

  static const menuLimit = 5;

  @override
  State<GPSelect<T>> createState() => _GPSelectState<T>();
}

final class _GPSelectState<T> extends State<GPSelect<T>> {
  var _isOpen = false;

  GPSelectOption<T>? get _selected => widget.options.where((option) => option.value == widget.value).firstOrNull;

  Future<void> _handleOpen() async {
    setState(() => _isOpen = true);
    final picked = widget.options.length <= GPSelect.menuLimit ? await _openMenu() : await _openSheet();
    if (!mounted) return;

    setState(() => _isOpen = false);
    if (picked != null && picked.value != widget.value) widget.onChanged?.call(picked.value);
  }

  Future<GPSelectOption<T>?> _openMenu() {
    final box = context.findRenderObject()! as RenderBox;
    final navigator = Navigator.of(context);

    return navigator.push(
      _GPSelectMenuRoute(
        options: widget.options,
        // The whole field, help line included: the menu never covers the error it is about to fix.
        anchor: box.localToGlobal(Offset.zero) & box.size,
        capturedThemes: InheritedTheme.capture(from: context, to: navigator.context),
        selected: widget.value,
        barrierLabel: context.l10n.widgets.dismiss,
        label: widget.label,
      ),
    );
  }

  Future<GPSelectOption<T>?> _openSheet() => showGPSheet(
    context: context,
    title: widget.label,
    builder: (_) => _GPSelectList(options: widget.options, selected: widget.value, label: widget.label, isInSheet: true),
  );

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return GPPickerField(
      focusNode: widget.focusNode,
      leading: selected?.icon,
      errorText: widget.errorText,
      helperText: widget.helperText,
      label: widget.label,
      placeholder: widget.placeholder,
      value: selected?.label,
      isOpen: _isOpen,
      onTap: widget.onChanged == null ? null : _handleOpen,
    );
  }
}

final class _GPSelectMenuRoute<T> extends PopupRoute<GPSelectOption<T>> {
  _GPSelectMenuRoute({
    required this.options,
    required this.anchor,
    required this.capturedThemes,
    required this.selected,
    required this.barrierLabel,
    required this.label,
  });

  final List<GPSelectOption<T>> options;
  final Rect anchor;
  final CapturedThemes capturedThemes;
  final T? selected;

  @override
  final String barrierLabel;

  final String? label;

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
        child: _GPSelectMenu(options: options, selected: selected, label: label),
      ),
    ),
  );
}

/// Under the field and as wide as it, never over it: flips above when the space below is too short.
final class _GPSelectMenuLayout extends SingleChildLayoutDelegate {
  _GPSelectMenuLayout({required this.anchor, required this.padding});

  final Rect anchor;
  final EdgeInsets padding;

  static const gap = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    return BoxConstraints.tightFor(width: anchor.width).copyWith(minHeight: 0.0, maxHeight: math.max(0.0, math.max(_below(size), _above(size))));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final fitsBelow = childSize.height <= _below(size) || _below(size) >= _above(size);
    return Offset(anchor.left, fitsBelow ? anchor.bottom + gap : anchor.top - gap - childSize.height);
  }

  @override
  bool shouldRelayout(_GPSelectMenuLayout oldDelegate) => anchor != oldDelegate.anchor || padding != oldDelegate.padding;

  double _below(Size size) => size.height - padding.bottom - anchor.bottom - gap;

  double _above(Size size) => anchor.top - padding.top - gap;
}

final class _GPSelectMenu<T> extends StatelessWidget {
  const _GPSelectMenu({required this.options, required this.selected, required this.label});

  final List<GPSelectOption<T>> options;
  final T? selected;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Dark has no shadow to lift the menu: it sits a step lighter than the surface, edged in outline.
    final isDark = context.isDark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceVariant : colors.surface,
        borderRadius: context.radii.borderLg,
        border: Border.all(color: isDark ? colors.outline : colors.outlineVariant),
        boxShadow: context.shadows.large,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: _GPSelectList(options: options, selected: selected, label: label, isInSheet: false),
        ),
      ),
    );
  }
}

final class _GPSelectList<T> extends StatelessWidget {
  const _GPSelectList({required this.options, required this.selected, required this.label, required this.isInSheet});

  final List<GPSelectOption<T>> options;
  final T? selected;
  final String? label;
  final bool isInSheet;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    explicitChildNodes: true,
    child: ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: options.length,
      separatorBuilder: (_, _) => SizedBox(height: context.spacing.xxs),
      itemBuilder: (_, index) => _GPSelectOptionTile(option: options[index], isInSheet: isInSheet, isSelected: options[index].value == selected),
    ),
  );
}

final class _GPSelectOptionTile<T> extends StatelessWidget {
  const _GPSelectOptionTile({required this.option, required this.isInSheet, required this.isSelected});

  final GPSelectOption<T> option;
  final bool isInSheet;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final icon = option.icon;

    return Semantics(
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: isSelected ? colors.accentContainer : Colors.transparent,
        borderRadius: context.radii.borderMd,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(option),
          borderRadius: context.radii.borderMd,
          overlayColor: WidgetStatePropertyAll(colors.onSurface.withValues(alpha: 0.06)),
          child: Container(
            constraints: BoxConstraints(minHeight: isInSheet ? 52.0 : 48.0),
            padding: EdgeInsets.symmetric(horizontal: isInSheet ? spacing.md : spacing.smd),
            child: Row(
              spacing: spacing.smd,
              children: [
                if (icon != null) Icon(icon, size: 20.0, color: isSelected ? colors.onAccentContainer : colors.onSurfaceVariant),
                Expanded(
                  child: Text(
                    option.label,
                    style: context.text.bodyLarge.copyWith(color: colors.onSurface, fontWeight: isSelected ? FontWeight.w500 : null),
                  ),
                ),
                // Kept in the layout when hidden, so a row's text does not move when it becomes the selected one.
                Visibility.maintain(
                  visible: isSelected,
                  child: Icon(Icons.check, size: 20.0, color: colors.onAccentContainer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
