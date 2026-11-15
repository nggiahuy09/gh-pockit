import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/auth/data/repositories/local_only_auth_repository.dart';
import 'package:ghpockit/features/auth/domain/entities/user_entity.dart';

void main() {
  const repository = LocalOnlyAuthRepository();

  test('sign-up says there is no backend', () async {
    expect(await repository.signUp(email: 'a@example.com', password: 'secret-1'), const GPErr<UserEntity>(GPBackendUnavailableFailure()));
  });

  test('sign-in says there is no backend', () async {
    expect(await repository.signIn(email: 'a@example.com', password: 'secret-1'), const GPErr<UserEntity>(GPBackendUnavailableFailure()));
  });

  test('sign-out succeeds: there is nothing to sign out of', () async {
    expect(await repository.signOut(), const GPOk<void>(null));
  });
}
