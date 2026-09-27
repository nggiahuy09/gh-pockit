# ADR 0008 — Bundle Inter as a Latin + Vietnamese subset

## Status

Accepted — 2026-09-27 (W3, the font finding split out of the flex task)

Amends ADR-0005's _Inter, bundled, not `google_fonts`_. The typeface, the
static files and the reasons for both stand; what changes is which characters
those files contain and how they are produced.

## Context

The four `assets/fonts/Inter-*.ttf` copied from `ngh09_ui_kit` at W1 were Inter
4.1 — but a Latin-only subset of it, from another build (`git-66647c0bb`) and
with no record of how it was cut: 230 codepoints. Their `cmap` has no
`ă` (U+0103), `đ` (U+0111), `ơ` (U+01A1) or `ư` (U+01B0), none of the
precomposed toned vowels in U+1EA0–U+1EF9, and no `₫` (U+20AB). The first
bundled font of a Vietnamese-first app could not write Vietnamese.

**Nothing failed, which is the actual problem.** On a device Flutter falls back
to the system font for a character the font cannot draw, so "Tiền mặt", "Ví
điện tử" and every VND amount `GPMoneyFormatter` prints (`1.500.000 ₫`) came
out in two typefaces mid-word. It looked almost right, because many toned
vowels still rendered in Inter: the shaper decomposes `ề` into `ê` plus U+0300,
and the Latin cut had both. In a test render with Inter loaded — no system font
to fall back to — the pattern is plain: `ề` survives, while `ặ`, `ệ` and `ử`
become boxes, because they decompose into parts the cut also lacked (`ạ` and a
combining breve, `ẹ` and a combining circumflex, `ư`). `đ` and `₫` have no
decomposition at all.

The test suite could not see it either. `flutter test` renders with its own
placeholder font unless a test loads ours, and a widget test finds text by
string, not by glyph. The gap surfaced only when `AccountsPage` (W3 flex) was
rendered with Inter loaded and every `đ` and `₫` came out as a NO GLYPH box.

## Decision

**Four static TTFs, subset from the upstream Inter 4.1 release with
`pyftsubset`, covering Latin + Vietnamese + Latin Extended-A: 511 codepoints,
313,464 bytes for the four weights (was 272,008).**

- **Source:** `extras/ttf/Inter-{Regular,Medium,SemiBold,Bold}.ttf` from
  `Inter-4.1.zip` (SHA-256 recorded in `assets/fonts/README.md`). The same
  version as the files it replaces, though not the same build, so Latin text
  keeps its look: line metrics are identical, and a 150-character line at 16 px
  lays out within 0.6 px of before. Only the missing letters arrive.
- **Coverage:** Google Fonts' own `latin` and `vietnamese` ranges — a set other
  people have already argued about — plus the three Vietnamese combining marks
  that `vietnamese` range leaves out, plus Latin Extended-A. It covers the
  whole Vietnamese alphabet (134 precomposed letters, and the eight marks it
  decomposes into) and everything the previous files did. The exact ranges,
  each with its reason, are in the README.
- **OpenType features:** exactly the previous files' set — `kern mark mkmk`,
  `calt ccmp locl tnum pnum frac numr dnom`. `tnum` stays because money needs
  it; `mark`/`mkmk` because decomposed Vietnamese stacks with them.
- **Hinting stripped**, as it was in the previous files. **`name` table kept
  whole**, so each file carries its copyright line, the OFL notice and its URL
  (name IDs 0, 13, 14) — the previous files had kept only the URL.
- **Reproducible:** the README holds the exact command and the output
  checksums, and the build is byte-for-byte deterministic — rerunning the
  command must reproduce the committed files, which is checkable.
- **Guarded:** `test/core/theme/font_coverage_test.dart` reads every bundled
  text font's `cmap` and fails on any missing Vietnamese letter or mark, any
  character `GPMoneyFormatter` can print, common punctuation, or Latin
  Extended-A. The formatter's characters are derived from `CurrencyCode` ×
  `GPLocale`, not listed, so the currency that brings a new symbol fails the
  test on the day it is added. The `cmap` reader is ~90 lines of test-only
  Dart; no package.

### fontTools, against the five questions in CLAUDE.md §5

fontTools is a **tool**, not a dependency — it runs on a developer machine when
the coverage changes, and nothing of it reaches `pubspec.yaml`, CI or the app.
It still answers the five questions, because a tool can lock a project in too:

1. **What it solves:** cutting a font down to a character set while keeping
   the glyphs, composites, substitutions and positioning those characters
   depend on. Nothing in the Dart or Flutter toolchain does this.
2. **Doing it ourselves:** a subsetter is a `glyf` / GSUB / GPOS closure over
   composites and lookups — weeks of work, and wrong in ways that only show on
   the one word that exercises the missing lookup.
3. **Maintained:** it is the reference implementation of the format, the
   library Google Fonts' own pipeline is built on, and actively released.
   Pinned at 4.66.0 in the README's command.
4. **Native setup:** none. The app ships plain TTFs, as it did before.
5. **Lock-in:** none. The output is ordinary TTF; if fontTools disappeared, the
   committed files keep working, and the documented ranges and features are
   enough to reproduce them with any subsetter (`hb-subset`).

### Options measured

All from the Inter 4.1 release, four weights. _Deflated_ is zlib level 9, a
proxy for what the APK and every download pay; _bytes_ is what an iOS device
stores.

| Option                                            | Files | Bytes    | vs before | Deflated | Codepoints |
| ------------------------------------------------- | ----- | -------- | --------- | -------- | ---------- |
| Before: the Latin-only files                      | 4     | 272 KB   | —         | 132 KB   | 230        |
| (a) Upstream static TTFs, as shipped              | 4     | 1,669 KB | +1,397 KB | 800 KB   | 2,852      |
| (a) … with hinting stripped                       | 4     | 1,183 KB | +911 KB   | 581 KB   | 2,852      |
| (b) Subset: Google Fonts latin + vietnamese       | 4     | 290 KB   | +18 KB    | 135 KB   | 395        |
| **(b) Subset: … + Latin Extended-A — chosen**     | 4     | 313 KB   | +41 KB    | 146 KB   | 511        |
| (b) Subset: … + Currency Symbols block            | 4     | 334 KB   | +62 KB    | 158 KB   | 538        |
| (b) Subset: … + Latin Ext-B, modifiers, all marks | 4     | 470 KB   | +198 KB   | 231 KB   | 874        |
| (c) Variable font, wght 400–700, chosen coverage  | 1     | 129 KB   | −143 KB   | 55 KB    | 511        |

## Consequences

**Good.** Vietnamese renders in one typeface in every weight, `₫` included.
Coverage is now a build gate beside contrast (ADR-0005): a regenerated file
that drops a letter fails the suite instead of shipping. The design is the one
already bundled, with identical line metrics, so no screen changes shape. The
files are reproducible from a pinned source and a pinned tool, down to the
byte.

**Bad.** +41 KB on disk, +14 KB deflated. The fonts are now generated
artifacts: changing coverage means rerunning the documented command, not
dropping in a new download. Inter's character variants and stylistic sets
(`cv01`–`cv14`, `ss01`–`ss08`, `zero`, `case`) are not in the files; a design
that wants one needs a rebuild with that feature added. Characters outside the
set — the rest of Latin Extended-B, Cyrillic, Greek, emoji — still fall back to
the system font. That is the accepted edge, not an oversight.

**Owed.**

- **Text is not normalized.** The combining marks make decomposed Vietnamese
  (a "Unicode tổ hợp" keyboard) render correctly, but decomposed `Tiền` and
  precomposed `Tiền` are still different strings to `==` and to SQL `LIKE`.
  That is a search problem, not a font one — it belongs to W26.
- **The license is not on a licenses page.** The OFL travels inside each file
  and beside them in `assets/fonts/OFL.txt`, but nothing calls
  `LicenseRegistry.addLicense`, so `showLicensePage` would not list Inter.
  There is no such page yet; whichever week builds Settings → About owes it.

## Alternatives rejected

**(a) The full upstream files.** 6.1× the bytes — +1.4 MB on disk, +669 KB
deflated on every download — for Cyrillic, Greek and 2,300 other codepoints an
English + Vietnamese app never draws. Their one real advantage, no tool and
provenance by checksum, is kept anyway: the source zip and the tool are pinned
and the output is checksummed.

**(c) A variable font.** The smallest option by far — 129 KB for all four
weights. But on Flutter 3.35.6, measured, `fontWeight` does not select the
instance: text laid out at `w700` has exactly the width of `w400` until
`fontVariations: [FontVariation.weight(700)]` is also set, after which it
matches the static Bold exactly (765.4 against 765.4 logical px, 40 px text).
Every style in `GPTypography` would need a `fontVariations` twin of its
`fontWeight`, and any `copyWith(fontWeight: …)` — ours, or inside a Material
widget — would silently render Regular. A new class of silent bug, in exchange
for ~185 KB. Worth revisiting if Flutter starts mapping `fontWeight` onto
`wght` by itself.

**Wider coverage** — all of Latin Extended-B, every combining mark, the
spacing modifiers, the whole currency block: +157 KB over the chosen set. Latin
Extended-B alone is +79 KB for 203 codepoints, and its only Vietnamese ones,
`ơ ư`, are taken in every option.

**Narrower coverage** — Google Fonts latin + vietnamese alone, +18 KB. It fixes
the bug, but a name typed with a letter outside Latin-1 (`š ł ő ę`) shows the
same mixed-typeface symptom. Latin Extended-A costs +23 KB, because most of it
is composites of glyphs already in the file.

**The Currency Symbols block now.** Deferred, not refused. `$ ¢ £ ¥ € ₫` are
covered, multi-currency is W37+, and the test derives what the formatter prints
from `CurrencyCode` — the week that adds a currency with a new symbol finds out
from the suite.

**A Vietnamese supplement through `fontFamilyFallback`.** Keep the Latin files
and add a second family holding only the Vietnamese letters. It saves nothing —
the letters cost the same bytes in either file — and it breaks kerning and mark
positioning across the font boundary, which in Vietnamese falls inside most
words.

**The platform font** (Roboto, SF Pro). Zero bytes, and it covers Vietnamese.
It also reverses ADR-0005's typeface decision and makes Android and iOS look
like two different apps.

**`google_fonts`.** Rejected in ADR-0005 for offline-first reasons, which have
not changed.
