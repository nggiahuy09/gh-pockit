import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/currency_code.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/money/money_formatter.dart';
import 'package:ghpockit/core/theme/tokens/typography.dart';

import '../../helpers/font_cmap.dart';

/// Each vowel followed by its five toned forms, written out rather than generated so a Vietnamese reader can check it by eye.
const String _vietnameseLower = 'aàáảãạ ăằắẳẵặ âầấẩẫậ b c dđ eèéẻẽẹ êềếểễệ g h iìíỉĩị k l m n oòóỏõọ ôồốổỗộ ơờớởỡợ p q r s t uùúủũụ ưừứửữự v x yỳýỷỹỵ';
const String _vietnameseUpper = 'AÀÁẢÃẠ ĂẰẮẲẴẶ ÂẦẤẨẪẬ B C DĐ EÈÉẺẼẸ ÊỀẾỂỄỆ G H IÌÍỈĨỊ K L M N OÒÓỎÕỌ ÔỒỐỔỖỘ ƠỜỚỞỠỢ P Q R S T UÙÚỦŨỤ ƯỪỨỬỮỰ V X YỲÝỶỸỴ';

/// Decomposed Vietnamese is real input (keyboards have a "Unicode tổ hợp" mode); the shaper stacks these marks when a font lacks the precomposed glyph.
const List<int> _vietnameseMarks = <int>[
  0x0300, // huyền — grave
  0x0301, // sắc — acute
  0x0302, // circumflex, in â ê ô
  0x0303, // ngã — tilde
  0x0306, // breve, in ă
  0x0309, // hỏi — hook above
  0x031B, // horn, in ơ ư
  0x0323, // nặng — dot below
];

const String _punctuation = '–—‘’“”…•·';

/// Derived, not listed: a currency or locale added later whose symbol or separators the font lacks fails here, not on a device.
Set<int> _formatterOutput() => <int>{
  for (final locale in GPLocale.values)
    for (final currency in CurrencyCode.values) ...GPMoneyFormatter(locale).format(Money(-1234567890, currency.code)).runes,
};

/// Names typed in other European languages (ADR-0008). Minus U+0149 `ŉ`, which Inter does not draw — Unicode deprecated it in 5.2.
final List<int> _latinExtendedA = <int>[for (var c = 0x0100; c <= 0x017F; c++) c]..remove(0x0149);

/// Icon families are excluded by name, so a text family added later is held to the same bar by default.
const Set<String> _iconFamilies = <String>{'MaterialIcons', 'packages/cupertino_icons/CupertinoIcons'};

/// As `FontManifest.json` lists it: what the build bundled, not what pubspec.yaml meant to say.
typedef _BundledFont = ({String family, String asset, int? weight});

Future<List<_BundledFont>> _bundledTextFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<Object?>;
  return <_BundledFont>[
    for (final family in manifest.cast<Map<String, Object?>>())
      if (!_iconFamilies.contains(family['family']))
        for (final font in (family['fonts']! as List<Object?>).cast<Map<String, Object?>>())
          (family: family['family']! as String, asset: font['asset']! as String, weight: font['weight'] as int?),
  ];
}

String _describe(int codepoint) => 'U+${codepoint.toRadixString(16).toUpperCase().padLeft(4, '0')} ${String.fromCharCode(codepoint)}';

void main() {
  // `flutter test` renders with a placeholder font, so a missing glyph is invisible to every other test. This reads each file's `cmap` table — what a
  // device consults before it silently falls back to a system font mid-word.
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<_BundledFont> fonts;
  final mapped = <String, Set<int>>{};

  setUpAll(() async {
    fonts = await _bundledTextFonts();
    for (final font in fonts) {
      mapped[font.asset] = mappedCodepoints(await rootBundle.load(font.asset));
    }
  });

  /// One string per file, not a list: the matcher truncates a printed list after 24 entries.
  void expectEveryFileMaps(Iterable<int> required) {
    final gaps = <String, String>{};
    for (final MapEntry<String, Set<int>>(key: asset, value: codepoints) in mapped.entries) {
      final missing = required.toSet().difference(codepoints).toList()..sort();
      if (missing.isNotEmpty) gaps[asset] = '${missing.length} missing: ${missing.map(_describe).join(', ')}';
    }
    expect(gaps, isEmpty, reason: 'a device draws these from the system font, mid-word; a test render with the font loaded draws a box');
  }

  test('the text family is bundled with one file per weight the type scale uses', () {
    // Keeps the loops below honest: a loop over no files passes vacuously.
    final weights = <int?>[
      for (final font in fonts)
        if (font.family == GPTypographyTokens.fontFamily) font.weight,
    ];
    final tokens = <FontWeight>[GPTypographyTokens.regular, GPTypographyTokens.medium, GPTypographyTokens.semiBold, GPTypographyTokens.bold];

    expect(weights, unorderedEquals(<int>[for (final weight in tokens) weight.value]));
  });

  group('every bundled text font maps', () {
    test('the whole Vietnamese alphabet, both cases', () => expectEveryFileMaps('$_vietnameseLower$_vietnameseUpper'.runes));

    test('all of U+1EA0–U+1EF9, the precomposed Vietnamese vowels', () => expectEveryFileMaps(<int>[for (var c = 0x1EA0; c <= 0x1EF9; c++) c]));

    test('the combining marks decomposed Vietnamese is written with', () => expectEveryFileMaps(_vietnameseMarks));

    test('₫ and everything else GPMoneyFormatter can print', () => expectEveryFileMaps(<int>{0x20AB, ..._formatterOutput()}));

    test('the typographic punctuation translations use', () => expectEveryFileMaps(_punctuation.runes));

    test('Latin Extended-A, for names typed in other European languages', () => expectEveryFileMaps(_latinExtendedA));
  });
}
