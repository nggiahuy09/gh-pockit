# Inter

Inter **4.1**, subset to Latin + Vietnamese. SIL Open Font License 1.1 — full text in [`OFL.txt`](OFL.txt), upstream at https://github.com/rsms/inter.
The license declares no Reserved Font Name, so a subset may keep the name "Inter".

| File                 | Weight | Bytes  | SHA-256                                                            |
| -------------------- | ------ | ------ | ------------------------------------------------------------------ |
| `Inter-Regular.ttf`  | 400    | 77,352 | `a316a03381508c32eb7a5ced8ed032691aba6d5cb68f6992efc64315481007b7` |
| `Inter-Medium.ttf`   | 500    | 78,736 | `7b40385fb6c028e9ab6c63474fb6ed47d2474fa3b65413cf0636fbae6c137251` |
| `Inter-SemiBold.ttf` | 600    | 78,804 | `512dcde14c9a72c62cbf6fc1fbacabdeb54b7c43a0bf100e4d2abd16875e2ebc` |
| `Inter-Bold.ttf`     | 700    | 78,572 | `d56c808d132ce10a78df86ae16960bfe0eb4bfaf5ead245eba63c97ce35e998d` |

~313 KB for the four. The Latin-only files before them were ~272 KB; the full upstream files are ~1.67 MB. Why a subset, and why this one: ADR-0008.

## Why bundled, not `google_fonts`

On purpose. Pockit is offline-first (CLAUDE.md §1): a font fetched over the network on first launch means the first frame of a cold start depends on
connectivity, which is exactly the property this app exists to not have. The bytes are the price, paid once in the bundle.

## What is in it

511 codepoints, the same in every weight: Google Fonts' own `latin` and `vietnamese` ranges — a set other people have already argued about — plus
the three Vietnamese combining marks that `vietnamese` leaves out, plus Latin Extended-A.

| Range                                                    | For                                                                                                                                                                         |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| U+0000–00FF                                              | Basic Latin + Latin-1: English, and the Vietnamese letters that live there (`à á â ã è é ê ì í ò ó ô õ ù ú ý`)                                                              |
| U+0100–017F                                              | Latin Extended-A: `ă đ ĩ ũ` for Vietnamese, and the letters of names people type in other European languages (Škoda, Łódź, İzmir)                                           |
| U+01A0–01A1, U+01AF–01B0                                 | `Ơ ơ Ư ư` — the only Vietnamese letters in Latin Extended-B, and the only part of that block taken                                                                          |
| U+1EA0–1EF9                                              | every precomposed Vietnamese vowel with a tone mark, `Ạ ạ Ả ả … Ỹ ỹ`                                                                                                        |
| U+0300–0304, U+0306, U+0308–0309, U+031B, U+0323, U+0329 | combining marks: the eight Vietnamese decomposes into (grave, acute, circumflex, tilde, breve, hook above, horn, dot below), plus macron, diaeresis and vertical line below |
| U+02BB–02BC, U+02C6, U+02DA, U+02DC                      | modifier letters the previous files carried (`ʻ ʼ ˆ ˚ ˜`)                                                                                                                   |
| U+2000–206F                                              | General Punctuation: dashes, curly quotes, ellipsis, bullet, the space variants                                                                                             |
| U+20AB–20AC                                              | `₫` and `€`                                                                                                                                                                 |
| U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD   | `™ ↑ ↓ − ∕`, the BOM, and the replacement character `�`                                                                                                                     |

Everything the previous files covered is still covered. Inter has no glyph for U+0149 `ŉ`, which Unicode deprecated — the one hole in Latin
Extended-A, and it is Inter's, not the subset's.

Left out on purpose: the rest of Latin Extended-B, Cyrillic, Greek, and currency symbols beyond `$ ¢ £ ¥ € ₫`. A character outside the set still
renders — Flutter falls back to the system font for it — just not in Inter.

**OpenType features:** `kern mark mkmk` (GPOS) and `calt ccmp locl tnum pnum frac numr dnom` (GSUB) — the set the previous files had, `tnum` included,
which money needs. Dropped: Inter's `cv01`–`cv14`, `ss01`–`ss08`, `case`, `zero`, `sups`/`subs` and the rest; a feature a screen later wants is one more
name in the command below. **Hinting** is stripped, as it was in the previous files. The **`name` table** is kept whole, so each file carries its
copyright line, the OFL notice and its URL (name IDs 0, 13, 14); the previous files had kept only the URL.

## Rebuilding

The files are generated, not edited. From the repo root:

```bash
work=$(mktemp -d)
curl -L -o "$work/Inter-4.1.zip" https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip
shasum -a 256 "$work/Inter-4.1.zip"   # 9883fdd4a49d4fb66bd8177ba6625ef9a64aa45899767dde3d36aa425756b11e
unzip -q "$work/Inter-4.1.zip" -d "$work/Inter-4.1"
python3 -m venv "$work/venv" && "$work/venv/bin/pip" install fonttools==4.66.0
for weight in Regular Medium SemiBold Bold; do
  "$work/venv/bin/pyftsubset" "$work/Inter-4.1/extras/ttf/Inter-$weight.ttf" \
    --output-file="assets/fonts/Inter-$weight.ttf" \
    --unicodes='U+0000-017F,U+01A0-01A1,U+01AF-01B0,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0300-0304,U+0306,U+0308-0309,U+031B,U+0323,U+0329,U+1EA0-1EF9,U+2000-206F,U+20AB-20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD' \
    --layout-features='calt,ccmp,dnom,frac,locl,numr,pnum,tnum,kern,mark,mkmk' \
    --name-IDs='*' --notdef-outline --no-hinting
done
shasum -a 256 assets/fonts/Inter-*.ttf   # must match the table above
```

The output is byte-for-byte deterministic — `pyftsubset` keeps the upstream `head.modified` — so the checksums above are what a rebuild must
reproduce. fontTools is a tool run on a developer machine, not a dependency: nothing in `pubspec.yaml`, nothing in CI, nothing at runtime.

## The guard

`test/core/theme/font_coverage_test.dart` reads every bundled text font's `cmap` and fails if any file is missing a letter of the Vietnamese alphabet,
one of U+1EA0–1EF9, a Vietnamese combining mark, anything `GPMoneyFormatter` can print, the common typographic punctuation, or Latin Extended-A. The
formatter's characters are derived from `CurrencyCode` × `GPLocale` rather than listed, so a currency added later whose symbol is not in the set fails
the test the day it is added. Narrow the set, and the test names what went missing.

## History

The first files were copied from `ngh09_ui_kit` (branch `dev`): the same Inter 4.1, but a Latin-only subset of another build of it (`git-66647c0bb`),
cut by a recipe nobody recorded — 230 codepoints, with no `ă đ ơ ư`, nothing from U+1EA0–1EF9 and no `₫`. They did carry five of the eight Vietnamese
combining marks, which is why some toned vowels still rendered and the gap was easy to miss. On a device Flutter drew the rest from the system font,
mid-word ("Tiền mặt", every VND amount); in a test render with the font loaded they were boxes. Replaced at the end of W3 — ADR-0008.
