# Pockit

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

**Line width is 180**, declared in `formatter.page_width` in `analysis_options.yaml`
(read by the CLI, the hook and CI) and in `dart.lineLength` in `.vscode/settings.json`
(read by the editor). The two must match — if they drift, save formats one way and
the hook checks another. The `lines_longer_than_80_chars` rule is disabled because it
directly contradicts this number.
