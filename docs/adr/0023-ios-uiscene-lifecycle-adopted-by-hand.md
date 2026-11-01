# ADR 0023 — iOS runs on the UIScene lifecycle, adopted by hand on Flutter 3.35.6

## Status

Accepted — 2026-11-01 (W8, outside the plan). The user chose option 1 of the three below on 2026-11-01. This decision is temporary. It ends
when the SDK pin moves to Flutter 3.38 or later.

## Context

The first release build on a physical iPhone (iPhone 15, iOS 27.2) crashed at launch with `EXC_BREAKPOINT` in
`_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`. iOS 27 refuses to launch an app that has not adopted the UIScene lifecycle.
The runner that Flutter 3.35.6 generates has neither a `UIApplicationSceneManifest` nor a scene delegate. The iOS 26.2 simulator only logs a
warning, so the simulator check of W8 T4 did not catch it.

Flutter migrates the runner itself from 3.38 on. Its template registers plugins in `FlutterImplicitEngineDelegate`. But 3.38 needs Dart
3.10, and `.fvmrc` pins 3.35.6 / Dart 3.9.2 (ADR-0003). The 3.35.6 engine does ship a `FlutterSceneDelegate`. Its header declares only
`window`. Its binary implements three methods: `scene:willConnectToSession:options:`, `scene:openURLContexts:`, and the home-screen shortcut
handler. It has no hook for registering plugins.

Three options were put to the user:

1. Adopt UIScene by hand in the runner, staying on 3.35.6.
2. Move the SDK pin to 3.38 or later and run Flutter's own migration.
3. Use Android for the month of real use and leave iOS for later.

## Decision

**Adopt the UIScene lifecycle by hand in `ios/Runner`, staying on Flutter 3.35.6.**

- `Info.plist` gains a `UIApplicationSceneManifest`:
  - one window scene;
  - no multiple scenes;
  - `UISceneDelegateClassName` set to `$(PRODUCT_MODULE_NAME).SceneDelegate`;
  - `UISceneStoryboardFile` set to `Main`, so UIKit still builds the `FlutterViewController` from the storyboard.
- `SceneDelegate` is a plain `UIResponder, UIWindowSceneDelegate`. In `scene(_:willConnectTo:options:)` it registers the generated plugins
  on the storyboard controller's engine. It also hands the scene's window to `FlutterAppDelegate.window`, which the delegate uses to find its
  root view, for example to forward a status-bar tap.
- `AppDelegate` no longer registers plugins. With scenes, there is no window at `didFinishLaunching`. `FlutterAppDelegate` would therefore
  return a nil registrar, and every plugin would register against nothing.
- The class lives in `AppDelegate.swift`, so `project.pbxproj` needs no new source entry.

It is **not** a subclass of `FlutterSceneDelegate`. That class does not declare its `scene:willConnectToSession:options:` in a header, so a
Swift subclass cannot call `super` without reaching into the Objective-C runtime. The class's only other work is forwarding URLs and
shortcuts, and the app uses neither.

## Consequences

Positive:

- The app launches on iOS 27. This was checked on 2026-11-01 in two places:
  - **iPhone 15 (iOS 27.2), release build.** No new crash log. The database was created at schema v4 with the 11 default categories, so
    `path_provider`, SQLite and the Dart startup all ran.
  - **iOS 26.2 simulator, debug build.** Existing data showed. Backgrounding and resuming kept the same process.
- Two native files change, both in the runner. No Dart code changes and no new dependency.

Negative:

- A deep link or a home-screen shortcut would not reach the plugins. The app has neither today. Whatever adds one first must revisit this.
- `AppLifecycleState` under scenes was not checked. That first matters for W21's `appResumed` sync trigger, which must test it on a device.
- This is hand-written glue that Flutter will replace. When the pin moves to 3.38 or later, delete `SceneDelegate`, then let `flutter`
  migrate the runner and move plugin registration into `FlutterImplicitEngineDelegate`.

## Alternatives rejected

**Move the pin to Flutter 3.38 or later now.** This is the right end state. But it means Dart 3.10, then the go_router, drift and
`very_good_analysis` bumps that ADR-0003 held back, then a full re-test. That is a week's task, not a fix to get one phone working.

**Subclass `FlutterSceneDelegate`.** The subclass would keep the URL and shortcut forwarding. But calling the superclass's undeclared
`willConnect` needs `class_getMethodImplementation` and a cast. That is more fragile than the plain delegate, for features the app does not
have.

**Android only for now.** This would leave the user's own phone unable to run the app, and the crash would still be waiting for whoever
tried iOS next.
