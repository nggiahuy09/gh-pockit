<!--
  ADR / docs template. See CLAUDE.md §2 rule 10: no ADR = the decision does not exist.
  Branch: docs/adr-<slug>   Title: docs(adr): short description
  If this PR also ships code implementing the decision, use the default template instead
  and link the ADR from its Architecture impact section.
-->

## ADR

- **File:** `docs/adr/NNNN-xxx.md`
- **Status:** proposed / accepted / supersedes `NNNN-yyy.md`

## Decision

<!-- One or two sentences. What are we committing to? -->

-

## Context

<!-- What forces this decision now. Link the ROADMAP.md phase / blueprint.md section that triggered it. -->

-

## Options considered

| Option | Pro | Con | Verdict           |
| ------ | --- | --- | ----------------- |
|        |     |     | chosen / rejected |
|        |     |     | chosen / rejected |

## Consequences

- **What becomes easier:**
- **What becomes harder / what we give up:**
- **What this locks in** (how expensive to reverse later):
- **Golden rules affected** (CLAUDE.md §2): none / rule N because:

## Scope of this PR

- [ ] Docs only — no code change
- [ ] Follow-up implementation tracked in: <!-- issue / ROADMAP.md item -->

## Testing

- [ ] `dart format --set-exit-if-changed .` (if any code/sample was touched)
- [ ] Links and file references in the ADR resolve
- [ ] `CLAUDE.md` §14 "ADR mới nhất" updated
- [ ] `ROADMAP.md` updated if the decision changes the plan
