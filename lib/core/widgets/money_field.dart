import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/money/money_formatter.dart';
import 'package:ghpockit/core/widgets/text_field.dart';

/// Cash-register entry (ADR-0015): the digits typed are the minor units, so `1250` in USD is `12.50` and nothing is ever parsed from a decimal separator.
/// Every edit re-renders the whole text; [GPMoneyField] keeps the caret at the end, which is what makes a typed digit an appended one.
class GPMoneyInputFormatter extends TextInputFormatter {
  GPMoneyInputFormatter({required this.currencyCode, required GPLocale locale}) : _formatter = GPMoneyFormatter(locale);

  /// 15 digits stay exact in a JS double and far inside Postgres `bigint` (ADR-0007), and no wallet holds 10^15 dong.
  static const int maxDigits = 15;

  final String currencyCode;
  final GPMoneyFormatter _formatter;

  /// Null for an empty field, which is "nothing typed", not zero.
  static int? minorUnitsOf(String text) {
    final digits = _digitsOf(text);
    return digits.isEmpty ? null : int.parse(digits);
  }

  String format(int minorUnits) => _formatter.format(Money(minorUnits, currencyCode), withSymbol: false);

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

  /// Leading zeros dropped, so `0` then `5` reads 5 rather than growing a `05`.
  static String _digitsOf(String text) => text.replaceAll(_nonDigits, '').replaceFirst(_leadingZeros, '');

  static final RegExp _nonDigits = RegExp('[^0-9]');
  static final RegExp _leadingZeros = RegExp('^0+');
}

/// A magnitude only: the caller owns the sign (a transaction's type, an account's "owed" switch).
class GPMoneyField extends StatefulWidget {
  const GPMoneyField({required this.currencyCode, required this.onChanged, this.initialMinorUnits, this.label, this.errorText, this.autofocus = false, this.focusNode, super.key});

  final String currencyCode;

  /// Null while the field is empty.
  final ValueChanged<int?> onChanged;

  final int? initialMinorUnits;
  final String? label;
  final String? errorText;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<GPMoneyField> createState() => _GPMoneyFieldState();
}

class _GPMoneyFieldState extends State<GPMoneyField> {
  final TextEditingController _controller = TextEditingController();
  GPLocale? _locale;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_keepCaretAtEnd);
  }

  /// A caret left mid-number would take the next digit there, and the formatter, which only sees text, cannot tell: `12.500` with the caret after the 5,
  /// backspace, then 8, would save 12,008. Selection-only changes never reach a formatter, so this listens to the controller instead.
  void _keepCaretAtEnd() {
    final end = _controller.text.length;
    final selection = _controller.selection;
    if (selection.isCollapsed && selection.baseOffset == end) return;

    _controller.selection = TextSelection.collapsed(offset: end);
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
      ..removeListener(_keepCaretAtEnd)
      ..dispose();
    super.dispose();
  }

  GPMoneyInputFormatter get _formatter => GPMoneyInputFormatter(currencyCode: widget.currencyCode, locale: _locale!);

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

    return GPTextField(
      controller: _controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      label: widget.label,
      hintText: formatter.format(0),
      errorText: widget.errorText,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[formatter],
      // No tap-to-place caret, no selection handles, no paste menu: there is nowhere but the end to put a digit.
      enableInteractiveSelection: false,
      textAlign: TextAlign.end,
      tabularFigures: true,
      // The field spaces the symbol itself; the formatter's no-break space would double the gap.
      prefixText: affixes.prefix.trim().isEmpty ? null : affixes.prefix.trim(),
      suffixText: affixes.suffix.trim().isEmpty ? null : affixes.suffix.trim(),
      onChanged: (String text) => widget.onChanged(GPMoneyInputFormatter.minorUnitsOf(text)),
    );
  }
}
