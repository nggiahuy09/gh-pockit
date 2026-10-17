# ADR 0016 — A refused save is shown on the field it is about, one at a time

## Status

Accepted — 2026-10-12 (W6 T3). Applies to every form; the transaction form and
the account form are the first two.

## Context

Every rule already runs in the domain (ADR-0010): the entities refuse their
own fields, the repository refuses an account that is gone or a currency that
does not match, the use cases refuse a category of the wrong kind. Each
refusal is a `GPValidationCode`, and `GPFailureMessage` gives every code a
sentence in both languages through a switch with no wildcard. What the forms
did with that sentence was put it in one banner above the Save button — far
from the amount field it was about, often under the keyboard, and with nothing
telling a screen reader which field to fix.

Two choices shape the rest; the user made both on 2026-10-12:

1. **When.** Validate on save only, or, after the first refused save, ask the
   domain again on every edit (which needs a write-free `validate` entry point
   on each entity).
2. **How many.** Show the first refusal, or all of them (which needs the
   entities to collect failures instead of returning at the first).

## Decision

**On save, one at a time, on its field.**

- The domain is unchanged. It still returns the first failure in form order
  (amount, destination, note), so the first error is always the topmost field.
- Each form has a field enum and a mapping from a failure to the field that
  fixes it — `transactionFormFieldOf`, `accountFormFieldOf`, in presentation.
  The inner switch over `GPValidationCode` has no wildcard, like the message
  switch: a new code does not compile until someone decides where it shows.
  A code with no field in this form (another form's, a transfer's while the
  form offers none, a refused delete) maps to null.
- A failure with a field shows as that field's `errorText`, and focus moves to
  the field: a text field scrolls itself into view, a dropdown is scrolled with
  `Scrollable.ensureVisible`. A failure with no field — a conflict, a row gone
  meanwhile, a read failure — stays in `GPFormFailureBanner`. Never both.
- An edit clears the failure it can fix: one about the edited field, or one
  about no field. An amount error survives typing a note; a conflict banner
  goes at the first edit, since the next save will tell anew.

## Consequences

Positive:

- The message sits where the fix is, and the focus goes there too.
- No domain API change; the forms keep one source of truth for the rules.
- Adding a validation code forces a placement decision in every form, at
  compile time.

Negative:

- A form with two wrong fields shows them one save at a time. Today each form
  has one field a user can actually get wrong (the amount; the account name);
  the transfer flow adds the destination.
- An error does not disappear the moment the input becomes valid, only when
  its field is edited: typing a 0 into the amount clears the "must be greater
  than zero" error until the next save says it again.

## Alternatives rejected

**Live re-validation after the first save.** Errors that track the input
exactly, at the price of a `validate` entry point per entity and a second path
into the rules that must stay identical to the one the write uses.

**All failures at once.** A list-valued `GPValidationFailure` changes every
site that matches on a single code, for forms that today cannot produce two.
Worth revisiting if a form grows several independently wrong fields.
