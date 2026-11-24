# ADR 0039 — The session is kept in the secure store, restored offline, and dropped after a reinstall

## Status

Accepted — 2026-11-16 (W12 T4, started early). You approved `flutter_secure_storage` 10.3.4. This completes ADR-0038 decision 5, which
held the session in memory until now, and takes the W12 Flex item "token in `flutter_secure_storage`" into T4. No schema change: the
marker is a row in the existing key/value `settings` table.

## Context

- Until T4 the session lived in memory, so every launch started signed out (ADR-0038).
- Blueprint §34: no token in SharedPreferences, plain SQLite or logs.
- Sign-in is optional and only adds backup and sync (ROADMAP W12, decision E). The app has to open on its local database with or without
  a session, and with or without a network.
- How GoTrue (`gotrue` 2.27.2, inside `supabase` 2.16.1) behaves, read from its source:
  - `setInitialSession(json)` sets a session with no network call, even an expired one.
  - `recoverSession(json)` refreshes an expired session over the network first. Offline, that throws, and the session is not kept.
  - The refresh ticker starts with the client and runs every 10 s.
    - A refresh that fails for lack of network emits a stream error and keeps the session.
    - A refresh token the server refuses removes the session and emits `signedOut`.
  - `onAuthStateChange` is a `ReplaySubject`. It replays every past event to a new listener, and carries errors.
- An iOS Keychain item survives an uninstall; the app's database does not. Reinstalling would find the previous install's session next to
  an empty database.

## Decision

1. **`flutter_secure_storage` 10.3.4, pinned,** behind `GPSecureStore` (`core/security`): `read`, `write` and `delete`.
   - `GPFlutterSecureStore` is the only file that imports the package.
   - On iOS, items are `first_unlock_this_device`: readable by a background sync once the phone has been unlocked after boot, never in an
     iCloud backup, and never on another device.
   - 10.3.4 is the newest version that resolves on the Dart 3.9.2 pin; 11.x is out.
2. **`SupabaseSessionKeeper`** (`features/auth/data/datasources`) owns the session's life on the device:
   - It writes the session as GoTrue's own JSON to `auth.session` on `signedIn`, `tokenRefreshed`, `userUpdated` and
     `mfaChallengeVerified`, and deletes it on `signedOut`.
   - Writes run in sequence, so a sign-out's delete never lands before the write it follows.
   - A write that fails is logged. The session still works in memory, and the next launch starts signed out.
3. **Restore with no network call (`setInitialSession`), never `recoverSession`.** An expired token comes back as it is, and the ticker
   renews it once there is a connection. Offline, a restored session stays signed in. Only the server refusing the refresh token signs
   out.
4. **A reinstall drops the old session.** Each kept session goes with an `auth.session_kept` row in `settings`, written before the
   session.
   - A session found with no marker comes from a previous install. It is deleted, not restored.
   - A crash between the two writes leaves a marker with no session, which restores nothing.
   - A kept value that is unreadable is deleted. A store that cannot be read means starting signed out. Neither stops the launch.
5. **The refresh ticker follows the app lifecycle** (`AppLifecycleListener`): it stops on `paused` and starts again on `resumed`. That is
   the piece `supabase_flutter` did and ADR-0038 left to us. On resume, the first tick refreshes a token that expired in the background.
6. **The bootstrap restores, after the database opens and before the first frame** (`RestoreSessionUseCase`).
   - The first auth status is already the real one. Nothing flickers from signed out to signed in.
   - It costs one Keychain or Keystore read and one `settings` query, on a backend build only. A local-only build does neither.
7. **`AuthRepository` gains `watchAuthStatus()` and `restoreSession()`.**
   - `AuthStatus` is `AuthSignedIn(user)`, `AuthSignedOut` or `AuthLocalOnly`.
   - The Supabase watch reads the client's current session on every event, rather than the event's own, and drops repeats. A new
     listener gets one status, not GoTrue's replayed history.
   - Stream errors (failed refreshes) never reach the domain.
   - It is a `StreamController`, not `async*`. Cancelling an `async*` paused in `await for` waits for an auth event that may never come;
     the tests hung on exactly that.
8. **`AuthBloc`** watches: `AuthUnknownState`, then `AuthSignedInState`, `AuthSignedOutState` or `AuthLocalOnlyState`.
   - It does not restore, since the bootstrap already has.
   - It is not provided yet: T5 puts it above the router, where the guard and the Profile card read it.
   - The state is not called `AuthState`, which is GoTrue's.
9. **Logs carry event and error types only**, never the session, an email or a token. GoTrue's own `package:logging` output still has no
   listener (W12 Flex).

## Consequences

Positive:

- Signing in once lasts across launches, offline launches included. Only a refused refresh token or a sign-out ends it.
- No token is ever in plaintext: the Keychain or Keystore holds it, and the logs hold types.
- A phone that changes hands after an uninstall does not open signed in as the previous owner.

Negative:

- **`settings` now holds the auth marker.**
  - T6 keeps `settings` on sign-out (decision D). That is harmless: the session itself is deleted, and a marker with no session restores
    nothing.
  - A database restored from an Android auto-backup brings the marker along. The Keystore key does not come with it, so that session
    is unreadable and is dropped (decision 4).
- **Android auto-backup is still on** (no `allowBackup` in the manifest). The database and the secure-storage preferences go to Google
  Drive. Whether to exclude them is its own decision.
- **The lifecycle hook lives in the data layer.** It imports `flutter/widgets` for `AppLifecycleListener`, which is allowed there (no
  `BuildContext`), but the keeper is not pure Dart.
- **A launch with a backend reads the Keychain before the first frame.** It is one read, but a start-up benchmark (ADR-0026) should be
  re-run with a kept session.

## How it is validated

- `supabase_session_keeper_test.dart` (12 cases, the real `GoTrueClient` over `MockClient` with an in-memory database and secure store):
  - keeping: sign-in keeps and marks, sign-out deletes, a store that cannot write is logged, a refused refresh token signs out and
    deletes, a stream error keeps the kept copy and logs its type only;
  - restoring: with no request, an expired session offline, nothing kept, no marker (reinstall), an unreadable value, a store that cannot
    be read;
  - lifecycle: no refresh while paused, and an expired token refreshed on resume.
- `supabase_auth_repository_test.dart`: the watch starts with the current status and follows sign-in and sign-out; a late listener gets
  one status, not the replay; `restoreSession` restores with no request and keeps the next session.
- `auth_bloc_test.dart`, `auth_status_test.dart`, the use cases, the local-only repository, and DI (keeper registered only on a backend
  build).
- iPhone 17 Pro simulator, `--flavor dev` with `env/dev.json`: `pod install` added the plugin, the app built and opened Home with the
  restore step run. A real sign-in and relaunch waits for T5, which routes to the sign-in screen.

## Alternatives rejected

**`recoverSession` at launch.** It refreshes an expired token over the network before keeping it, so an offline launch after an hour
would start signed out.

**`supabase_flutter`'s storage, with `localStorage` set to a secure implementation.** That is the package ADR-0038 left out.

**A marker in the secure store instead of the database.** It survives the uninstall together with the session, so it cannot tell a
reinstall apart.

**Restoring in `AuthBloc` on start.** The first frame would be signed out, and the Profile sync card would flicker. The bloc would also need
to be alive before anything else reads auth.

## Amended 2026-11-24 (W12 Flex) — the log audit

Decision 9 relied on nothing listening to `package:logging`. The audit found that still true:
- no `Logger.root` listener, no `onRecord`, no `print` or `debugPrint` anywhere in `lib/`;
- every auth log line carries only types, GoTrue codes, HTTP statuses, the uid and counts.

Two changes keep it true:

- **`logging_listener_guard_test.dart`** fails on any `package:logging` import, `Logger.root`, `onRecord` or `print` in `lib/`. Whoever adds
  one (a Sentry logging integration, a debug dump) must first filter GoTrue's FINEST records, which hold the whole session.
- **The redactor treats `session` and `jwt` keys as sensitive,** like `token` and `email`, so a session dumped under either name is
  redacted.

