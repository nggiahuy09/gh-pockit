# ADR 0032 — Two flavors, dev and prod, with the backend config in a gitignored define file

## Status

Accepted — 2026-11-08 (W11 T2, started early). You chose: flavors on iOS as well as Android, `env/*.json` kept out of git with a committed
example, and email confirmation off on the dev project. No schema change.

## Context

P3 brings a backend: a dev Supabase project now, a prod one later. Until now every build had one identity, `com.nggiahuy.ghpockit`
("Pockit"), and the iPhone 15 holds a release v4 build of it with real data (W9 T4). The W11 Flex test upgrades that build in place.

Offline-first makes the identity matter more than usual. The local database holds rows owned by a user of _one_ backend, and from P4 on it
pushes them there. A dev build installed over prod shares prod's sandbox, so it opens prod's database and would push it to dev. Two
backends on one sandbox means two backends' data in one file.

`--dart-define-from-file` carries values into Dart. It cannot change the app id or the launcher name, which are what keep two sandboxes
apart. A flavor can.

## Decision

1. **Two flavors, `dev` and `prod`, on Android and iOS.**
   - `prod` keeps `com.nggiahuy.ghpockit` and "Pockit". Every install from before the flavors, and its database, is prod. The W11 Flex
     install-over test builds `--flavor prod`.
   - `dev` is `com.nggiahuy.ghpockit.dev`, "Pockit Dev": its own sandbox and database, installed next to prod.
   - `default-flavor: dev` in `pubspec.yaml`. A plain `flutter run` / `build` / `drive` is dev, and prod is only built when asked for by
     name. The benchmark (ADR-0026) therefore runs on the dev app, never on the one holding real data.
2. **Android:** dimension `env`, `applicationIdSuffix = ".dev"` on dev, a `resValue` `app_name` per flavor, and the manifest label reads
   `@string/app_name`.
3. **iOS:** six configurations, `{Debug,Profile,Release}-{dev,prod}`, replace the three plain ones. Schemes `dev` and `prod` replace
   `Runner`. Each Runner configuration has its own `Flutter/<Configuration>.xcconfig`, which includes its Pods xcconfig, `Generated.xcconfig`
   and the flavor's `dev.xcconfig` / `prod.xcconfig`. The flavor file sets the bundle id and `APP_DISPLAY_NAME`, and `Info.plist` reads the
   latter.
   - **One file per configuration** because CocoaPods writes one Pods xcconfig per configuration and only wires a configuration whose base
     file includes it. Sharing `Debug.xcconfig` across both flavors makes every `pod install` warn, and quietly applies Debug's Pods
     settings to the others.
   - **The plain three are removed, not kept beside the new ones.** With a default flavor, the flutter tool never builds them. A leftover
     `Runner` scheme would build a prod-id app with whatever defines the last command left in `Generated.xcconfig`. Flutter's own flavor
     test project (`dev/integration_tests/flavors`) does the same.
4. **Config comes from `--dart-define-from-file=env/<flavor>.json`.** `env/*.json` is gitignored, except `env/example.json`, which lists
   the keys with empty values: `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`.
   - The publishable key is not a secret: it ships inside every build, and RLS is the real guard (W11 T4). The file is kept out of git
     anyway, because a real secret (a service key, a Sentry auth token) would later land in the same file by mistake, and blueprint §46
     keeps config out of the repo.
   - Nothing in Dart reads the keys yet. Their first reader is W12 T2, which also decides what an empty URL means (likely no backend, local
     only).
   - The flavor and the env file are chosen separately: nothing yet stops `--flavor prod --dart-define-from-file=env/dev.json`. A guard
     needs the reader, so it is W12's.
5. **CI builds `--flavor dev --dart-define-from-file=env/example.json`.** The build needs the keys to exist, not real values. One flavor is
   enough, because Gradle configures every variant on every build, so a broken `prod` block fails the dev build too. iOS is not built in CI
   (Ubuntu runner).
6. **The dev Supabase project:** email/password sign-in on, _Confirm email_ off. Sign-up returns a session, so W12 can test without an
   inbox, and the built-in SMTP sends only a few emails an hour anyway. Prod chooses its own setting, with its own SMTP, when it is
   created. There is no prod project yet, so a local `env/prod.json` is a copy of the empty example.
7. **The bootstrap logs `flavor`** (`appFlavor`) in `app bootstrapped`. It is the one line that shows the flavor reached Dart. It logs
   neither the URL nor the key.

## Consequences

Positive:

- Dev and prod never share a database on one device: each has its own sandbox.
- The install holding real data stays prod. Nothing on it moves or needs migrating.
- A clean clone builds with no credentials, and CI proves it on every PR.

Negative:

- Every run needs the env file. Without `--dart-define-from-file`, the keys are empty, and a missing file is a hard error from the flutter
  tool. Each clone runs `cp env/example.json env/dev.json` once.
- The dev iOS app needs its own App ID and provisioning profile. Automatic signing (team `Q8Q5R9GTRX`) creates them on the first device
  build.
- Simulator data stays with the old id: sample data and benchmark databases created before this ADR live in `com.nggiahuy.ghpockit`, and
  a dev build starts empty.
- Adding a build mode or a flavor on iOS means editing the pbxproj, the Podfile and a scheme together. That is work for a script, not for
  hand edits.
- Both flavors share the launcher icon, so dev is told apart only by its name. A dev badge on the icon can come later.

## How it is verified

- Android: debug APKs for `dev`, `prod` and no `--flavor` (which builds dev). `aapt dump badging` shows the package id and label of each.
- iOS: `flutter build ios --release --no-codesign` for both flavors, then the bundle id and display name read from each built `Info.plist`.
- No Dart test. Only build configuration changed, and the one Dart change is a log field.

## Alternatives rejected

**Android only, as CLAUDE.md §1 orders platforms.** The flutter tool refuses a flavor when the Xcode project has no custom schemes, so
`default-flavor` would break iOS, and every Android command would need `--flavor`. The device used for every on-device check is an iPhone,
where dev and prod would share one sandbox.

**Commit `env/dev.json`.** A clean clone would reach dev at once. But the dev project's URL and key would stay in git history, letting
anyone with the repo call sign-up on dev, and the file is where a real secret would land later.

**`main_dev.dart` / `main_prod.dart`.** The env would become Dart code chosen with `-t`, and two entry points drift apart
(`docs/patterns/app-bootstrap.md` §1). One `main.dart` takes its config from the define file instead.

**A `staging` flavor** (blueprint §46 lists dev, staging, prod). There is no staging backend: a build cut from `dev` uses the dev project.
Add a third flavor when there is a third project.
