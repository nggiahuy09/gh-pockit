import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/app_shell.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/features/auth/domain/entities/auth_status.dart';
import 'package:ghpockit/features/auth/domain/entities/user_entity.dart';
import 'package:ghpockit/features/auth/domain/repositories/auth_repository.dart';
import 'package:ghpockit/features/auth/domain/repositories/device_owner_repository.dart';
import 'package:ghpockit/features/auth/presentation/pages/auth_page.dart';
import 'package:ghpockit/features/dashboard/presentation/pages/home_page.dart';
import 'package:ghpockit/features/settings/presentation/pages/settings_page.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_device_owner_repository.dart';
import '../../helpers/localization_harness.dart';
import '../../helpers/shell_harness.dart';

const _user = UserEntity(id: 'u-1', email: 'huy@example.com');

late FakeAuthRepository _auth;
late FakeDeviceOwnerRepository _owners;

Future<void> _pumpApp(WidgetTester tester, AuthStatus status, [String location = Routes.settings]) async {
  _auth.currentStatus = status;
  await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.en), initialLocation: Routes.home));
  await tester.pumpAndSettle();
  // After the first frame, as a tap would: by then the bloc has the restored status.
  GoRouter.of(tester.element(find.byType(HomePage))).go(location);
  await tester.pumpAndSettle();
}

Finder get _syncCard => find.text('Sync across devices');

void main() {
  setUp(() async {
    registerShellFakes();
    _auth = FakeAuthRepository();
    await getIt.unregister<AuthRepository>();
    getIt
      ..registerSingleton<AuthRepository>(_auth)
      ..registerSingleton<DeviceOwnerRepository>(_owners = FakeDeviceOwnerRepository(ownerId: _user.id));
  });

  tearDown(getIt.reset);

  group('signed out', () {
    testWidgets('Settings offers sign-in, which opens over the dock and closes back to Settings', (tester) async {
      await _pumpApp(tester, const AuthSignedOut());
      expect(_syncCard, findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsOneWidget);
      expect(find.byKey(AppShell.dockKey), findsNothing);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(AuthPage), findsNothing);
    });

    testWidgets('the register route opens the form on sign-up', (tester) async {
      await _pumpApp(tester, const AuthSignedOut(), Routes.register);

      expect(find.text('Create an account'), findsOneWidget);
    });

    testWidgets('a successful sign-in lands back on Settings, which now shows the account', (tester) async {
      await _pumpApp(tester, const AuthSignedOut());
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'huy@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'secret-1');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in').last);
      _auth.statuses.add(const AuthSignedIn(_user));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('Signed in as huy@example.com'), findsOneWidget);
    });
  });

  group('signed in', () {
    testWidgets('Settings shows the account, with no sign-in button', (tester) async {
      await _pumpApp(tester, const AuthSignedIn(_user));

      expect(find.text('Signed in as huy@example.com'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsNothing);
    });

    testWidgets('sign-out with unsynced changes is explained, never offered', (tester) async {
      _owners.unsyncedResult = const GPOk(4);
      await _pumpApp(tester, const AuthSignedIn(_user));

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text("You can't sign out yet"), findsOneWidget);
      expect(find.textContaining('4 changes are not backed up'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(_auth.signOutCalls, 0);
      expect(find.text('Signed in as huy@example.com'), findsOneWidget);
    });

    testWidgets('sign-out with nothing unsynced asks, then wipes and signs out', (tester) async {
      await _pumpApp(tester, const AuthSignedIn(_user));

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out of Pockit?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out').last);
      await tester.pumpAndSettle();

      expect(_owners.releases, 1);
      expect(_auth.signOutCalls, 1);
      expect(find.text('Signed out.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    });

    testWidgets('a cancelled sign-out keeps everything', (tester) async {
      await _pumpApp(tester, const AuthSignedIn(_user));

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(_owners.releases, 0);
      expect(find.text('Signed in as huy@example.com'), findsOneWidget);
    });

    for (final route in const [Routes.login, Routes.register]) {
      testWidgets('$route sends the user back to Settings', (tester) async {
        await _pumpApp(tester, const AuthSignedIn(_user), route);

        expect(find.byType(AuthPage), findsNothing);
        expect(find.byType(SettingsPage), findsOneWidget);
      });
    }
  });

  group('local-only', () {
    testWidgets('Settings has no sync card', (tester) async {
      await _pumpApp(tester, const AuthLocalOnly());

      expect(_syncCard, findsNothing);
    });

    testWidgets('the sign-in route does not exist for it: back to Settings', (tester) async {
      await _pumpApp(tester, const AuthLocalOnly(), Routes.login);

      expect(find.byType(AuthPage), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });

  testWidgets('the shell never waits on auth: an unknown status still opens Home', (tester) async {
    await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.en)));
    await tester.pumpAndSettle();

    expect(find.byKey(AppShell.dockKey), findsOneWidget);
  });
}
