import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/router/auth_redirect.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/features/auth/domain/entities/user_entity.dart';
import 'package:ghpockit/features/auth/presentation/bloc/auth_bloc.dart';

void main() {
  test('a signed-out device opens the sign-in routes', () {
    expect(authRouteRedirect(const AuthSignedOutState()), isNull);
  });

  test('an unknown status lets the page open rather than guess', () {
    expect(authRouteRedirect(const AuthUnknownState()), isNull);
  });

  test('a signed-in device goes back to Settings', () {
    expect(authRouteRedirect(const AuthSignedInState(UserEntity(id: 'u-1', email: 'huy@example.com'))), Routes.settings);
  });

  test('a local-only build has nothing to sign in to: back to Settings', () {
    expect(authRouteRedirect(const AuthLocalOnlyState()), Routes.settings);
  });
}
