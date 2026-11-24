import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/domain/use_case.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/auth/domain/entities/auth_status.dart';
import 'package:ghpockit/features/auth/domain/entities/user_entity.dart';
import 'package:ghpockit/features/auth/domain/usecases/restore_session_use_case.dart';
import 'package:ghpockit/features/auth/domain/usecases/sign_in_use_case.dart';
import 'package:ghpockit/features/auth/domain/usecases/sign_out_use_case.dart';
import 'package:ghpockit/features/auth/domain/usecases/sign_up_use_case.dart';
import 'package:ghpockit/features/auth/domain/usecases/watch_auth_status_use_case.dart';

import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_device_owner_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late FakeDeviceOwnerRepository owners;

  setUp(() {
    repository = FakeAuthRepository();
    owners = FakeDeviceOwnerRepository();
  });

  group('SignInUseCase', () {
    test('sends the trimmed email and the password as typed', () async {
      final result = await SignInUseCase(repository, owners).execute(const SignInInput(email: ' huy@example.com ', password: ' pass '));

      expect(result, const GPOk(UserEntity(id: 'u-1', email: 'huy@example.com')));
      expect(repository.calls.single, (method: 'signIn', email: 'huy@example.com', password: ' pass '));
    });

    test('a refused field never reaches the repository', () async {
      final result = await SignInUseCase(repository, owners).execute(const SignInInput(email: 'huy@example', password: 'secret'));

      expect(result, const GPErr<UserEntity>(GPValidationFailure(GPValidationCode.authEmailInvalid)));
      expect(repository.calls, isEmpty);
    });

    test("passes the repository's failure through", () async {
      repository.result = const GPErr(GPValidationFailure(GPValidationCode.authInvalidCredentials));

      final result = await SignInUseCase(repository, owners).execute(const SignInInput(email: 'huy@example.com', password: 'wrong'));

      expect(result, const GPErr<UserEntity>(GPValidationFailure(GPValidationCode.authInvalidCredentials)));
    });

    test('logs nothing of its input', () {
      expect(const SignInInput(email: 'huy@example.com', password: 'secret').toLog(), isEmpty);
    });
  });

  group('SignUpUseCase', () {
    test('signs up with valid credentials', () async {
      final result = await SignUpUseCase(repository, owners).execute(const SignUpInput(email: 'huy@example.com', password: 'secret-1'));

      expect(result, isA<GPOk<UserEntity>>());
      expect(repository.calls.single.method, 'signUp');
    });

    test('a short password never reaches the repository', () async {
      final result = await SignUpUseCase(repository, owners).execute(const SignUpInput(email: 'huy@example.com', password: '12345'));

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

  test('RestoreSessionUseCase restores', () async {
    final restored = RestoreSessionUseCase(repository, owners).execute(const GPNoInput());
    await pumpEventQueue();
    repository.statuses.add(const AuthSignedOut());

    expect(await restored, const GPOk<void>(null));
    expect(repository.restoreCalls, 1);
  });

  test('WatchAuthStatusUseCase passes the statuses through', () async {
    final first = WatchAuthStatusUseCase(repository).execute(const GPNoInput()).first;
    await pumpEventQueue();
    repository.statuses.add(const AuthSignedOut());

    expect(await first, const AuthSignedOut());
  });

  group('claim after sign-in (ADR-0040)', () {
    const input = SignInInput(email: 'huy@example.com', password: 'secret-1');

    test('an unclaimed device becomes the user’s', () async {
      expect(await SignInUseCase(repository, owners).execute(input), isA<GPOk<UserEntity>>());

      expect(owners.claims, ['u-1']);
      expect(owners.ownerId, 'u-1');
    });

    test('sign-up claims too', () async {
      await SignUpUseCase(repository, owners).execute(const SignUpInput(email: 'huy@example.com', password: 'secret-1'));

      expect(owners.claims, ['u-1']);
    });

    test('the device already being the user’s claims nothing', () async {
      owners.ownerId = 'u-1';

      expect(await SignInUseCase(repository, owners).execute(input), isA<GPOk<UserEntity>>());
      expect(owners.claims, isEmpty);
    });

    test("another account's data is refused, and the new session is signed out again", () async {
      owners.ownerId = 'u-other';

      final result = await SignInUseCase(repository, owners).execute(input);

      expect(result, const GPErr<UserEntity>(GPValidationFailure(GPValidationCode.authDeviceOwnedByAnotherAccount)));
      expect(repository.signOutCalls, 1);
      expect(owners.claims, isEmpty);
    });

    test('a claim that fails in the database keeps the sign-in: the next launch claims again', () async {
      owners.claimResult = const GPErr(GPDatabaseFailure());

      expect(await SignInUseCase(repository, owners).execute(input), isA<GPOk<UserEntity>>());
      expect(owners.ownerId, 'local');
    });

    test('a refused sign-in claims nothing', () async {
      repository.result = const GPErr(GPValidationFailure(GPValidationCode.authInvalidCredentials));

      await SignInUseCase(repository, owners).execute(input);

      expect(owners.claims, isEmpty);
    });
  });

  group('RestoreSessionUseCase', () {
    test('claims for a restored user whose claim had not landed', () async {
      final restored = RestoreSessionUseCase(repository, owners).execute(const GPNoInput());
      await pumpEventQueue();
      repository.statuses.add(const AuthSignedIn(UserEntity(id: 'u-1', email: 'huy@example.com')));

      expect(await restored, const GPOk<void>(null));
      expect(owners.claims, ['u-1']);
    });

    test('claims nothing when nobody is signed in', () async {
      final restored = RestoreSessionUseCase(repository, owners).execute(const GPNoInput());
      await pumpEventQueue();
      repository.statuses.add(const AuthSignedOut());

      expect(await restored, const GPOk<void>(null));
      expect(owners.claims, isEmpty);
    });
  });
}
