import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/locale.dart';
import '../localization/localization_scope.dart';
import '../money/money.dart';
import '../money/money_formatter.dart';
import 'text_field.dart';

/// Cash-register entry (ADR-0015): the digits typed are the minor units, so `1250` in USD is `12.50` and nothing is ever parsed from a decimal separator.
/// Every edit re-renders the whole text; [GPMoneyField] keeps the caret at the end, which is what makes a typed digit an appended one.
final class GPMoneyInputFormatter extends TextInputFormatter {
  GPMoneyInputFormatter({required GPLocale locale, required this.currencyCode}) : _formatter = GPMoneyFormatter(locale);

  final GPMoneyFormatter _formatter;
  final String currencyCode;

  /// Null for an empty field, which is "nothing typed", not zero.
  static int? minorUnitsOf(String text) {
    final digits = _digitsOf(text);
    return digits.isEmpty ? null : int.parse(digits);
  }

  /// Leading zeros dropped, so `0` then `5` reads 5 rather than growing a `05`.
  static String _digitsOf(String text) => text.replaceAll(_nonDigits, '').replaceFirst(_leadingZeros, '');

  /// 15 digits stay exact in a JS double and far inside Postgres `bigint` (ADR-0007), and no wallet holds 10^15 dong.
  static const maxDigits = 15;

  static final _nonDigits = RegExp('[^0-9]');
  static final _leadingZeros = RegExp('^0+');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = _digitsOf(newValue.text);
    if (digits.length > maxDigits) return oldValue;
    if (digits.isEmpty) return TextEditingValue.empty;

    final text = format(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  String format(int minorUnits) => _formatter.format(Money(minorUnits, currencyCode), withSymbol: false);
}

/// A magnitude only: the caller owns the sign (a transaction's type, an account's "owed" switch).
final class GPMoneyField extends StatefulWidget {
  const GPMoneyField({
    super.key,
    this.focusNode,
    required this.currencyCode,
    this.errorText,
    this.label,
    this.initialMinorUnits,
    this.autofocus = false,
    required this.onChanged,
  });

  final FocusNode? focusNode;
  final String currencyCode;
  final String? errorText;
  final String? label;
  final int? initialMinorUnits;
  final bool autofocus;

  /// Null while the field is empty.
  final void Function(int? minorUnits) onChanged;

  @override
  State<GPMoneyField> createState() => _GPMoneyFieldState();
}

final class _GPMoneyFieldState extends State<GPMoneyField> {
  final _controller = TextEditingController();

  GPLocale? _locale;

  GPMoneyInputFormatter get _formatter => GPMoneyInputFormatter(locale: _locale!, currencyCode: widget.currencyCode);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final locale = context.l10n.locale;
    if (locale == _locale) return;

    // First build: show the initial amount. A language change: re-render what is there with the new separators.
    final minorUnits = _locale == null ? widget.initialMinorUnits : GPMoneyInputFormatter.minorUnitsOf(_controller.text);
    _locale = locale;
    _render(minorUnits);
  }

  @override
  void didUpdateWidget(GPMoneyField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Another account picked: the same digits, read in the new currency's exponent.
    if (oldWidget.currencyCode != widget.currencyCode) _render(GPMoneyInputFormatter.minorUnitsOf(_controller.text));
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerChange)
      ..dispose();
    super.dispose();
  }

  /// A caret left mid-number would take the next digit there, and the formatter, which only sees text, cannot tell: `12.500` with the caret after the 5,
  /// backspace, then 8, would save 12,008. Selection-only changes never reach a formatter, so this listens to the controller instead.
  void _handleControllerChange() {
    final end = _controller.text.length;
    final selection = _controller.selection;
    if (selection.isCollapsed && selection.baseOffset == end) return;

    _controller.selection = TextSelection.collapsed(offset: end);
  }

  void _handleTextChange(String text) => widget.onChanged.call(GPMoneyInputFormatter.minorUnitsOf(text));

  void _render(int? minorUnits) {
    final text = minorUnits == null ? '' : _formatter.format(minorUnits);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = _formatter;
    final affixes = GPMoneyFormatter(_locale!).symbolAffixes(widget.currencyCode);
    // The field spaces the symbol itself; the formatter's no-break space would double the gap.
    final prefix = affixes.prefix.trim();
    final suffix = affixes.suffix.trim();

    return GPTextField(
      inputFormatters: [formatter],
      controller: _controller,
      focusNode: widget.focusNode,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.end,
      errorText: widget.errorText,
      hintText: formatter.format(0),
      label: widget.label,
      prefixText: prefix.isEmpty ? null : prefix,
      suffixText: suffix.isEmpty ? null : suffix,
      autofocus: widget.autofocus,
      // No tap-to-place caret, no selection handles, no paste menu: there is nowhere but the end to put a digit.
      enableInteractiveSelection: false,
      tabularFigures: true,
      onChanged: _handleTextChange,
    );
  }
}
