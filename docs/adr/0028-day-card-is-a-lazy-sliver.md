# ADR 0028 — A day card is a lazy sliver: a new window rebuilds a screenful, not every row

## Status

Accepted — 2026-11-04 (W9 T6).

## Context

The transaction list is one live query whose limit grows by 50 on every load-more (ADR-0011). Each new window re-emits every row, and the
list rebuilt every one of them. Each day was a `SliverMainAxisGroup` holding a pinned header and a `SliverToBoxAdapter` around a `Column`
of all that day's rows. A box child of an adapter is built and laid out in full, on screen or not.

W9 measured what that costs:

- **iPhone 15, 10k, profile.** The average frame builds in 3 ms, but 51 frames went over budget, with p99 at 44 ms and the worst at
  108 ms (`docs/benchmarks/10k.md`).
- **Android emulator, 50k, profile.** The device test matched every slow frame to the list snapshot before it (ADR-0026, amended):
  - 19 to 28 of 26 to 29 new windows were followed by a slow frame;
  - that frame's build time grew with the window, from 33 ms at 100 rows to 2,496 ms at 1,250 rows.

Mapping the rows on the UI isolate is not the cause. On the host, a 2,000-row window costs about 85 ms to read and map, and that work runs
outside the frame. It never shows as build time.

## Decision

**`TransactionDayCardWidget` returns a sliver.** It is a `SliverPadding` around a `DecoratedSliver`, which paints the rounded card and its
shadow, around a `SliverList.builder` of the day's rows. Only the rows inside the viewport and its cache extent are built and laid out.

- **Keys.** Each row is keyed by its transaction id, and `findChildIndexCallback` finds a row by that key. A row keeps its state, such as a
  swipe in progress, when a write above it shifts the indexes.
- **Rounded ends.** The card has rounded corners, so only its first and last rows clip, to the card's top and bottom radius. The ripple and
  the red swipe background stay inside the corners, and the rows in between pay for no clip.
- **Ripples.** Each row carries its own transparent `Material`, so its ripple still draws above the card's colour.

The day grouping, the pinned headers and the view's layout do not change.

## Consequences

Positive:

- Measured on the emulator at 50k, median of three runs, the same 30 flings before and after:

  | | Before | After |
  | --- | ---: | ---: |
  | Build, average | 29.4 ms | 5.9 ms |
  | Build, p90 | 33.3 ms | 13.1 ms |
  | Build, p99 | 599 ms | 42.0 ms |
  | Build, worst | 1,921 ms | 132 ms |
  | Frames over the build budget | 301 of 1,166 | 131 of 1,818 |
  | Rows reached in the 30 flings | 1,350 | 1,700 |

  The frame after a new window now builds in 17–58 ms whatever the window's size (200 to 1,900 rows). Before, it grew with the window.
- A widget test pins the laziness: a 300-row window builds fewer than 30 rows.

Negative:

- A row that leaves the cache extent is disposed, so a test can no longer find an off-screen row. The pinned-header test now checks that
  the first rows are gone, instead of reading their position.
- The window itself still grows: each load-more reads and maps every row again, about 40 µs a row on the host. Keyset pagination (W26 T2)
  remains the fix for that, if it starts to show.
- The list still creates one `SliverMainAxisGroup` per day of the window. That is cheap per day, but it is not zero.

## Alternatives rejected

**One flat `SliverList` with headers as items.** It would be fully lazy, but the headers would stop being pinned, and the card per day
would have to be drawn from row positions.

**Keyset pagination now.** It cuts the read and the mapping too, but it changes the bloc and the query contract (ADR-0011) and is scheduled
for W26. The build cost was the visible jank, and fixing it does not need the query to change.
