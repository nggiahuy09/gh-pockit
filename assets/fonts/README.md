# Inter

SIL Open Font License 1.1 — https://github.com/rsms/inter

Bundled as static TTF weights rather than pulled at runtime through `google_fonts`, on purpose. Pockit is offline-first (CLAUDE.md §1): a font
fetched over the network on first launch means the first frame of a cold start depends on connectivity, which is exactly the property this app exists
to not have. 4 weights × ~68 KB ≈ 272 KB is the price, paid once in the bundle.

Copied from `ngh09_ui_kit` (branch `dev`).
