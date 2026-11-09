# Pockit

[![CI](https://github.com/nggiahuy09/gh-pockit/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nggiahuy09/gh-pockit/actions/workflows/ci.yml)

An **offline-first** personal finance app written in Flutter.
The engineering focus is data architecture and the sync engine, not screen count.

- Binding architecture and conventions: [`CLAUDE.md`](CLAUDE.md)
- Full design: [`docs/blueprint.md`](docs/blueprint.md), [`docs/system-design.md`](docs/system-design.md)
- Week-by-week plan: [`ROADMAP.md`](ROADMAP.md)

## Setup

The Flutter SDK is pinned in `.fvmrc` — use `fvm` so versions never drift.

```bash
fvm install                      # install the pinned Flutter version
fvm use 3.35.6                   # create the .fvm/flutter_sdk symlink for the IDE
fvm flutter pub get
git config core.hooksPath .githooks   # enable the pre-commit hook (git will not)
```

`.fvm/` is gitignored, so `fvm use` has to run on every machine. Skip it and the
Dart extension in VS Code cannot find the SDK and reports
_"There is no formatter for 'dart' files installed"_.

### Flavors and env

Two flavors ([ADR-0032](docs/adr/0032-dev-and-prod-flavors-with-a-gitignored-env-file.md)):

| Flavor | App id                      | Name       | Backend              |
| ------ | --------------------------- | ---------- | -------------------- |
| `dev`  | `com.nggiahuy.ghpockit.dev` | Pockit Dev | dev Supabase project |
| `prod` | `com.nggiahuy.ghpockit`     | Pockit     | none yet             |

`dev` is the default, so a bare `flutter run` builds it; `prod` keeps the id every
build had before the flavors, so an existing install and its data stay prod.

The backend URL and key come from `env/<flavor>.json`, which is gitignored. Only
`env/example.json` (the keys, empty) is committed. Once per clone:

```bash
cp env/example.json env/dev.json   # then fill in the dev project's values
cp env/example.json env/prod.json  # stays empty until there is a prod project
fvm flutter run --flavor dev --dart-define-from-file=env/dev.json
```

Both values are in the dev project's Supabase dashboard: the project URL and the
**publishable** key. The URL is the API one, `https://<project-ref>.supabase.co`,
not the dashboard link `https://supabase.com/dashboard/project/<project-ref>`.
Never the secret / `service_role` key: the app ships everything in these files.

To check the values and the dev project's auth settings (`disable_signup` should
be `false`, and `mailer_autoconfirm` `true`, which means _Confirm email_ is off):

```bash
curl -s "$(jq -r .SUPABASE_URL env/dev.json)/auth/v1/settings" -H "apikey: $(jq -r .SUPABASE_PUBLISHABLE_KEY env/dev.json)" | jq '{email: .external.email, disable_signup, mailer_autoconfirm}'
```

### Server schema

The Postgres schema lives in `supabase/migrations/`, and its pgTAP tests in
`supabase/tests/database/`
([ADR-0033](docs/adr/0033-the-server-schema-mirrors-local-with-checks-a-server-can-afford.md)).
They run against a local stack in Docker. Once per machine:

```bash
brew install supabase/tap/supabase
brew install --cask orbstack   # any Docker runtime works; open it once
```

Once per clone, to reach the dev project (the login opens a browser, and the link
asks for the database password set when the project was created):

```bash
supabase login
supabase link --project-ref "$(jq -r .SUPABASE_URL env/dev.json | sed -E 's#https://([^.]+)\..*#\1#')"
```

Then:

```bash
supabase db start   # local Postgres with the auth schema; applies the migrations
supabase test db    # pgTAP
supabase db push --remote --dry-run   # what dev does not have yet
supabase db push --remote             # without --remote, CLI 3.x targets the local stack
```

## Quality gate

`.githooks/pre-commit` runs format + analyze before every commit. To run it by hand:

```bash
fvm dart format --output=none --set-exit-if-changed .
fvm dart analyze --fatal-infos
fvm flutter test
```

The lint baseline is `very_good_analysis` (209 rules), included by a specific file
version so that bumping the package cannot silently change the rule set. The
overrides and the reasoning behind each one live in
[`analysis_options.yaml`](analysis_options.yaml).

`--fatal-infos` is mandatory: nearly every rule reports at `info` level, and
`dart analyze` exits 0 when only infos are present.

## CI

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs the same gate on every
push and pull request against `main` and `dev`, in the same fail-fast order:
**format → analyze → test → build**. The Flutter version is read from `.fvmrc`
with `jq`, so CI and every machine always use the one pinned SDK — CI never
hardcodes the version a second time.

`build` is a debug APK of the `dev` flavor, built with the empty
`env/example.json`: the build needs the keys to exist, not real values, so CI
holds no credentials. It catches what breaks on a clean machine (the native
SQLite, the subset font, the icon assets, a flavor block). One flavor is enough,
since Gradle configures every variant on every build. The job keeps the name
`format → analyze → test`, since that is the status check the rulesets below
require.

A second job, `server schema (pgTAP)`, starts a fresh local Postgres with the
Supabase CLI, which replays every migration in `supabase/migrations/`, then runs
the pgTAP suite
([ADR-0034](docs/adr/0034-each-owner-reads-and-writes-only-their-own-rows.md)),
then a two-session race between two pushes and a pull, which pgTAP cannot stage
([ADR-0036](docs/adr/0036-the-server-stamps-writes-in-commit-order.md)).
It runs beside the first, and blocks a merge only once it is added to the
rulesets below.

### Branch protection for `main` and `dev` (manual, once)

GitHub cannot enable this from the repo, so set it by hand in
**Settings → Branches → Add branch ruleset** (or classic branch protection) for
**both** `main` and `dev` — the same rules on each:

- [ ] Require a pull request before merging (1 approval; self-approve is fine for a solo repo)
- [ ] Require status checks to pass → select **`format → analyze → test`** and, once it
      has run on a PR, **`server schema (pgTAP)`**
- [ ] Require branches to be up to date before merging
- [ ] Leave **Require linear history** OFF — `CLAUDE.md` §10 merges a work branch into `dev`
      with a merge commit (`--no-ff`), and linear history is exactly the rule that forbids one.
      Turning it on leaves only squash or rebase, which flattens a week of distinct decisions
      into a single commit — the history this repo exists to show. Squash stays the exception,
      for a genuinely messy WIP branch.
- [ ] Do not allow force pushes / deletions

The status check only appears in the list after the workflow has run at least
once on the repo, so push this workflow first, then add the rule.

**Both rulesets are in place** — `main` from the start, `dev` since 2026-09-14,
which closes the last item W1 left open. The checklist above is the recipe for a
fresh fork, not an open to-do. `dev` needs it as much as `main` does: it is the ref
an AB-test build is cut from (`CLAUDE.md` §10), so a force-push there invalidates a
build someone is already testing.

**Line width is 180**, declared in `formatter.page_width` in `analysis_options.yaml`
(read by the CLI, the hook and CI) and in `dart.lineLength` in `.vscode/settings.json`
(read by the editor). The two must match — if they drift, save formats one way and
the hook checks another. The `lines_longer_than_80_chars` rule is disabled because it
directly contradicts this number.
