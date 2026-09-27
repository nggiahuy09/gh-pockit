import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/currency_code.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/money/money_formatter.dart';
import 'package:ghpockit/core/theme/tokens/typography.dart';

import '../../helpers/font_cmap.dart';

/// The whole Vietnamese alphabet in both cases, each vowel followed by its five toned forms — 29 letters and 134 precomposed ones.
///
/// Written out rather than generated so a Vietnamese reader can check it by eye. Of the seven letters Vietnamese adds to the Latin alphabet,
/// `ă â đ ê ô ơ ư`, the first bundled files had only the three in Latin-1. Most toned vowels sit in U+1EA0–U+1EF9 — asserted as a range as well — and the
/// rest in Latin-1 (`à á ã`) and Latin Extended-A (`ĩ ũ`).
const String _vietnameseLower = 'aàáảãạ ăằắẳẵặ âầấẩẫậ b c dđ eèéẻẽẹ êềếểễệ g h iìíỉĩị k l m n oòóỏõọ ôồốổỗộ ơờớởỡợ p q r s t uùúủũụ ưừứửữự v x yỳýỷỹỵ';
const String _vietnameseUpper = 'AÀÁẢÃẠ ĂẰẮẲẴẶ ÂẦẤẨẪẬ B C DĐ EÈÉẺẼẸ ÊỀẾỂỄỆ G H IÌÍỈĨỊ K L M N OÒÓỎÕỌ ÔỒỐỔỖỘ ƠỜỚỞỠỢ P Q R S T UÙÚỦŨỤ ƯỪỨỬỮỰ V X YỲÝỶỸỴ';

/// The marks Vietnamese decomposes into. The shaper recombines a decomposed sequence into the precomposed glyph when the font has one and stacks these
/// marks when it does not, so they are the safety net — and decomposed text is real input: Vietnamese keyboards offer a "Unicode tổ hợp" mode that types it.
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

/// Typographic punctuation a translator reaches for: en and em dash, curly quotes, ellipsis, bullet, middle dot. The strings use the em dash today.
const String _punctuation = '–—‘’“”…•·';

/// Every character an amount can be printed with: each language we ship × each currency the catalog knows, on a negative amount that uses all ten digits.
///
/// Derived rather than listed, so a currency added to `CurrencyCode` whose symbol the font cannot draw fails here instead of on a device — and so does a
/// locale whose separators it lacks. Today that is `0–9 , . -`, `$`, `₫` and the no-break space `intl` puts before a Vietnamese symbol.
Set<int> _formatterOutput() => <int>{
  for (final locale in GPLocale.values)
    for (final currency in CurrencyCode.values) ...GPMoneyFormatter(locale).format(Money(-1234567890, currency.code)).runes,
};

/// Latin Extended-A, for names typed in other European languages — Škoda, Łódź, İzmir (ADR-0008). U+0149 `ŉ` is the one letter Inter does not draw:
/// Unicode deprecated it in 5.2 in favour of `ʼn`.
final List<int> _latinExtendedA = <int>[for (var c = 0x0100; c <= 0x017F; c++) c]..remove(0x0149);

/// The families that draw icons, not words. These are named rather than the text family, so a second text family added later — an Inter Display for
/// the balance, say — is held to the same bar by default instead of by somebody remembering this file exists.
const Set<String> _iconFamilies = <String>{'MaterialIcons', 'packages/cupertino_icons/CupertinoIcons'};

/// One font file as `FontManifest.json` lists it: what the build actually bundled, which is what the device will load — not what pubspec.yaml was meant
/// to say.
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
  // The bug this file exists for: the first Inter files were a Latin-only cut of 230 codepoints. Nothing failed — on a device, Flutter quietly drew
  // `đ ư ơ ă`, most toned vowels and `₫` from the system font, so "Tiền mặt", "Ví điện tử" and every VND amount switched typeface mid-word, and in a test
  // render with the font loaded they came out as boxes. A missing glyph is invisible to every other test in the suite, because `flutter test` renders
  // with its own placeholder font unless a test loads ours. So this reads the files' `cmap` tables directly — exactly what a device consults before it
  // decides to fall back.
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<_BundledFont> fonts;
  final mapped = <String, Set<int>>{};

  setUpAll(() async {
    fonts = await _bundledTextFonts();
    for (final font in fonts) {
      mapped[font.asset] = mappedCodepoints(await rootBundle.load(font.asset));
    }
  });

  /// Reports every file's gaps at once, each as `U+0111 đ`, so a failure reads as a to-do list rather than one codepoint per run. One string per file
  /// rather than a list, because the matcher cuts a printed list off after 24 entries and the Latin-only files were missing 102 letters.
  void expectEveryFileMaps(Iterable<int> required) {
    final gaps = <String, String>{};
    for (final MapEntry<String, Set<int>>(key: asset, value: codepoints) in mapped.entries) {
      final missing = required.toSet().difference(codepoints).toList()..sort();
      if (missing.isNotEmpty) gaps[asset] = '${missing.length} missing: ${missing.map(_describe).join(', ')}';
    }
    expect(gaps, isEmpty, reason: 'a device draws these from the system font, mid-word; a test render with the font loaded draws a box');
  }

  test('the text family is bundled with one file per weight the type scale uses', () {
    // Every assertion below loops over the bundled files, and a loop over nothing passes. This is what keeps them from passing vacuously — and what
    // fails first if the fonts block in pubspec.yaml ever stops matching the weights `GPTypographyTokens` hands out.
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
