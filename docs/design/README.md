# Design

The code is the source of truth for tokens (`lib/core/theme/`, ADR-0005). The design files follow it, never the reverse.

| What                                                                                                                              | Where                                              |
| --------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| Canvas "Pockit Design": Foundations page (colors, type, components, screens) and the W5 page (transaction list, states, variants) | https://claude.ai/artifact/2GNXWS9rQJKzPVd7KUyZ8d  |
| Design system source, for re-syncing the design tool from code                                                                    | [design-system-source.md](design-system-source.md) |
| W5 brief: list screen, `GPMoneyText`, T5 states                                                                                   | [w5-ui-brief.md](w5-ui-brief.md)                   |

Each week gets its own page on the canvas. When a week ends, promote its finished components to Foundations.
