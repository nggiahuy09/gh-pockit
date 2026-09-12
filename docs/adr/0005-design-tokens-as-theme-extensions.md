# ADR 0005 — Design tokens as `ThemeExtension`, with a Claude-derived palette

## Status

Accepted — 2026-09-12 (W1, weekend flex)

## Context

`ROADMAP.md` W1 flex asks for "theme + design tokens". Until now `GPApp` passed
`ColorScheme.fromSeed(seedColor: Color(0xFF2E7D67))` — one green seed, from
which Material derived everything else. That is a placeholder, and it fails in
three specific ways:

1. **A seed cannot express roles the app needs.** Money moving in and money
   moving out are two semantic colors; Material's scheme has no slot for them,
   so every feature would reach for its own `Colors.green`.
2. **A seed produces its own neutrals**, which are blue-grey. The look this app
   wants is warm paper.
3. **Nothing is checkable.** A derived scheme gives no place to assert that a
   pairing is legible, so a contrast regression ships silently.

There is also an existing asset: `ngh09_ui_kit` (branch `dev`, the newest of
`app` / `dev` / `main`), a Flutter UI kit with a token layer and ~35
components, built on the Finesse UI Kit with Inter.

## Decision

### Three layers: primitive tokens → semantic roles → `context.x`

```
GPColorTokens.clay500      // primitive: a hex value, no meaning
        ↓
GPColors.accent            // role: what it is for
        ↓
context.colors.accent      // how a widget reads it
```

Primitives live in `core/theme/tokens/` and are the **only** place in `lib/`
holding a hex literal. Roles are `ThemeExtension`s, so Flutter interpolates
them across a theme change and a future density or high-contrast variant is a
different instance rather than a different code path.

Widgets never touch primitives. A widget that wants "the disabled border color"
asks for `outlineVariant`; re-theming is then one file instead of a grep.

### `core/theme/` for tokens, `app/theme/` for assembly

`CLAUDE.md` §4 puts `theme/` under `app/`. But `core/widgets/` reads tokens, and
a `core` file importing from `app/` inverts the dependency direction in §3. So
the split is by role: the tokens and extensions sit in `core/theme/`, and
`app/theme/app_theme.dart` holds only `GPAppTheme`, which folds them into one
`ThemeData` — composition, which is the composition root's job.

### The palette follows Claude / Anthropic, with two deliberate departures

Warm ivory ground, near-black warm ink, a single terracotta accent. Values were
sampled from the Claude interface and Anthropic's brand palette; there is no
published token export to pin against, so they are Pockit's palette, not a
mirror of somebody else's.

**Departure 1 — terracotta is the accent, not the action color.** Anthropic's
own CTAs are near-black and the orange is brand. That is also the accessible
reading: white on `#D97757` is 3.1:1, which fails AA for body text. So
`primary` is ink and `accent` is clay, as two roles.

**Departure 2 — a separate `accentInk`.** The terracotta reads at 2.96:1 as a
foreground on the ivory ground — below even the 3:1 that non-text UI owes. One
value cannot be both a fill that content sits on and a label sitting on the
ground, so there are two. This is the finding that shaped the focus ring: the
ring is drawn in `accentInk`, at full opacity rather than as a soft halo,
because a 24 %-alpha ring lands near 1.5:1 and WCAG 1.4.11 wants 3:1.

Status fills are darkened (light) and lifted (dark) from their obvious values
for the same reason. `test/core/theme/contrast_test.dart` recomputes every
pairing and fails the build below AA — which is how both departures above were
found rather than assumed.

### Inter, bundled, not `google_fonts`

Anthropic's Styrene and Tiempos are licensed and not distributable. Inter is
the closest open grotesque and holds up at 12sp in a dense list.

It is bundled as four static TTFs (~272 KB) rather than fetched by
`google_fonts`, because a font downloaded on first launch makes the first frame
of a cold start depend on connectivity — the exact property an offline-first
app exists not to have.

### From the kit: the architecture, not the values

Ported: the three-layer token structure, the `context.x` accessors, and
`GHAppButton` → `GPButton`, including its states-controller handling of the
"Material updates states during build" trap.

Re-cut on the way in:

| Kit                 | Pockit         | Why                                                |
| ------------------- | -------------- | -------------------------------------------------- |
| Finesse palette     | Claude-derived | the look this app wants                            |
| 120 px display step | 40 px          | the kit's scale is drawn for web                   |
| 5 button variants   | 6 roles        | no `secondaryGrey`; `danger` added, which W6 needs |
| 5 button sizes      | 3              | 40 / 48 / 56, with 48 the Android touch target     |
| 4 corner variants   | dropped        | nothing needs a pill yet (§12.11)                  |
| hover states        | dropped        | Android-first; a touch screen has no hover         |

Not ported: everything depending on `flutter_svg` and the bundled Heroicons —
alerts, snackbars, text fields, dropdowns. That is a dependency decision
(`CLAUDE.md` §13) and is deferred until a screen needs one, at which point the
question is whether to take `flutter_svg` + ~1 MB of SVG assets or to use
Material icons.

`GPEmptyState` is new. The kit has no equivalent, because an empty state is an
app concern; §11 makes it part of the definition of done and W5 ships the first
list that can be empty.

## Consequences

**Good.** Adding a role is one field plus its contrast assertion. Light and
dark are separate hand-checked palettes, not one inverted. Material's own
widgets inherit the palette through `toColorScheme()` / `toTextTheme()`, so a
`SnackBar` cannot appear in Material purple. Contrast is a build gate.

**Bad.** ~25 color roles is real boilerplate in `copyWith` and `lerp`, and every
new role touches four places. `freezed` would remove it but cannot generate a
`ThemeExtension`. Accepted as the cost of the analyzer knowing the role set.

**Owed.** No in-app light/dark switch: `themeMode` follows the device until
Settings has a `settings` table to persist a choice in (W2 flex) — the same
debt the language picker carries. `GPMoneyText` is not built; it needs `Money`
and tabular figures, which arrive in W3.

## Alternatives rejected

**`ColorScheme.fromSeed` with `ThemeExtension` only for extras.** Half the
palette derived, half declared, and no way to tell which is which when a color
looks wrong.

**Depend on `ngh09_ui_kit` as a package.** Would drag in `flutter_svg`, the
Heroicons assets and the Finesse palette to use a button, and would put the
app's visual language in another repo's release cycle. Porting two widgets and
the token structure is cheaper than owning that coupling.

**Plain `static const` tokens, no `ThemeExtension`.** Less boilerplate, but
themes stop interpolating and a second palette becomes an `if` in every widget.
