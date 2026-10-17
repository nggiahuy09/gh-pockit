# ADR 0018 — The shared inputs follow the Pockit Design canvas: a sheet picks, a dialog decides

## Status

Accepted — 2026-10-14 (W6). Adds the components on the canvas's Foundations
page to `core/widgets/`, and moves the account form, the transaction form,
the swipe-to-delete dialog and the settings page's language picker onto them.

## Context

The Foundations page of the Pockit Design canvas specifies eight components
that `core/widgets/` did not have: GPTextField, GPSwitch, GPSelect, GPDialog,
GPDatePicker, GPChip, GPProgressBar and GPRadio (with GPRadioList). The tokens they use (color, type,
spacing, radius, shadow, motion) already matched `core/theme/` value for value.
Only a scrim was missing.

The forms use Material's `TextFormField`, `DropdownButtonFormField`,
`SwitchListTile`, `showDatePicker` and `AlertDialog`. Those widgets float the
label into the box, put a menu over its own field, show a calendar with a
typed-entry mode and an OK button, and allow any number of dialog actions.
The canvas specifies something different for each one.

## Decision

**Build the canvas's components as GP widgets, with these rules built into
them rather than left to each screen.**

- **A sheet picks, a dialog decides.** `showGPSheet` is the only bottom sheet:
  a drag handle, a title, surface color, dismissed by a swipe, the scrim or
  Back, which return null so the caller keeps its value. `showGPDialog` takes
  one or two actions. Its assert refuses a third: three or more choices go in
  a sheet.
- **GPSelect opens a menu for up to five options and a sheet for six or
  more** (`GPSelect.menuLimit`). The menu opens under the whole field,
  including its help line, so it never covers the error it is being used to
  fix. If there is no room below, it opens above.
- **A radio list is for settings; a form uses GPSelect.** `GPRadioList` is a
  card of rows at least 56 px tall, for two to five choices that should all be
  visible at once. A tap anywhere on a row applies the choice; there is no
  Save button. The selected row shows a weight of 500 rather than a fill, so it
  cannot be mistaken for the highlighted item of a GPSelect menu. The arrow
  keys move the choice, skipping disabled options and wrapping at either
  end.
- **Every field puts its label above a 56 px box.** GPTextField, GPSelect and
  GPDateField share `GPField`, `GPFieldBox` and `GPPickerField`. A focused
  field shows a 2 px accentInk edge and an error shows a 2 px danger edge,
  with no change in height. The error line keeps the ADR-0016 contract: the
  form passes `errorText`.
- **The date picker has no typed entry and no OK for a single day.** Tapping a
  day answers. A range answers on Apply. Days after `lastDate`, which defaults
  to `today`, cannot be tapped. That default is a UI choice and not a domain
  rule: the transaction entity accepts a future `occurredAt`. The transaction
  form keeps the bounds it had before the move, a year ahead for a planned
  expense and widened to the day being edited. Weeks start on Monday.
- **A dialog's initial focus goes to Cancel when the other action is
  `danger`.** Otherwise it goes to the action the dialog is asking for. Two
  labels that each fit half the width sit side by side with Cancel on the
  left. Otherwise the buttons stack with the answer on top.
- **The progress bar decides thresholds on integers.** `GPProgressTone.of`
  compares `value * 100` with `max * 85` in minor units. A spending bar turns
  warning at 85% and over at 100%. A goal bar is always success. Color is never
  the only signal: `GPProgressStatus` adds an icon and text.
- **The scrim is a role**, `GPColors.scrim`: ink at 32% on light, black at 50%
  on dark. That keeps the widgets on roles (ADR-0005).
- **The widgets own their strings** in a new `GPLocaleBase.widgets` section
  (ADR-0004): month and weekday names, presets, accessibility labels. A
  `core/` widget must not reach into a feature's strings. That is why
  `gpDateLabel` duplicates `transactions.today` and `transactions.yesterday`.

## Consequences

- `GPMoneyField` draws through `GPTextField`, so the amount has the same frame
  as every other field. The currency symbol is now a separate prefix or
  suffix, trimmed of the no-break space the formatter puts in it.
- The transaction type is a row of single-choice `GPChip`s, not a
  `SegmentedButton`.
- The form tests find a field by its `GPField` label, since the label is no
  longer inside the `TextField`. The transaction form outgrows the test
  screen, so its tests scroll to Save before tapping it.
- The settings page drops the "Language / current language" tile above the
  options. The section title and the selected row already show both.
- `gpDateLabel` and the transaction list's `dayLabel` format a day the same
  way. `dayLabel` can call `gpDateLabel` once someone touches the list.
- A semantics rule learned while building these: `Semantics(excludeSemantics:
true)` also drops the tap and the focus of the gesture under it. Each such
  node sets `onTap` (and `focusable`) itself, and the tests check
  `hasTapAction`.
