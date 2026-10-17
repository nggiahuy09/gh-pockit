# ADR 0015 — Amounts are typed cash-register style: the digits are the minor units

## Status

Accepted — 2026-10-12 (W6 T2). Applies to every amount a user types: the
transaction form's amount and the account form's opening balance.

## Context

The first forms that take money from a keyboard arrive at W6. ADR-0007 already
fixes what an amount _is_ — an `int` of minor units, never a `double` — but not
how a person types one. Two ways were on the table (the user chose on
2026-10-12):

1. **Free text, parsed by locale.** The field accepts a decimal separator, and
   `GPMoneyFormatter.parse` turns `12,50` (vi) or `12.50` (en) into 1250.
2. **Cash register.** The field accepts digits only; the digits typed are the
   minor units, and the field re-renders them formatted on every keystroke.
   `1250` in USD shows `12.50`; `45000` in VND shows `45.000`.

The ambiguity option 1 has to settle is real in this app: it ships Vietnamese
and English, whose separators are swapped. `1.500` is fifteen hundred dong to a
Vietnamese reader and one and a half to an English one, and a phone's language
and the reader's habit do not always agree. Every half-typed state (`1.`,
`1.50.`, a pasted `1,500.00`) is a parse that may fail or, worse, succeed as a
different number.

## Decision

**Cash register.** `GPMoneyInputFormatter` (`core/widgets/money_field.dart`):

- keeps the digits of whatever the field now holds, drops leading zeros, and
  renders `GPMoneyFormatter.format(Money(digits, currency), withSymbol: false)`
  with the caret at the end;
- caps input at 15 digits — exact in a JS `double` and far inside Postgres
  `bigint` (ADR-0007) — and refuses the keystroke past it rather than
  truncating;
- treats an emptied field as "nothing typed" (null), not zero.

`GPMoneyField` wraps it in a `TextField` and **keeps the caret at the end**: it
turns off interactive selection (no tap-to-place caret, no handles, no paste
menu) and collapses any other selection change back to the end. The formatter
alone is not enough, because a selection-only change never reaches it — found
on the simulator, where a tap left of the digits put the caret first and the
next 5 turned 45,000 into 545,000. With the caret pinned, a typed digit is
always appended and backspace always drops the last one. The symbol sits on
the side `GPMoneyFormatter.symbolAffixes` gives for the language, the same
side the list prints it (`₫45,000` / `45.000 ₫`).

It is a magnitude only: the sign belongs to the caller — the transaction's type,
or the account form's "I owe this" switch. When the currency changes under it
(another account picked) the digits stay and are re-read in the new exponent;
the field does not convert anything.

Nothing typed is submitted as zero, so the entity's "amount must be positive"
is what the user sees, not a disabled button with no reason given.

## Consequences

Positive:

- No string-to-number parse on the input path at all, so no separator
  ambiguity, no locale to get wrong, no `double` anywhere near it.
- One code path for VND, where it is indistinguishable from plain typing, and
  for USD.
- The field always shows a well-formed amount; there is no invalid state to
  validate.

Negative:

- A dollar amount needs its cents typed: `12` is twelve cents, `1200` is twelve
  dollars. Unfamiliar to someone used to free entry.
- The caret cannot be placed mid-number to fix one digit; the edit is always at
  the end. Nor can an amount be pasted or selected: the field has no menu.
  Fixing a digit means deleting back to it.
- Switching account mid-entry between currencies of different exponents
  changes the amount shown (450.00 USD from 45.000 VND). Acceptable while a
  transaction cannot span currencies; revisit with multi-currency.

## Alternatives rejected

**Free text parsed by locale.** `GPMoneyFormatter.parse` exists and is tested,
so the parser is not the cost. The cost is the ambiguity above, a new class of
"could not read that amount" failure, and the states in between keystrokes.

**A custom numeric keypad.** Solves the same problem with more surface: its
own keys, its own accessibility, and a keyboard the OS no longer provides.
Cash-register entry gets the guarantee with the system keyboard.
