# ADR 0007 — Store money as integer minor units

## Status

Accepted — 2026-09-27 (W3 flex)

> Numbered sequentially, and for once the sequence and Appendix E of
> `docs/blueprint.md` agree: both put this decision at 0007.
>
> Written after the fact. Golden rule 2 has been binding since W1, `Money`
> landed at W2 T5 and `GPMoneyFormatter` at W3 T4, so this record states what
> the code already does — every claim below can be checked against
> `lib/core/money/` and its tests.

## Context

Adding amounts is most of what this app does. A balance is
`initial_balance + SUM(transactions)` (§6), a budget compares a sum against a
limit, analytics groups sums by month. How an amount is represented therefore
decides whether those numbers are right, and three properties of Pockit make
the choice less free than "pick a numeric type".

**1. A ledger has to agree with itself.** In IEEE-754 doubles
`0.1 + 0.2 == 0.30000000000000004`, and because floating-point addition is not
associative, the same transactions summed in a different order can land on a
different total. On a dashboard that is the headline balance and the sum of the
per-account balances disagreeing by a cent — which a user notices and nobody
can explain.

**2. The same integer means different amounts in different currencies.** VND
has no subunit in circulation (ISO-4217 exponent 0) and USD has cents
(exponent 2), so `1234` is either 1.234 ₫ or $12.34. An amount that travels
without its currency cannot be read.

**3. An amount crosses three number systems.** SQLite has `INTEGER` (64-bit
signed) and `REAL` (a double). JSON, on the wire from P4, has one number type,
and Dart's `jsonDecode` hands `1234` back as an `int` but `12.34` as a
`double`. Postgres, mirrored at W10, has `integer`, `bigint` and `numeric`.
Whatever the representation is, it has to cross all three unchanged.

## Decision

**An amount is an `int` count of the currency's smallest unit, and it never
travels without its ISO-4217 code.** In Dart that pair is `Money`
(`lib/core/money/money.dart`): `minorUnits` and `currencyCode`. `1500000` with
`VND` is 1.500.000 ₫; `1234` with `USD` is $12.34. No `double`, `num` or
decimal type appears anywhere on the path from storage to screen.

- **Stored as two columns, `INTEGER` + `TEXT`** — `accounts.initial_balance`
  and `accounts.currency_code` today, the same pair on `transactions` at W4
  (blueprint §20 already gives each transaction row its own `currency_code`).
  The currency column carries `CHECK(LENGTH(currency_code) = 3)` in the
  `CREATE TABLE` itself, because it decides how the integer beside it is read.
- **The exponent is not stored.** It is a fact about the currency, looked up in
  the `CurrencyCode` catalog (VND 0, USD 2) when an amount is shown or parsed.
  A per-row exponent would let two rows disagree about what VND is.
- **Validation is split in two.** `Money` checks the _shape_ of a code — three
  uppercase letters, the minimum for the integer to be interpretable at all.
  `CurrencyCode` checks _membership_ — which currencies this build can render.
  A well-formed code the catalog does not know, such as a row written by a
  newer build, survives the round trip and prints as exponent 0 plus the raw
  code rather than being guessed at.
- **Combining two currencies is a bug, not an outcome.** `+`, `-` and every
  comparison throw `MoneyCurrencyMismatchError`, which is an `Error`
  (ADR-0006). There is no implicit conversion: a conversion needs a rate and a
  date, and that is a feature with its own design (multi-currency, W37+) or it
  is absent.
- **The range is 64-bit and it wraps — recorded, not guarded** (W3 T3). The
  ceiling is 9,223,372,036,854,775,807 minor units, which in VND is more dong
  than exist. A guard would put a branch on every addition to defend a bound no
  personal ledger reaches. `money_test.dart` asserts the wrap, so it stays a
  decision rather than turning into a surprise.
- **No `double` on the way to the screen, or back.** `NumberFormat.format`
  takes a `num`, so the obvious call computes `minorUnits / 100`.
  `GPMoneyFormatter` splits the amount with `~/` and `remainder` instead, hands
  `intl` only the integer part — always an exact `int` — and joins the
  fraction as digits. Parsing runs the other way: the digit string becomes the
  integer through `int.tryParse`, and more fractional digits than the currency
  has is a rejection, not a rounding.

## Alternatives

**`double`.** What most tutorials use, and what `NumberFormat.format`'s
signature invites. Rejected on property 1: rounding error accumulates and
depends on order, integers are exact only up to 2^53, and every display and
every parse becomes a rounding policy somebody has to own.

**An arbitrary-precision decimal (`package:decimal`).** Exact, and it can hold
fractions of a cent, which exchange-rate maths eventually wants. Rejected for
the stored amount on three counts. It is a dependency §5 would have to justify
for a guarantee `int` already gives inside any real balance. No SQLite type
holds it, so it would be stored as `TEXT` and `SUM()` could not run in SQL —
W7's aggregates would have to load every row into Dart, turning the 50k-row
benchmark into a parse loop. And every arithmetic operation allocates. It may
come back for the _rate_ when multi-currency lands, not for the amount.

**Integer major units** (`1500000` for 1.500.000 ₫, `12` for $12). Correct for
VND and for nothing else: the cents are gone.

**One fixed scale for every currency** (everything ×100, or "micros" ×10^6).
One exponent everywhere and a simpler formatter. Rejected because a raw VND row
then reads wrong by that factor — `150000000` for 1.500.000 ₫ in every SQL
query and every debugging session — while ISO-4217 already defines the right
exponent for each currency.

**The amount as `TEXT` (`'12.34'`).** Readable and exact. Rejected because
SQLite can only sum it after `CAST(... AS REAL)`, which is a double again, and
because it compares lexicographically: `'9' > '10'`.

**Amount and currency packed into one column** (`'1234 USD'`, or an integer
with the currency folded in). One field that cannot come apart. Rejected
because it can be neither summed nor grouped by currency in SQL.

## Consequences

**What it buys.**

- Exact arithmetic inside the range, in any order. The dashboard total and the
  sum of the account balances are the same number by construction.
- `SUM()` runs inside SQLite on an `INTEGER` column, so a balance can be the
  indexed aggregate §6 asks for rather than a loop in Dart.
- A raw row reads as an amount once you know its currency: `1500000` beside
  `VND` is exactly what it looks like.
- An amount cannot lose its currency. `Money(0, 'VND') != Money(0, 'USD')`, and
  `AccountEntity.initialBalance` is one field, not two.
- A mixed-currency sum crashes a debug build instead of producing a plausible
  wrong number.

**What it costs.**

- Every amount on screen goes through `GPMoneyFormatter`, and every typed
  amount through its `parse`; there is no `toString()` shortcut. That is a
  class of our own on top of `intl`, and it exists only because `NumberFormat`
  takes a `num`.
- Fractions of a minor unit do not exist. Splitting 100 ₫ three ways, or
  spreading a monthly budget over its days, needs an explicit allocation rule
  at that call site. None exists yet; the first feature that divides an amount
  writes one.
- Overflow is silent in Dart: `+` past the ceiling wraps to a negative number.
- **Nothing mechanical enforces the rule.** In Dart `int / int` is a `double`,
  so `minorUnits / 100` compiles, passes the analyzer and is precisely the bug
  this ADR exists to prevent; only `~/` stays an `int`. Review is what catches
  it. W3's done criterion — no `double` related to money anywhere in the
  codebase — was checked by hand on 2026-09-27: every `double` left in `lib/`
  is a layout dimension or a typography token.

**What it commits later work to.**

- **W4 T2.** `transactions` stores its amount as `INTEGER` minor units with a
  `currency_code` on the same row (blueprint §20), and its mapper either
  builds a `Money` from both or refuses the row, as `AccountMapper` does.
- **W7 aggregates.** `sum()` only. In Drift, `sum()` on an `int` column is an
  `Expression<int>`, while `total()` and `avg()` are `Expression<double>` and
  must never touch an amount. SQLite draws the same line: `SUM()` over integers
  raises `integer overflow` rather than wrapping, whereas `TOTAL()` silently
  returns `9.2233720368547758e+18` for the same input. A loud error is the
  better failure; a quiet float is the one this ADR forbids.
- **W10 Postgres.** Amount columns are `bigint`. `integer` is 32-bit and tops
  out at 2,147,483,647 minor units — 2.1 billion ₫, less than an apartment in
  Hanoi. `numeric` is a decimal type and would reopen every question above at
  the API boundary.
- **P4 DTOs.** An amount on the wire is a JSON integer, and a DTO reads it as an
  `int`. Anything else — `12.34`, `"1234"` — is a malformed payload, never
  something to round into an amount the user did not enter.

**What is still open.**

- The allocation rule for dividing an amount, above.
- Multi-currency (W37+). Blueprint Appendix §A keeps each transaction in its
  original currency and never rewrites history when a rate moves, which this
  representation already supports. The exchange rate itself needs more
  precision than a minor unit, and that is where a decimal type may earn its
  dependency.
- `Money.fromStorage` is named for its only untrusted source today, SQLite.
  The first DTO that parses a currency code off the wire will call it too, and
  the name should be revisited then — the class doc says the same.
