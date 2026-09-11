# ADR 0004 — Hand-written localization classes, English and Vietnamese

## Status

Accepted — 2026-09-11 (W1, unplanned)

## Context

`docs/blueprint.md` §47 asks for English and Vietnamese and names Flutter
`gen_l10n`. That was intent, never a decision: there is no ADR, no `l10n.yaml`,
no ARB file, no `flutter_localizations`, and — until this one — no slot for
localization anywhere in the 28-week `ROADMAP.md`, including the polish weeks.

Localization is usually safe to defer. Here it is not, because three items
already on the calendar bake in an answer whether or not one has been chosen:

1. **W1 flex — `sealed class Failure`.** Appendix B of the blueprint models
   `ValidationFailure(this.message)`, holding a user-facing `String`. A
   `Failure` lives in `domain/`, which must not import Flutter (`CLAUDE.md`
   §3), so it cannot translate anything. Ship that signature and every
   repository and use case that constructs one is a place English is baked
   into the domain layer.
2. **W3 T5 — `seed default categories (is_system = true)`.** How a system
   category's name is stored is a *schema* decision. Get it wrong and the fix
   is a migration, on a table that by then has rows.
3. **W3 — the `Money` value object.** `1.234,56 ₫` and `₫1,234.56` are the same
   amount. Parsing a typed amount is locale-dependent in the other direction,
   and a misparsed separator violates golden rule 2 from the UI inwards.

So the structure is decided now, while all three are still unwritten.

## Decision

### Hand-written classes, not ARB + `gen_l10n`

An abstract `GPLocaleBase` declares every string as a getter, grouped into one
section per feature (`root`, `home`, `accounts`, `transactions`, `budgets`,
`settings`, `error`), split across `part` files that mirror `lib/features/`.
`GPLocaleEn` and `GPLocaleVi` implement it. All implementations are `const`, so
switching language allocates nothing.

The property this buys is worth more here than codegen convenience: **the
analyzer is the completeness check.** A new getter on the base does not compile
until both languages implement it. With ARB, a key missing from `app_vi.arb`
is a runtime fallback to English that ships silently.

The shape follows the pattern already in use in `~/UTS/xperisemapp`, with three
deliberate departures, each of which is a gap in that implementation:

| There | Here | Why |
| --- | --- | --- |
| No `localizationsDelegates` / `supportedLocales` | `flutter_localizations` wired in `GPApp` | Otherwise Material's own widgets — the date picker on every transaction screen, the text-selection menu — stay English inside a Vietnamese app |
| `XMLocalization.instance` static singleton | `GPLocalization` registered in `get_it` | Same reason as `GPClock` and `GPUuidGenerator` in ADR-0002: a global cannot be faked, so tests either all run in English or leak language into each other |
| Strings read from the singleton inside `build()` | `GPLocalizationScope`, an `InheritedNotifier` | A plain field read compiles and then leaves the old language on screen; a dependency makes the rebuild automatic |

`GPLocalizationScope` is an `InheritedNotifier`, not an `InheritedWidget`
holding the strings. A plain inherited widget would compare
`oldWidget.localization.locale` against `localization.locale` — the same
mutable object on both sides, so always equal and never a rebuild. This was not
a hypothetical: the first implementation had that bug and two widget tests
caught it.

The scope carries the *controller*, not just the strings, so a language picker
calls `context.localization.changeLocale(...)` and no page has to reach into
`getIt`.

### Locale resolution and persistence

- Order: stored choice → device language → `GPLocale.fallback` (English).
  Resolved in `bootstrap()` before `runApp`, so the first frame is already
  correct and there is no flash of English.
- Country is ignored. `en_US`, `en_GB` and `en_AU` are one translation; three
  files that never differ would be three files to keep in sync. Region-specific
  number and currency shapes are `intl`'s job, not the string table's.
- An unsupported language falls back rather than throwing. `'vn'` — a plausible
  typo for Vietnamese — resolves to English, not to `vi`; guessing is worse
  than falling back.
- Language names are **never translated**. `GPLocale.displayName` is
  `'English'` / `'Tiếng Việt'` in both locales, because a picker has to be
  readable by someone who cannot read the current UI language.
- **Persistence is behind `GPLocaleStore`, with no persistent implementation
  yet.** The app has no database until W2 and no settings screen until W23;
  adding `shared_preferences` for one key today would mean owning two settings
  stores once Drift lands. W2 adds a local-only `settings` table and a
  `GPDriftLocaleStore`; nothing outside that file changes.
- **The locale does not sync.** It is a property of a device, not of an
  account: a phone kept in Vietnamese and a work tablet kept in English must
  not fight, and no sync round trip may sit between a tap and the repaint.
  This answers the Definition-of-Done question (`CLAUDE.md` §11) for this piece
  of state: *decided, and the decision is "does not sync"*.

### Consequences for the three items that forced this ADR

- **`Failure` carries a type, never a message.** Appendix B's
  `ValidationFailure(this.message)` is superseded: presentation maps a failure
  to one of the `error.*` getters. The `error` section exists already, with one
  string per failure type in Appendix B.
- **System category names are stored as a key, not as text** (`name_key`,
  e.g. `category.food`), with the user-editable `name` column winning when it
  is set. Storing the translated text at seed time would freeze the language
  the app happened to be in at install, and two devices on different languages
  would disagree after a sync. This was left to my judgement; it is written
  here so W3 T5 implements it deliberately, and it is open to being revisited
  before that task starts.
- **Money and date formatting go through `intl`,** which arrives transitively
  with `flutter_localizations` and gets promoted to a direct pinned dependency
  at W3 when `Money` needs it. Not added today: an unused dependency is a
  dependency nobody has justified.

## Alternatives

**ARB + `gen_l10n`,** what blueprint §47 names. Standard, generates
`AppLocalizations`, handles plurals and gendered forms through ICU syntax, and
is what a Flutter reviewer expects. Rejected on the completeness point above: a
missing key degrades to English at runtime instead of failing the build, and
that is precisely the failure this repo's Definition of Done tries to make
impossible elsewhere. Also rejected because plural and gender machinery buys
little between English and Vietnamese — Vietnamese has no plural inflection at
all. Worth revisiting if a third language with real inflection is added.

**`slang`.** Solves the completeness problem too, with generated typed keys
from YAML/JSON. Rejected on the `CLAUDE.md` §5 dependency test: it adds a
codegen dependency and a build step for a benefit hand-written classes already
give, on an app with two languages.

**`easy_localization`.** Runtime key lookup with string keys
(`'home.title'.tr()`). Rejected outright: a typo in a key is a runtime miss,
which is the opposite of the property being bought.

**Store both a key and the translated text on a category row.** Safer when the
string table and the seed data drift apart. Rejected: two sources of truth for
one name, and sync then has to answer which column wins.

**Defer the whole thing to W27 polish**, per the roadmap's own "no polish
before the sync engine" rule. Rejected because localization here is not polish
— it is the shape of `Failure`, of the `categories` schema, and of `Money`
formatting. Deferring the structure does not defer the decision; it only means
the decision gets made implicitly, three times, by whoever writes those tasks.

## Consequences

Positive:

- A missing translation is a compile error, in either language, at the moment
  the string is added.
- `Failure`, the `categories` schema and `Money` formatting now have an answer
  to build against, before any of the three is written.
- Language changes repaint every live tab branch, including the ones the
  stateful shell (ADR-0003) keeps mounted off screen — covered by a test.
- Material's own widgets follow the app language.
- The whole thing is injectable: a widget test pumps one page in one language
  with no DI and no app boot.

Negative:

- Adding a string means editing three files (base, en, vi) instead of two ARB
  files. The compiler points at the two that are missing, so the cost is
  mechanical, not a risk.
- Plurals and gendered forms have no built-in support. Not needed for
  English + Vietnamese; a third language may force a rethink, and this ADR is
  the place that rethink starts.
- No persistence until W2: in W1 a language choice does not survive a restart.
  Acceptable because W1 has no settings entry point other than the picker added
  with this change.
- The blueprint's §47 (`gen_l10n`) and Appendix B (`ValidationFailure(message)`)
  are both now out of date. This ADR is the newer decision on both points.
