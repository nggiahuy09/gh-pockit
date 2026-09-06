<!--
  DEFAULT PR template for gh-pockit — use this for features (branch: feat/<epic>-<slug>).
  See CLAUDE.md §10 (Git & PR) and §11 (Definition of Done).
  Delete sections that don't apply, but state "N/A — <reason>" instead of removing them silently.
  Title follows Conventional Commits: feat(sync): add durable outbox

  LIGHTER TEMPLATES — append the query param to the compare URL of your PR:
    ?expand=1&template=fix.md     bug fixes        (.github/PULL_REQUEST_TEMPLATE/fix.md)
    ?expand=1&template=chore.md   tooling/CI/deps  (.github/PULL_REQUEST_TEMPLATE/chore.md)
    ?expand=1&template=adr.md     ADR / docs       (.github/PULL_REQUEST_TEMPLATE/adr.md)
  Example:
    https://github.com/nggiahuy09/gh-pockit/compare/main...<branch>?expand=1&template=chore.md
  GitHub does not show a picker for PR templates, so the param is the only way to switch.
-->

## What

<!-- What changed, and in which layer. Short bullets. -->

-

## Why

<!-- The problem being solved. Link the issue / ROADMAP.md item / blueprint.md section. -->

-

## Architecture impact

<!-- Required. If nothing changes, write "No change" plus one sentence explaining why. -->

- **Layers touched:** presentation / domain / data / core
- **Dependency direction:** still `Presentation → Domain ← Data`? (no reverse imports)
- **Schema:** changed? `schemaVersion` old → new:
- **Sync behaviour:** how does this entity sync? (push/pull/no sync — must be decided, not left open)
- **New dependency:** no / yes (if yes, answer the 5 questions in CLAUDE.md §5)
- **ADR:** `docs/adr/NNNN-xxx.md` / not needed because:

## Screenshots

<!-- UI change: before/after. Include loading / error / empty states for new screens. Otherwise write "N/A — no UI change". -->

| Before | After |
| ------ | ----- |
|        |       |

## Testing

<!-- Which tests were written and run — not "tested manually". -->

- [ ] `dart format --set-exit-if-changed .`
- [ ] `flutter analyze` — 0 warnings
- [ ] `flutter test` — passing
- [ ] Unit tests for domain logic / Money / validation
- [ ] Repository tests (in-memory Drift)
- [ ] Migration test + old-schema fixture DB (if `schemaVersion` was bumped)
- [ ] Sync engine tests (fake clock + fake remote, no real `Future.delayed`)
- [ ] BLoC tests (`bloc_test`) for non-trivial state machines
- [ ] Widget tests for loading / error / empty states
- [ ] 50k-row benchmark (if heavy queries were touched)

**Manual verification:**

-

## Risks

<!-- What can break, and how it would be detected. Do not leave empty. -->

- **Risk:**
- **Blast radius:** (data loss / sync stuck / UI only)
- **Rollback plan:**
- **Migration reversible?** yes / no — if no, explain

## Definition of Done (CLAUDE.md §11)

- [ ] Domain rules implemented and validated in the domain layer
- [ ] Local persistence implemented
- [ ] Sync behaviour decided and documented (including when the decision is "no sync")
- [ ] Loading / error / empty states have UI
- [ ] Unit tests for the important logic
- [ ] Migration + migration test (if the schema changed)
- [ ] No analyzer warnings
- [ ] Docs / ADR updated

## Golden rules self-check (CLAUDE.md §2)

- [ ] Money is `int` minor units via `Money` — no `double`
- [ ] Entity write + outbox mutation commit in the **same** DB transaction
- [ ] IDs generated client-side (UUID), not waiting on the server
- [ ] Delete is a soft delete (`deleted_at`)
- [ ] No `sync_mutations` deleted before a successful response is received
- [ ] Presentation does not import `dio` / `drift` / `supabase_flutter` / DTOs
- [ ] No financial payloads logged (amount, note, email, token)
- [ ] Database not wiped to avoid writing a migration
