import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/app/theme/app_theme.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/widgets/field.dart';
import 'package:ghpockit/core/widgets/form_failure_banner.dart';
import 'package:ghpockit/features/auth/domain/repositories/auth_repository.dart';
import 'package:ghpockit/features/auth/presentation/auth_form_mode_enum.dart';
import 'package:ghpockit/features/auth/presentation/pages/auth_page.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/localization_harness.dart';

late FakeAuthRepository _repository;

/// Opened cold, as a deep link would: closing it lands on Home.
Future<void> _pump(WidgetTester tester, {AuthFormMode mode = AuthFormMode.signIn, GPLocale locale = GPLocale.en}) async {
  final router = GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(
        path: Routes.home,
        name: RouteNames.home,
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, _) => AuthPage(mode: mode),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    GPLocalizationScope(
      localization: await localizationFor(locale),
      child: MaterialApp.router(theme: GPAppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.descendant(of: find.widgetWithText(GPField, label), matching: find.byType(TextField));

String? _errorOn(WidgetTester tester, String label) => tester.widget<GPField>(find.widgetWithText(GPField, label)).errorText;

Future<void> _type(WidgetTester tester, {String email = 'huy@example.com', String password = 'secret-1'}) async {
  await tester.enterText(_field('Email'), email);
  await tester.enterText(_field('Password'), password);
  await tester.pump();
}

Finder _submitButton(String label) => find.widgetWithText(FilledButton, label);

void main() {
  setUp(() {
    _repository = FakeAuthRepository();
    getIt.registerSingleton<AuthRepository>(_repository);
  });

  tearDown(getIt.reset);

  testWidgets('sign-in shows its title, both fields and the way to sign up', (tester) async {
    await _pump(tester);

    expect(find.text('Sign in to sync'), findsOneWidget);
    expect(_field('Email'), findsOneWidget);
    expect(_field('Password'), findsOneWidget);
    expect(find.text('No account yet?'), findsOneWidget);
    expect(find.text('At least 6 characters.'), findsNothing);
  });

  testWidgets('the password is hidden until the eye is tapped', (tester) async {
    await _pump(tester);

    expect(tester.widget<TextField>(_field('Password')).obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(tester.widget<TextField>(_field('Password')).obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('a malformed email is refused on its field, and nothing is sent', (tester) async {
    await _pump(tester);
    await _type(tester, email: 'huy@example');

    await tester.tap(_submitButton('Sign in'));
    await tester.pumpAndSettle();

    expect(_errorOn(tester, 'Email'), 'Enter a valid email address.');
    expect(_errorOn(tester, 'Password'), isNull);
    expect(_repository.calls, isEmpty);
  });

  testWidgets('wrong credentials show the banner, never a field error', (tester) async {
    _repository.result = const GPErr(GPValidationFailure(GPValidationCode.authInvalidCredentials));
    await _pump(tester);
    await _type(tester);

    await tester.tap(_submitButton('Sign in'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(GPFormFailureBanner, 'The email or password is incorrect.'), findsOneWidget);
    expect(_errorOn(tester, 'Email'), isNull);
    expect(_errorOn(tester, 'Password'), isNull);
  });

  testWidgets('while the request is out the fields are locked and the button spins', (tester) async {
    _repository.gate = Completer<void>();
    await _pump(tester);
    await _type(tester);

    await tester.tap(_submitButton('Sign in'));
    await tester.pump();

    expect(tester.widget<TextField>(_field('Email')).enabled, isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    _repository.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a successful sign-in closes the form and says so', (tester) async {
    await _pump(tester);
    await _type(tester);

    await tester.tap(_submitButton('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('Signed in.'), findsOneWidget);
  });

  testWidgets('sign-up shows the minimum length and refuses a shorter password', (tester) async {
    await _pump(tester, mode: AuthFormMode.signUp);
    expect(find.text('At least 6 characters.'), findsOneWidget);
    await _type(tester, password: '12345');

    await tester.tap(_submitButton('Create account'));
    await tester.pumpAndSettle();

    expect(_errorOn(tester, 'Password'), 'Password is too short.');
    expect(_repository.calls, isEmpty);
  });

  testWidgets('a taken email offers sign-in with the same email, kept as typed', (tester) async {
    _repository.result = const GPErr(GPValidationFailure(GPValidationCode.authEmailTaken));
    await _pump(tester, mode: AuthFormMode.signUp);
    await _type(tester);
    await tester.tap(_submitButton('Create account'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in with this email'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to sync'), findsOneWidget);
    expect(tester.widget<TextField>(_field('Email')).controller?.text, 'huy@example.com');
    expect(_errorOn(tester, 'Email'), isNull);
  });

  testWidgets('the switch at the bottom moves between the two modes', (tester) async {
    await _pump(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Create an account'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to sync'), findsOneWidget);
  });

  testWidgets('the close button returns to Home', (tester) async {
    await _pump(tester);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('reads in Vietnamese', (tester) async {
    await _pump(tester, locale: GPLocale.vi);

    expect(find.text('Đăng nhập để đồng bộ'), findsOneWidget);
    expect(_field('Mật khẩu'), findsOneWidget);
  });
}
