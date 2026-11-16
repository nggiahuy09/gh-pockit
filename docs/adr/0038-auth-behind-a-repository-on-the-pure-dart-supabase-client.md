# ADR 0038 — Auth behind a repository, on the pure-Dart Supabase client, with the env file checked against the flavor

## Status

Accepted — 2026-11-15 (W12 T2, started early). You chose: the pure-Dart `supabase` package instead of `supabase_flutter`, a session held in
memory until T4, and an empty env file meaning local-only, on prod as well while there is no prod project. This amends ADR-0037 decision 4
and closes the guard ADR-0032 decision 4 left open. No schema change.

## Context

- W12 brings sign-up, sign-in and sign-out (blueprint §7.1, §33). ADR-0037 put auth behind `AuthRepository` and named `supabase_flutter` as
  the package. Nothing in Dart had read the env file yet (ADR-0032).
- `supabase_flutter` 2.17.2 adds 33 packages, among them three native plugins: `app_links`, `url_launcher` and `shared_preferences`. By
  default it writes the session, refresh token included, to SharedPreferences, and the PKCE verifier there too. It is reached through the
  global `Supabase.instance`.
- The pure-Dart `supabase` 2.16.1 is the client that `supabase_flutter` wraps. It adds 11 packages and no native code. What the wrapper adds
  on top:
  - a lifecycle observer that pauses token refresh in the background;
  - deep-link handling, for email links and OAuth;
  - the SharedPreferences storage.
- Blueprint §34 forbids an access token in SharedPreferences. The W12 Flex task says the same.
- The env file and the flavor are chosen separately. `--flavor prod --dart-define-from-file=env/dev.json` builds, and from P4 such a build
  would push the prod install's data to the dev project (ADR-0032).
- Read from a local GoTrue (`supabase start`, CLI 3.0.0):
  - a wrong password and an unknown email both answer `400 invalid_credentials`;
  - a taken email answers `422 user_already_exists` (hosted projects can also send `email_exists`);
  - a short password answers `422 weak_password`;
  - a malformed email and an empty password both answer `400 validation_failed`;
  - a second logout with a revoked session answers `403 session_not_found`.

## Decision

1. **The pure-Dart `supabase` 2.16.1, not `supabase_flutter`.**
   - The client is built in DI (`configureAuthDependencies`) and handed to the repository as its `GoTrueClient`. There is no global
     singleton.
   - `app/di/injector.dart` is the one file outside `data/` that imports it: the composition root has to name what it builds. Presentation
     still never does (golden rule 8).
   - **Implicit auth flow.** PKCE needs a store for its verifier: GoTrue asserts one exists on every `signUp`. It also only serves redirect
     sign-ins (magic link, OAuth, email confirmation link), which email/password never makes.
   - `http` 1.6.0 is a dev dependency only, for `MockClient`. It was already in the lock file through `supabase`.
2. **`AuthRepository`** (domain): `signUp`, `signIn` and `signOut`, returning `GPResult`. A user is `UserEntity(id, email)`. Its id is the
   server's uid, and the future `owner_id` of every synced row. Its `toString` prints the id only.
3. **`SupabaseAuthRepository`** (data) maps GoTrue's answers onto the app's failures:

   | GoTrue                                                              | Failure                                       |
   | ------------------------------------------------------------------- | --------------------------------------------- |
   | `invalid_credentials`                                               | `GPValidationFailure(authInvalidCredentials)` |
   | `user_already_exists`, `email_exists`                               | `GPValidationFailure(authEmailTaken)`         |
   | `weak_password` (`AuthWeakPasswordException`)                       | `GPValidationFailure(authPasswordWeak)`       |
   | `email_address_invalid`                                             | `GPValidationFailure(authEmailInvalid)`       |
   | `over_request_rate_limit`, `over_email_send_rate_limit`, or any 429 | `GPRateLimitedFailure` (new)                  |
   | no response (`AuthRetryableFetchException` without a status)        | `GPNetworkFailure`                            |
   | 5xx, `validation_failed`, any other code, an unparseable 200        | `GPUnknownFailure`                            |
   | a 200 with no session, or a user without an email                   | `GPUnknownFailure`                            |
   - **One failure for wrong password and unknown email,** because the server gives one. The copy must not say which, or the form would leak
     which emails have accounts.
   - **`validation_failed` stays unknown,** because it names no field: GoTrue sends it for a bad email and for an empty password alike.
     Client-side validation (T3) has to catch both before the request.
   - **Not `GPAuthenticationFailure`.** That one means HTTP 401 on an authenticated call, the one 4xx with a refresh flow (W19). A wrong
     password is a user correcting a form.
   - **A missing session is unknown.** It is what a project with _Confirm email_ on answers. Dev has it off (ADR-0032), and turning it on
     needs a failure of its own and a screen.
   - **Logs carry only the exception type, the GoTrue code and the HTTP status.** Never the email, the password, a token, or the server's
     message, and no exception object. The tests run every path and search the log for each of them.

4. **Sign-out always signs the device out.** GoTrue drops the local session before it asks the server to revoke it. A revoke that fails
   offline is logged at `warn` and the result is still `GPOk`. A 401, 403 or 404 there means the session was already gone, and GoTrue ignores
   it.
5. **The session lives in memory until T4.**
   - Nothing is persisted, so a relaunch means signing in again.
   - T4 (session restore) brings `flutter_secure_storage` with it, and uses GoTrue's `recoverSession` / `setInitialSession`.
   - T4 also pauses `startAutoRefresh` / `stopAutoRefresh` with the app lifecycle, which is the part of `supabase_flutter` given up here.
   - Until then no token is ever written anywhere.
6. **`env/<flavor>.json` gains `ENV_FLAVOR`**, and `GPBackendConfig.resolve` checks the file before anything else runs:

   | The file                                                  | Result                                                                |
   | --------------------------------------------------------- | --------------------------------------------------------------------- |
   | both keys empty, whatever `ENV_FLAVOR` says (or no file)  | local-only: `LocalOnlyAuthRepository`, every row owned by `'local'`   |
   | a backend set, `ENV_FLAVOR` missing or not the flavor     | refused: `flavorMismatch`                                             |
   | one key set, the other empty                              | refused: `backendIncomplete`                                          |
   | URL not a bare origin (path, query, fragment)             | refused: `urlMalformed`. This catches the dashboard link              |
   | URL `http://`                                             | allowed on dev, for the local stack; refused on prod (`urlMalformed`) |
   | otherwise                                                 | `GPRemoteBackendConfig(url, publishableKey)`                          |

   - **The flavor is checked only when a backend is set.** It guards one thing: a build talking to the other flavor's backend. With both
     keys empty there is none, and the sandbox and the database follow the flavor anyway (ADR-0032). So a bare `flutter run`, with no
     `--dart-define-from-file`, starts local-only instead of stopping, as it did before this ADR.

7. **Prod runs local-only on an empty file for now.** There is no prod project, and `env/prod.json` is empty. A strict rule would block the
   next prod build, which is the install holding real data. **The change that creates the prod project makes an empty prod file a
   refusal**, in the same PR.

## Consequences

Positive:

- No native plugin, no singleton and no token storage comes with the backend. Dropping Supabase later (ADR-0037, Option B) touches the data
  layer and one DI function.
- A build whose env file does not match its flavor never opens the database, so it can never sync one flavor's data to the other's
  backend.
- CI, a clean clone, and the sample-data and benchmark runs keep working with the empty example file.
- The wire contract is pinned by tests against the real GoTrue client: 21 cases, fed responses read from a local GoTrue.

Negative:

- **Every filled env file needs the new key.** A file with a backend and without the key is refused (`flavorMismatch`); an empty one runs
  local-only either way. `env/example.json` says `dev`, so a `cp env/example.json env/prod.json` is edited to `prod` before it is filled.
- **A run without the env file is silently local-only.** Sign-in then answers that this build has no backend. Deliberate: refusing it
  made a bare `fvm flutter run` open on the error screen, for no risk.
- **Token refresh on resume is ours to write (T4).** Without it, a session older than an hour fails its first call after a long background,
  and recovers on the next refresh tick.
- **No deep links.** Password reset by email, magic links and OAuth would need `app_links` (or `supabase_flutter`) back, and PKCE with a
  verifier store.
- **Until T4, every launch is signed out.** That is acceptable while no screen uses auth (T3 adds them).
- **Two new failure types and four validation codes,** each with copy in both languages. Every exhaustive switch on `GPFailure` gained two
  cases.
- **Prod's strictness is deferred.** Until the prod project exists, a prod build with an empty file runs local-only rather than stopping,
  which is today's behaviour.

## How it is validated

- `test/features/auth/data/repositories/supabase_auth_repository_test.dart`: the real `GoTrueClient` over `MockClient`, 21 cases. Every row
  of the mapping table, sign-out online, offline and with a revoked session, no PKCE challenge sent, and no email, password or token in any
  log line.
- `test/app/config/backend_config_test.dart`: every row of the env table, both flavors.
- `injector_test.dart`: a remote config binds the Supabase repository on one shared client, a local-only config builds no client, and an
  invalid config throws.
- By hand, against a local GoTrue: the DI-built repository signed up, refused the taken email, a wrong password and a weak password, signed
  in, and signed out with the session gone. The probe test was deleted afterwards.
- On the iPhone 17 Pro simulator (iOS 27.1): `--flavor prod --dart-define-from-file=env/dev.json` opens on the misconfigured-build screen
  naming `flavorMismatch`. `--flavor dev` with `env/dev.json` opens Home as before. Not yet on a physical device.

## Alternatives rejected

**`supabase_flutter`, as ADR-0037 named it.** It works with its storage overridden (`localStorage`, `pkceAsyncStorage`). But the three
native plugins ship unused, and the singleton fights DI. The defaults it falls back to are the plaintext storage blueprint §34 forbids, so one
missed override is a token in SharedPreferences.

**Secure storage in T2.** It would split session restore across two tasks and bring a second dependency into this one. Holding the session
in memory writes no token anywhere, which is stricter than either store.

**Refusing an empty prod file now.** That is the eventual rule. Today it would lock the real-data install out of every new build until a
prod project exists.

**An explicit `LOCAL_ONLY` key.** Local-only would become a written choice rather than an empty value. But it is one more key in every file,
for a state that ends when the prod project exists.

**Detecting the flavor from the URL** (a project ref per flavor). Dev and prod could point at the same local stack, there is no prod ref yet,
and a ref says nothing about which flavor the file was meant for.
