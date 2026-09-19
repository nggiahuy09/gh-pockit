# ADR 0006 — Repositories return a result type; only bugs throw

## Status

Accepted — 2026-09-18 (W2 T5)

> Numbered sequentially, not from Appendix E of `docs/blueprint.md`. That list
> reserved 0006 for version-based conflict detection; the repo diverged at 0003
> and the numbers are now in the order decisions were actually made. Conflict
> detection keeps its own ADR when the sync engine lands in P4 — this one only
> decides how a conflict _reaches_ the caller.

## Context

`AccountRepository` (W2 T5) is the first repository interface in the app, so its
signature is the template every later one copies. The question it has to settle:
when a write fails, does the caller find out by catching something or by reading
something?

Three properties of this app make the answer less obvious than the usual
"exceptions are for exceptional things".

**1. A failed write is silent by construction.** The local DB is the source of
truth and the UI reads a Drift stream off it (golden rule 1). A successful write
therefore announces itself — the stream re-emits and the screen updates with
nobody asking. A failed write announces nothing, because nothing changed. So a
`BLoC` that forgets a `try/catch` does not produce a visible error; it produces a
screen that did not move. The user pressed Save, saw no change and no message,
and has no way to tell "it saved and looks the same" from "it did not save".
That failure mode does not exist in a request/response app, where the absent
response is itself the signal.

**2. Conflict is an ordinary outcome, not an exceptional one.** Under the
optimistic versioning of §7, `GPConflictFailure` is what a perfectly correct edit
returns when another device touched the row first. On a two-device account that
is normal use, not an anomaly. Routing it through the same channel as a null
dereference means it arrives at whatever generic handler catches last.

**3. Validation is the user typing.** A blank account name is not a bug. It is
the most common thing that will ever go wrong in this app, and the screen has to
answer it with a message under the right field.

## Decision

**Every repository method that can fail in a way a user should hear about returns
`GPResult<T>`.** `GPResult` is a sealed class in `lib/core/error/` with two
subtypes, `GPOk<T>` carrying the value and `GPErr<T>` carrying a `GPFailure`.

**The dividing line is: could a correct program with a correct user produce
this?**

- **Yes → `GPResult`.** Validation, conflict, a local DB that refused, and later
  every network and auth failure the sync engine surfaces.
- **No → throw.** A currency mismatch in `Money` arithmetic, a malformed currency
  code, a broken invariant. These are `Error` subtypes, not `Exception`s, they
  have no user-facing message, and they should crash a debug build. Wrapping them
  in `GPResult` would teach callers to handle bugs, which is the opposite of what
  should happen to a bug.

**Reads stay plain streams.** `watchAccounts()` returns
`Stream<List<AccountEntity>>`, not `Stream<GPResult<List<AccountEntity>>>`. Errors travel on
the stream's own error channel, which `BLoC` already routes into a state.
Wrapping each emission would make the common path — there are accounts, render
them — pay for the rare one, in every widget.

**`GPResult` is hand-written, not `dartz` or `fpdart`.** §5 requires answering
what it would cost to do it ourselves before adding a dependency: the answer is
one 60-line file, most of it comment. `Either<L, R>` would also import a
vocabulary (`fold`, `bimap`, monad transformers) this codebase would use
inconsistently, and `Left`/`Right` are worse at a call site than `GPOk`/`GPErr` —
one requires remembering that failure conventionally sits on the left, the other
says which is which.

**`GPValidationFailure` gains a `GPValidationCode`.** Its own doc comment
predicted this for W4; `AccountEntity` brought the first real rules forward to W2 T5,
and it has two of them. One constant per rule, one `l10n.error.*` getter per
constant, mapped through the existing exhaustive switch in
`failure_message.dart`. The generic `l10n.error.validation` string is deleted, so
a new rule cannot fall back to "Please check the information you entered".

Validation messages carry no limit numbers: `AccountEntity.nameMaxLength` lives in a
feature's domain, presentation must not import it to build a sentence, and a
hard-coded `100` in two languages goes stale silently. The form field shows the
limit with a live counter instead — which tells the user before they hit it
rather than after.

## Alternatives

**Throw a `GPFailureException` and catch it in the BLoC.** Less code at the
repository, and it matches what most Flutter tutorials show. Rejected on
property 1 above: the compiler cannot tell a caller it forgot to catch, and in
this architecture forgetting produces a screen that silently does nothing rather
than a visible crash. It also makes conflict — a routine outcome — indistinguishable
in shape from a null dereference.

**Nullable returns (`Future<AccountEntity?>`).** Cheapest of all, and enough to say
_that_ something failed. Rejected because it cannot say _which_ failure, so the
UI can only ever show one message. "Account name can't be empty" and "This item
was changed on another device" need different words and different buttons.

**`Either<GPFailure, T>` from `dartz`/`fpdart`.** Same shape, plus combinators
this project does not need and a dependency §5 would have to justify. Rejected on
cost: see above.

**Wrap stream emissions too.** Uniform, and it would let a list screen render an
error state without a separate channel. Rejected because every widget and every
test would unwrap on the path that always succeeds, and `BLoC`'s existing
`onError` handling already gives the error state a home.

## Consequences

**What it buys.**

- A caller cannot reach the value without naming the failure branch, so "nothing
  visibly happened" stops being reachable by omission.
- Conflict, validation and DB failure are each a `switch` arm somebody had to
  write, which means each has a screen state and a sentence.
- Adding a failure type or a validation code without deciding what the user reads
  for it does not compile — the sealed switch in `failure_message.dart` and the
  nested switch over `GPValidationCode` both break.
- Tests read as `expect(result, GPErr(GPValidationFailure(code)))` instead of
  `expect(() => ..., throwsA(isA<...>()))`, which asserts the specific failure
  rather than merely that something was thrown.

**What it costs.**

- Every write call site is a `switch` or a pattern match. That is the noise the
  decision is buying the guarantee with, and it is real.
- `GPErr<void>` and `GPErr<AccountEntity>` are different types, so a repository
  implementation that wants to forward a failure across methods must rebuild it.
  Annoying, and an `Either` would have exactly the same problem.
- `GPResult` has no `map`/`flatMap`. Deliberate — §12.11 — and if chaining ever
  gets painful, that is the moment to add one method, not a functional library.

**What is still open.**

- Use cases (W4 flex) return `GPResult` unchanged; whether they ever _translate_
  a failure is undecided and will be decided when the first one needs to.
- No app-wide policy says _where_ a failure is logged. W2 T6 set a shape rather
  than a rule: `AccountRepositoryImpl` logs at `error` with `{entity, id}` and,
  for a row it could not parse, an `AccountMapperReason` code. That is what
  golden rule 9 allows and nothing more. Whether every repository does the same,
  and what the sync engine adds, is worth writing down at P4.
- **A corrupt local row has no way out, and this is debt, not a decision.**
  `AccountRepositoryImpl.watchAccounts` fails the whole list when one row will
  not map, on the argument that an account silently missing from a list and from
  a balance is worse than an honest error state. That argument still holds, and
  it has a hole: there is no repair path. A user with one bad row gets an
  accounts screen that errors forever. `deleteAccount(id)` would fix it — it is
  a plain `UPDATE` and never touches the mapper — but nothing in the UI can
  surface the id to delete. The id _is_ in the log, next to the reason that
  refused it, so the information exists; what is missing is a way for anyone but
  a developer holding logcat to act on it. A quarantine or diagnostics path
  belongs with P4's sync engine or P7's crash reporting, and until one exists
  this policy is a bet that local rows do not corrupt.
- **That policy must be decided again at W4 T6, from scratch.** With five
  accounts, one bad row taking down the list is proportionate. With 50k
  transactions it hides a year of history, and the middle ground — emit the good
  rows plus a non-blocking warning — needs a stream shape this interface does not
  have. Inheriting the `accounts` answer by copy-paste is the failure mode.
- **Conflict resolution needs no extra read, and W20 should not add one.**
  `GPConflictFailure` carries two version numbers and not the remote entity,
  which looks like it forces the caller to re-read. It does not: a detail screen
  is already subscribed to `watchAccount(id)`, so the fresh row has arrived
  before the conflict returns. Putting the remote entity in the failure would
  also drag a feature's entity into `core/error/`.
