# ADR 0041 — Sign-in is optional, and the router guards only the sign-in routes

## Status

Accepted — 2026-11-18 (W12 T5, started early). This writes down decision E of the W12 plan, which you chose on 2026-11-15: sign-in is
optional and only adds backup and sync. It replaces the roadmap's original T5, "redirect by auth state". No schema change.

## Context

- The roadmap's T5 was the usual guard: a signed-out user is sent to `/login` and a splash waits on `unknown`. That fits an online app. It
  contradicts this one: the UI reads the local database (golden rule 1), the app was fully usable for eleven weeks with no account, and
  local-only builds have nothing to sign in to (ADR-0038).
- `AuthBloc` (ADR-0039) exists but was provided nowhere. The session is restored before the first frame, so its first status is the real
  one a microtask after it starts.
- There is no Profile screen yet. Settings, opened from Home, is the screen that plays its part. The design canvas (Profile, SyncAuth)
  puts the entry on a "Sync across devices" card there.

## Decision

1. **No route inside the shell needs a sign-in.** There is no splash and no redirect to `/login`. An `unknown` status blocks nothing.
2. **`/login` and `/register` sit outside the shell,** over the dock, like the forms. Both build `AuthPage`, which opens in sign-in mode on
   `/login` and sign-up mode on `/register`, and can switch modes in place.
   - The close button returns to the page underneath; opened cold, it falls back to Settings.
   - A successful sign-in or sign-up does the same, with a snackbar.
3. **The only guard is on those two routes** (`authRouteRedirect`):

   | Status                  | `/login`, `/register`                   |
   | ----------------------- | --------------------------------------- |
   | signed out              | opens                                   |
   | unknown                 | opens. It is known before the first tap |
   | signed in               | back to Settings                        |
   | local-only (no backend) | back to Settings: nothing to sign in to |

   It runs at each navigation into them, with no `refreshListenable`. A refresh would also fire on a sign-in's own success, while the form
   is already closing itself, and the two would race over the same route.

4. **`AuthBloc` sits above the router** in `GPApp`, with `lazy: false`, so its status is settled before any navigation reads it. Every
   screen reads the same instance.
5. **Settings has a sync card at the top** (`SyncAccountCardWidget`):
   - **unknown or local-only:** hidden;
   - **signed out:** "Sync across devices", why sign-in is optional, and a Sign in button that pushes `/login`;
   - **signed in:** the account's email.

   Sign-out and the count of unsynced changes come with T6 and P4.

## Consequences

Positive:

- Signing in never stands between a user and their data, offline or on a build with no backend.
- One guard, on two routes, as a pure function of one state, with a test per row.
- The whole flow runs on a device. On the simulator, against the local GoTrue: sign up from Settings, the card shows the account, the
  claim moved every row (version 2, still pending, `owner.id` written), and a relaunch restores the session with the data unchanged.

Negative:

- **`GPApp` needs an `AuthRepository`** in every test that pumps it. `registerShellFakes` registers the local-only one, and three page
  tests add it.
- **Settings in isolation now needs an `AuthBloc`** above it. The "no service locator" test became "only auth", via a local helper.
- **An OS deep link to `/login` at cold start** would meet an `unknown` status and open the form even when signed in. No such link is
  registered. If one ever is, the form should close itself on a signed-in status.
- **The sign-up URL does not follow an in-place mode switch.** Switching from `/login` to sign-up keeps the URL, which only matters for a
  deep link.

## How it is validated

- `auth_redirect_test.dart`: every row of the table.
- `auth_routes_test.dart` drives the whole app with a fake auth repository:
  - signed out: the card offers sign-in, which opens over the dock and closes back to Settings; `/register` opens on sign-up; a
    successful sign-in lands on Settings showing the account;
  - signed in: the card shows the email, and `/login` and `/register` send the user back;
  - local-only: no card, and `/login` sends the user back;
  - an unknown status still opens Home.
- iPhone 17 Pro simulator, the dev flavor against `supabase start` on localhost: the run described under Positive. The database rows were
  read from the simulator's app container.

## Alternatives rejected

**The roadmap's T5: signed-out users redirected to `/login`, with a splash on `unknown`.** It contradicts offline-first and decision E,
locks local-only builds out, and puts the network on the launch path.

**`refreshListenable` on the bloc's stream.** See decision 3: it races the form's own close on success.

**A lazy `AuthBloc`.** It would be created by the redirect itself, which would then always read `unknown`.
