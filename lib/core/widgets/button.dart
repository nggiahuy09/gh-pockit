import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/theme/tokens/dimensions.dart';

/// How much emphasis a [GPButton] carries.
enum GPButtonVariant {
  /// The highest-emphasis action on a screen: near-black fill, light label. There should be at most one on screen at a time.
  primary,

  /// The brand action — terracotta fill. Reserved for the one gesture that defines the screen, typically "add transaction".
  accent,

  /// A neutral tonal fill. A secondary action sitting beside a [primary] one.
  tonal,

  /// A bordered, unfilled action. Lower emphasis than [tonal], still clearly a button.
  outlined,

  /// No fill, no border. Inline actions and the lowest-emphasis slot — "Cancel", "Skip".
  text,

  /// A destructive action: delete, discard, sign out. Red fill.
  danger,
}

/// The height of a [GPButton].
///
/// Three steps, not the five the source kit carries — those were drawn for a web layout. [medium] is 48 logical pixels because that is Android's
/// minimum touch target; [small] is below it and is only legitimate inside a row that is itself tappable.
enum GPButtonSize {
  /// 40 — dense contexts, inside a list row or a chip bar.
  small,

  /// 48 — the default, and Android's minimum touch target.
  medium,

  /// 56 — a full-width primary action at the bottom of a form.
  large,
}

/// The app's action button.
///
/// Ported from `ngh09_ui_kit`'s `GHAppButton` (branch `dev`) and re-cut for this app: the five Finesse variants became the six roles Pockit actually
/// has, five sizes became three, and the corner enum was dropped — every button uses the theme's medium radius until something needs otherwise.
///
/// Hover handling was dropped with it. Pockit is Android-first (CLAUDE.md §1) and a touch screen has no hover state; what survives is the **focus
/// ring**, which is not decoration — it is how a keyboard or switch-access user knows where they are.
///
/// ```dart
/// GPButton(label: l10n.transactions.save, onPressed: _save);
/// GPButton(label: l10n.root.cancel, variant: GPButtonVariant.text, onPressed: _cancel);
/// GPButton(label: l10n.accounts.delete, variant: GPButtonVariant.danger, onPressed: _delete);
/// ```
///
/// The button is disabled when [onPressed] is null or [isLoading] is true. While loading it swaps the leading icon for a spinner and keeps the label,
/// so a button that already has an icon does not change size under a finger that is still on the screen. A button with *no* icon grows by the
/// spinner's width instead — which is why a form's submit button should be [expanded], where the width is fixed and the question does not arise.
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

  /// The button's text. Always a string, never a widget: a button whose label can be an arbitrary widget is a button that will eventually hold a
  /// `Row` nobody can translate.
  final String label;

  /// Called on tap. Null renders the disabled state.
  final VoidCallback? onPressed;

  /// How much emphasis this button carries.
  final GPButtonVariant variant;

  /// The button's height step.
  final GPButtonSize size;

  /// Optional icon before the label. Replaced by the spinner while [isLoading].
  final Widget? leading;

  /// Optional icon after the label. Hidden while [isLoading].
  final Widget? trailing;

  /// Whether to show a spinner and refuse input.
  final bool isLoading;

  /// Whether to stretch to the available width.
  final bool expanded;

  @override
  State<GPButton> createState() => _GPButtonState();
}

class _GPButtonState extends State<GPButton> {
  // Shared with the underlying Material button so the focus ring reads exactly the states that button reports, rather than a second Focus widget
  // guessing at them.
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

  // ── Metrics ──────────────────────────────────────────────────────────────

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

  /// Always semi-bold. A button label is a target, not prose: at Inter's regular weight a 14sp label inside a filled shape loses against its own background.
  TextStyle _labelStyle(BuildContext context) => switch (widget.size) {
    GPButtonSize.small => context.text.titleSmall,
    GPButtonSize.medium || GPButtonSize.large => context.text.titleMedium,
  }.copyWith(fontWeight: FontWeight.w600);

  // ── Colors ───────────────────────────────────────────────────────────────

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

  /// The focus ring, built from the palette rather than from a fixed shadow token.
  ///
  /// Two decisions here. Its **color follows the variant**, so a destructive button's ring is red — the ring has to agree with what pressing Enter is
  /// about to do. And it is drawn at **full opacity**, not as a soft halo: WCAG 1.4.11 asks a focus indicator to reach 3:1 against the ground, and a
  /// 24%-alpha version of the same color lands around 1.5:1. A ring nobody can see is not an accessibility feature.
  ///
  /// It is a shadow rather than a border because a border would change the button's size and shift everything beside it on focus.
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
      // Material's own elevation would fight the theme's shadow layer, which is where every other surface in this app gets its depth.
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

/// Lays out leading icon, label and trailing icon, swapping the leading slot for a spinner while loading.
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
