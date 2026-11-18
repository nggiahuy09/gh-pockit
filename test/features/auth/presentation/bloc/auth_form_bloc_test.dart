import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/auth/domain/repositories/auth_repository.dart';
import 'package:ghpockit/features/auth/domain/repositories/device_owner_repository.dart';
import 'package:ghpockit/features/auth/presentation/auth_form_field_enum.dart';
import 'package:ghpockit/features/auth/presentation/auth_form_mode_enum.dart';
import 'package:ghpockit/features/auth/presentation/bloc/auth_form_bloc.dart';

import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_device_owner_repository.dart';

late FakeAuthRepository _repository;

AuthFormBloc _bloc([AuthFormMode mode = AuthFormMode.signIn]) {
  final bloc = AuthFormBloc(mode: mode);
  addTearDown(bloc.close);
  return bloc;
}

/// Waits for the request to land or be refused.
Future<AuthFormState> _submitted(AuthFormBloc bloc) {
  bloc.add(const AuthFormSubmitEvent());
  return bloc.stream.firstWhere((state) => state.isSucceeded || (!state.isSubmitting && state.failure != null));
}

Future<AuthFormState> _settled(AuthFormBloc bloc) async {
  await pumpEventQueue();
  return bloc.state;
}

AuthFormBloc _filled({AuthFormMode mode = AuthFormMode.signIn, String email = 'huy@example.com', String password = 'secret-1'}) => _bloc(mode)
  ..add(AuthFormEmailChangeEvent(email))
  ..add(AuthFormPasswordChangeEvent(password));

void main() {
  setUp(() {
    _repository = FakeAuthRepository();
    getIt
      ..registerSingleton<AuthRepository>(_repository)
      ..registerSingleton<DeviceOwnerRepository>(FakeDeviceOwnerRepository());
  });

  tearDown(getIt.reset);

  test('starts blank in the mode it was opened with, password hidden', () {
    expect(_bloc().state, const AuthFormState.initial(AuthFormMode.signIn));
    expect(_bloc(AuthFormMode.signUp).state.isSignUp, isTrue);
    expect(_bloc().state.isPasswordVisible, isFalse);
  });

  test('signs in with what was typed and ends succeeded', () async {
    final state = await _submitted(_filled());

    expect(state.isSucceeded, isTrue);
    expect(_repository.calls.single, (method: 'signIn', email: 'huy@example.com', password: 'secret-1'));
  });

  test('signs up in sign-up mode', () async {
    await _submitted(_filled(mode: AuthFormMode.signUp));

    expect(_repository.calls.single.method, 'signUp');
  });

  test('is submitting while the request is out, and a second submit sends nothing', () async {
    _repository.gate = Completer<void>();
    final bloc = _filled()..add(const AuthFormSubmitEvent());

    expect((await _settled(bloc)).isSubmitting, isTrue);
    bloc.add(const AuthFormSubmitEvent());
    await pumpEventQueue();
    _repository.gate!.complete();

    expect((await bloc.stream.firstWhere((state) => state.isSucceeded)).isSucceeded, isTrue);
    expect(_repository.calls, hasLength(1));
  });

  test('a refused email goes on the email field and sends nothing', () async {
    final state = await _submitted(_filled(email: 'huy@example'));

    expect(state.failure, const GPValidationFailure(GPValidationCode.authEmailInvalid));
    expect(state.failedField, AuthFormField.email);
    expect(state.status, AuthFormStatus.editing);
    expect(_repository.calls, isEmpty);
  });

  test("the server's wrong-credentials answer is a banner, not a field", () async {
    _repository.result = const GPErr(GPValidationFailure(GPValidationCode.authInvalidCredentials));

    final state = await _submitted(_filled());

    expect(state.failure, const GPValidationFailure(GPValidationCode.authInvalidCredentials));
    expect(state.failedField, isNull);
  });

  group('an edit clears the failure it can fix (ADR-0016)', () {
    test('typing the email clears an email error', () async {
      final bloc = _filled(email: '');
      await _submitted(bloc);

      bloc.add(const AuthFormEmailChangeEvent('h'));

      expect((await _settled(bloc)).failure, isNull);
    });

    test('typing the password keeps an email error', () async {
      final bloc = _filled(email: '');
      await _submitted(bloc);

      bloc.add(const AuthFormPasswordChangeEvent('other-1'));

      expect((await _settled(bloc)).failure, const GPValidationFailure(GPValidationCode.authEmailEmpty));
    });

    test('any edit clears a banner', () async {
      _repository.result = const GPErr(GPNetworkFailure());
      final bloc = _filled();
      await _submitted(bloc);

      bloc.add(const AuthFormPasswordChangeEvent('secret-2'));

      expect((await _settled(bloc)).failure, isNull);
    });
  });

  group('switching mode', () {
    test('keeps both fields and drops the failure', () async {
      _repository.result = const GPErr(GPValidationFailure(GPValidationCode.authEmailTaken));
      final bloc = _filled(mode: AuthFormMode.signUp);
      final taken = await _submitted(bloc);
      expect(taken.isEmailTaken, isTrue);

      bloc.add(const AuthFormModeChangeEvent(AuthFormMode.signIn));
      final state = await _settled(bloc);

      expect(state.mode, AuthFormMode.signIn);
      expect(state.email, 'huy@example.com');
      expect(state.password, 'secret-1');
      expect(state.failure, isNull);
      expect(state.isEmailTaken, isFalse);
    });

    test('is ignored while a request is out', () async {
      _repository.gate = Completer<void>();
      final bloc = _filled()..add(const AuthFormSubmitEvent());
      await pumpEventQueue();

      bloc.add(const AuthFormModeChangeEvent(AuthFormMode.signUp));
      _repository.gate!.complete();

      expect((await bloc.stream.firstWhere((state) => state.isSucceeded)).mode, AuthFormMode.signIn);
    });
  });

  test('toggles the password visibility', () async {
    final bloc = _bloc()..add(const AuthFormPasswordVisibilityToggleEvent());

    expect((await _settled(bloc)).isPasswordVisible, isTrue);
  });

  test('toString prints neither the email nor the password', () async {
    final printed = (await _settled(_filled(password: 'correct-horse'))).toString();

    expect(printed, isNot(contains('huy')));
    expect(printed, isNot(contains('horse')));
  });
}
