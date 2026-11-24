# ADR 0043 — Appearance is a device setting, read before the first frame

## Status

Accepted — 2026-11-24 (W12, the appearance-mode item added to the plan on 2026-11-15). No schema change: one key in the key/value
`settings` table.

## Context

- The app already has light and dark themes (ADR-0005) and has always followed the system (`MaterialApp` default `ThemeMode.system`).
- The W12 plan adds a manual choice: system, light or dark. CLAUDE.md §1 ranks it low against sync work, so it comes after T6.
- The language is the precedent (ADR-0004):
  - a `settings` row behind a store that never throws;
  - a `ChangeNotifier` read before `runApp`;
  - an `InheritedNotifier` scope;
  - a radio list in Settings, applied on tap.
- The design canvas draws a separate Appearance screen, reached from a Profile screen that does not exist yet.

## Decision

1. **`GPThemePreference { system, light, dark }`**, stored by a `storageValue` rather than the Dart name, so a rename is not a data
   migration. An unknown stored value means no choice, never a guess.
2. **`GPThemePreferenceStore`, backed by the `settings` key `theme.mode`** (`GPDriftThemePreferenceStore`):
   - a read that fails follows the system;
   - a write that fails is logged, and the screen keeps the choice until the next launch;
   - neither throws.
3. **`GPAppearance`** (a `ChangeNotifier` and a DI singleton) holds the choice.
   - The bootstrap calls `init()` right after the language, before `runApp`, so a dark choice never paints one light frame first.
   - `change()` repaints before the write lands, since there is nothing to roll back.
4. **`GPApp` listens to the localization and the appearance together** and passes `themeMode` to `MaterialApp`. It also provides
   `GPAppearanceScope` above the routes, so Settings reaches the controller through `context.appearance`, not DI, as it does for the
   language.
5. **Device-local:** never synced, never enqueued, and kept by a sign-out, which keeps `settings` (ADR-0042, decision D).
6. **In Settings, a radio list under the language:** "Theo hệ thống" (with "Sáng hay tối theo cài đặt của máy"), "Sáng" and "Tối".
   It sits inline rather than on its own screen, like the language, until a Profile screen exists to hold both rows.

## Consequences

Positive:

- A dark choice holds from the very first frame and survives relaunches and sign-outs.
- It follows the language's pattern, so there is no new mechanism to learn or test.

Negative:

- **One more `settings` read before the first frame**, on every launch.
- **Every test that pumps `GPApp` needs a `GPAppearance`.** `registerShellFakes` and three page tests register one, and
  `localizedHarness` provides the scope.
- **Not on its own screen as the canvas draws it.** When Profile arrives, it becomes a row there opening this same list.

## How it is validated

- `appearance_test.dart` covers:
  - the preference's storage round trip and `ThemeMode` mapping, with an unknown value giving no choice;
  - the controller following the system with nothing stored, starting on a stored choice, and repainting and storing once per change;
  - the Drift store on an in-memory database: nothing stored, an overwrite, a corrupt row, and a dropped table that neither read nor
    write throws on.
- `app_test.dart`: `GPApp` starts on a stored dark choice. Picking Dark in Settings repaints the whole app and stores it.
- `injector_test.dart`: the store is the Drift one, and the appearance is a singleton.
- iPhone 17 Pro simulator, local-only build, simulator in light mode: Settings → Tối turned the whole app dark at once, `settings` held
  `theme.mode = dark`, and a relaunch opened dark. The test row was removed afterwards.

## Alternatives rejected

**Reading the choice in `GPApp` after the first frame.** That paints one light frame before the dark one, which is the flash the plan
names.

**Syncing it with the account.** A theme belongs to a device, as the language does: two phones of one user can choose differently.

**A separate Appearance screen now**, as the canvas draws it. It would be reached from Settings, one level deeper than the language next
to it, for the sake of a Profile screen that does not exist yet.
