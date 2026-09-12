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
**format → analyze → test**. The Flutter version is read from `.fvmrc` with `jq`,
so CI and every machine always use the one pinned SDK — CI never hardcodes the
version a second time.

`build` is deliberately not in the gate yet: there is no app beyond the
`flutter create` output and no Android flavors, so a build job would cost ~5
minutes per run and assert nothing. It joins the gate when the dev/prod flavors
land.

### Branch protection for `main` (manual, once)

GitHub cannot enable this from the repo, so set it by hand in
**Settings → Branches → Add branch ruleset** (or classic branch protection) for
`main`:

- [ ] Require a pull request before merging (1 approval; self-approve is fine for a solo repo)
- [ ] Require status checks to pass → select **`format → analyze → test`**
- [ ] Require branches to be up to date before merging
- [ ] Require linear history (matches the squash-merge rule in `CLAUDE.md` §10)
- [ ] Do not allow force pushes / deletions

The status check only appears in the list after the workflow has run at least
once on the repo, so push this workflow first, then add the rule.

**Line width is 180**, declared in `formatter.page_width` in `analysis_options.yaml`
(read by the CLI, the hook and CI) and in `dart.lineLength` in `.vscode/settings.json`
(read by the editor). The two must match — if they drift, save formats one way and
the hook checks another. The `lines_longer_than_80_chars` rule is disabled because it
directly contradicts this number.
