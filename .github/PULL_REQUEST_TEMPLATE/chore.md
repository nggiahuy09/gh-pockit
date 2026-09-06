<!--
  Chore template — tooling, CI, deps, formatting, config. No product behaviour change.
  Branch: chore/<slug>   Title: chore(scope): short description
  If this changes app behaviour, schema, or sync, use the default template instead.
-->

## What

-

## Why

-

## Behaviour change?

- [ ] **No product behaviour change** — this is tooling/CI/config only

<!-- If you cannot tick the box above, stop and use the default template. -->

## Dependency changes

<!-- Delete this section if no dependency was added, removed, or upgraded. -->

**Package + version:**

Per CLAUDE.md §5, answer all five:

1. What problem does it solve?
2. Cost of doing it ourselves?
3. Still maintained?
4. Does it affect native setup (Android/iOS)?
5. Does it lock in architecture?

- [ ] Version is pinned, not a floating range
- [ ] `pubspec.lock` committed

## Testing

- [ ] `dart format --set-exit-if-changed .`
- [ ] `flutter analyze` — 0 warnings
- [ ] `flutter test` — passing
- [ ] `dart run build_runner build --delete-conflicting-outputs` succeeds (if codegen is affected)
- [ ] Debug build succeeds on Android

## Risks

- **What breaks if this is wrong:** (CI red / local dev broken / build broken)
- **Rollback plan:**
