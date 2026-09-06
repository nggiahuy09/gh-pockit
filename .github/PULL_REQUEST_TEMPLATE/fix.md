<!--
  Bug fix template. See CLAUDE.md §10 (Git & PR).
  Branch: fix/<slug>   Title: fix(scope): short description
  For features use the default template (no ?template= needed).
-->

## What

<!-- What was broken, and what this PR changes. -->

-

## Root cause

<!-- The actual mechanism, not the symptom. "Outbox mutation was deleted before the response arrived" — not "sync was flaky". -->

-

## How it was found

<!-- Repro steps, crash report, failing test, user report. Include the repro if there is one. -->

-

## Blast radius before the fix

- **Who/what was affected:** (data loss / sync stuck / stale UI / cosmetic)
- **Is existing bad data left behind?** no / yes — recovery plan:

## Architecture impact

<!-- Most fixes are "No change". If the fix required a structural change, use the default template instead. -->

- **Layers touched:**
- **Schema:** unchanged / changed → `schemaVersion` old → new + migration test
- **Sync behaviour:** unchanged / changed →
- **ADR needed?** no / `docs/adr/NNNN-xxx.md`

## Testing

- [ ] **Regression test added that fails without this fix** (required)
- [ ] `dart format --set-exit-if-changed .`
- [ ] `flutter analyze` — 0 warnings
- [ ] `flutter test` — passing
- [ ] Migration test (if the schema changed)

**Manual verification:**

-

## Risks

- **Risk of the fix itself:**
- **Rollback plan:**
