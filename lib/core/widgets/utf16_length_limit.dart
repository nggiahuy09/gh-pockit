import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Caps text at [maxLength] UTF-16 code units, the unit the entities count in. `TextField.maxLength` counts what the user sees as characters, so an
/// emoji (two units) would get past it and be refused only on save.
final class GPUtf16LengthLimitingFormatter extends TextInputFormatter {
  const GPUtf16LengthLimitingFormatter(this.maxLength);

  final int maxLength;

  static bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.length <= maxLength) return newValue;

    // A Vietnamese IME holds the word being typed as provisional text; cutting it mid-composition breaks the word. The commit comes back through here.
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) return newValue;

    // Never keep half a surrogate pair: the high half alone is not text.
    final end = _isHighSurrogate(text.codeUnitAt(maxLength - 1)) ? maxLength - 1 : maxLength;
    final selection = newValue.selection;

    return TextEditingValue(
      text: text.substring(0, end),
      selection: selection.isValid ? selection.copyWith(baseOffset: math.min(selection.baseOffset, end), extentOffset: math.min(selection.extentOffset, end)) : selection,
    );
  }
}
