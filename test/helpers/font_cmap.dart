import 'dart:typed_data';

/// The Unicode codepoints a TrueType / OpenType font maps to a glyph, read from its `cmap` table. Glyph 0 (`.notdef`, the box) counts as unmapped.
Set<int> mappedCodepoints(ByteData font) {
  if (font.getUint32(0) == _ttcfTag) throw ArgumentError('a font collection (ttcf) holds several fonts; pass one font');

  final cmap = _tableOffset(font, _cmapTag);
  final codepoints = <int>{};
  final subtableCount = font.getUint16(cmap + 2);
  for (var i = 0; i < subtableCount; i++) {
    final record = cmap + 4 + i * 8;
    if (!_isUnicode(platformId: font.getUint16(record), encodingId: font.getUint16(record + 2))) continue;

    final subtable = cmap + font.getUint32(record + 4);
    final format = font.getUint16(subtable);
    switch (format) {
      case 4:
        _readFormat4(font, subtable, codepoints);
      case 12:
        _readFormat12(font, subtable, codepoints);
      case 14:
        // Variation sequences: they map no codepoint on their own.
        break;
      default:
        throw UnsupportedError('cmap subtable format $format is not read by this helper; teach it the format rather than skipping it');
    }
  }
  return codepoints;
}

/// `'cmap'` and `'ttcf'` as big-endian `uint32` tags.
const int _cmapTag = 0x636D6170;
const int _ttcfTag = 0x74746366;

/// Where [tag]'s table starts, from the table directory that follows the 12-byte sfnt header.
int _tableOffset(ByteData font, int tag) {
  final tableCount = font.getUint16(4);
  for (var i = 0; i < tableCount; i++) {
    final record = 12 + i * 16;
    if (font.getUint32(record) == tag) return font.getUint32(record + 8);
  }
  throw ArgumentError('the font has no table with tag 0x${tag.toRadixString(16)}');
}

/// Platform 0 is Unicode in every encoding; on platform 3 (Windows) encoding 1 is the BMP and 10 is every plane. The other encodings are not Unicode.
bool _isUnicode({required int platformId, required int encodingId}) => platformId == 0 || (platformId == 3 && (encodingId == 1 || encodingId == 10));

/// Format 4: the BMP as segments. A non-zero `idRangeOffset` addresses the glyph array relative to that `idRangeOffset` entry itself.
void _readFormat4(ByteData font, int table, Set<int> into) {
  final segmentCount = font.getUint16(table + 6) ~/ 2;
  final endCodes = table + 14;
  final startCodes = endCodes + segmentCount * 2 + 2; // + reservedPad
  final idDeltas = startCodes + segmentCount * 2;
  final idRangeOffsets = idDeltas + segmentCount * 2;

  for (var s = 0; s < segmentCount; s++) {
    final start = font.getUint16(startCodes + s * 2);
    final end = font.getUint16(endCodes + s * 2);
    final delta = font.getUint16(idDeltas + s * 2);
    final rangeOffsetAt = idRangeOffsets + s * 2;
    final rangeOffset = font.getUint16(rangeOffsetAt);

    // The table always ends with a 0xFFFF segment that maps nothing.
    for (var codepoint = start; codepoint <= end && codepoint != 0xFFFF; codepoint++) {
      final int glyph;
      if (rangeOffset == 0) {
        glyph = (codepoint + delta) & 0xFFFF;
      } else {
        final fromArray = font.getUint16(rangeOffsetAt + rangeOffset + (codepoint - start) * 2);
        glyph = fromArray == 0 ? 0 : (fromArray + delta) & 0xFFFF;
      }
      if (glyph != 0) into.add(codepoint);
    }
  }
}

/// Format 12: every plane, as groups of consecutive codepoints mapped to consecutive glyphs.
void _readFormat12(ByteData font, int table, Set<int> into) {
  final groupCount = font.getUint32(table + 12);
  for (var g = 0; g < groupCount; g++) {
    final record = table + 16 + g * 12;
    final start = font.getUint32(record);
    final end = font.getUint32(record + 4);
    final startGlyph = font.getUint32(record + 8);
    for (var codepoint = start; codepoint <= end; codepoint++) {
      if (startGlyph + (codepoint - start) != 0) into.add(codepoint);
    }
  }
}
