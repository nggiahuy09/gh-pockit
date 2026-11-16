import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/domain/use_case.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/auth/domain/entities/user_entity.dart';
import 'package:ghpockit/features/auth/domain/usecases/sign_in_use_case.dart';
import 'package:ghpockit/features/auth/domain/usecases/sign_out_use_case.dart';
import 'package:ghpockit/features/auth/domain/usecases/sign_up_use_case.dart';

import '../../../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());

  group('SignInUseCase', () {
    test('sends the trimmed email and the password as typed', () async {
      final result = await SignInUseCase(repository).execute(const SignInInput(email: ' huy@example.com ', password: ' pass '));

      expect(result, const GPOk(UserEntity(id: 'u-1', email: 'huy@example.com')));
      expect(repository.calls.single, (method: 'signIn', email: 'huy@example.com', password: ' pass '));
    });

    test('a refused field never reaches the repository', () async {
      final result = await SignInUseCase(repository).execute(const SignInInput(email: 'huy@example', password: 'secret'));

      expect(result, const GPErr<UserEntity>(GPValidationFailure(GPValidationCode.authEmailInvalid)));
      expect(repository.calls, isEmpty);
    });

    test("passes the repository's failure through", () async {
      repository.result = const GPErr(GPValidationFailure(GPValidationCode.authInvalidCredentials));

      final result = await SignInUseCase(repository).execute(const SignInInput(email: 'huy@example.com', password: 'wrong'));

      expect(result, const GPErr<UserEntity>(GPValidationFailure(GPValidationCode.authInvalidCredentials)));
    });

    test('logs nothing of its input', () {
      expect(const SignInInput(email: 'huy@example.com', password: 'secret').toLog(), isEmpty);
    });
  });

  group('SignUpUseCase', () {
    test('signs up with valid credentials', () async {
      final result = await SignUpUseCase(repository).execute(const SignUpInput(email: 'huy@example.com', password: 'secret-1'));

      expect(result, isA<GPOk<UserEntity>>());
      expect(repository.calls.single.method, 'signUp');
    });

    test('a short password never reaches the repository', () async {
      final result = await SignUpUseCase(repository).execute(const SignUpInput(email: 'huy@example.com', password: '12345'));

      expect(result, const GPErr<UserEntity>(GPValidationFailure(GPValidationCode.authPasswordTooShort)));
      expect(repository.calls, isEmpty);
    });

    test('logs nothing of its input', () {
      expect(const SignUpInput(email: 'huy@example.com', password: 'secret').toLog(), isEmpty);
    });
  });

  test('SignOutUseCase signs out', () async {
    expect(await SignOutUseCase(repository).execute(const GPNoInput()), const GPOk<void>(null));
    expect(repository.signOutCalls, 1);
  });
}
