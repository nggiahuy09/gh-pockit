import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/widgets/utf16_length_limit.dart';

void main() {
  const limit = GPUtf16LengthLimitingFormatter(4);

  TextEditingValue typed(String text, {TextRange composing = TextRange.empty}) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
    composing: composing,
  );

  TextEditingValue apply(String before, TextEditingValue after) => limit.formatEditUpdate(typed(before), after);

  test('lets text up to the limit through untouched', () {
    expect(apply('abc', typed('abcd')).text, 'abcd');
  });

  test('cuts text past the limit and keeps the caret inside it', () {
    final result = apply('abcd', typed('abcde'));

    expect(result.text, 'abcd');
    expect(result.selection, const TextSelection.collapsed(offset: 4));
  });

  test('counts an emoji as the two units the entity counts, not as one character', () {
    // Two emoji: two characters on screen, four code units.
    expect(apply('😀', typed('😀😀')).text, '😀😀');
    expect(apply('😀😀', typed('😀😀a')).text, '😀😀');
  });

  test('never keeps half of a surrogate pair', () {
    // 'abc' + an emoji is five units; the cut at four would land between the emoji's halves.
    expect(apply('abc', typed('abc😀')).text, 'abc');
  });

  test('leaves a composing word alone until it is committed', () {
    final composing = typed('abcde', composing: const TextRange(start: 3, end: 5));

    expect(apply('abc', composing), composing);
  });
}
