import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/widgets/utf16_length_limit.dart';

const _limit = GPUtf16LengthLimitingFormatter(4);

TextEditingValue _typed(String text, [TextRange composing = TextRange.empty]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
  composing: composing,
);

TextEditingValue _apply({required TextEditingValue after, required String before}) => _limit.formatEditUpdate(_typed(before), after);

void main() {
  test('lets text up to the limit through untouched', () {
    expect(_apply(after: _typed('abcd'), before: 'abc').text, 'abcd');
  });

  test('cuts text past the limit and keeps the caret inside it', () {
    final result = _apply(after: _typed('abcde'), before: 'abcd');

    expect(result.text, 'abcd');
    expect(result.selection, const TextSelection.collapsed(offset: 4));
  });

  test('counts an emoji as the two units the entity counts, not as one character', () {
    expect(
      _apply(after: _typed('😀😀'), before: '😀').text,
      '😀😀',
      reason: 'two characters on screen, four code units',
    );
    expect(_apply(after: _typed('😀😀a'), before: '😀😀').text, '😀😀');
  });

  test('never keeps half of a surrogate pair', () {
    expect(
      _apply(after: _typed('abc😀'), before: 'abc').text,
      'abc',
      reason: 'the cut at four would land between the emoji halves',
    );
  });

  test('leaves a composing word alone until it is committed', () {
    final composing = _typed('abcde', const TextRange(start: 3, end: 5));

    expect(_apply(after: composing, before: 'abc'), composing);
  });
}
