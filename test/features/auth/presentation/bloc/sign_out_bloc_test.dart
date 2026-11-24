import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/auth/domain/repositories/auth_repository.dart';
import 'package:ghpockit/features/auth/domain/repositories/device_owner_repository.dart';
import 'package:ghpockit/features/auth/presentation/bloc/sign_out_bloc.dart';

import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_device_owner_repository.dart';

late FakeAuthRepository _auth;
late FakeDeviceOwnerRepository _owners;

SignOutBloc _bloc() {
  final bloc = SignOutBloc();
  addTearDown(bloc.close);
  return bloc;
}

Future<SignOutState> _after(SignOutBloc bloc, SignOutEvent event) async {
  bloc.add(event);
  await pumpEventQueue();
  return bloc.state;
}

void main() {
  setUp(() {
    _auth = FakeAuthRepository();
    _owners = FakeDeviceOwnerRepository(ownerId: 'u-1');
    getIt
      ..registerSingleton<AuthRepository>(_auth)
      ..registerSingleton<DeviceOwnerRepository>(_owners);
  });

  tearDown(getIt.reset);

  test('unsynced changes block the sign-out, with their count', () async {
    _owners.unsyncedResult = const GPOk(5);

    expect(await _after(_bloc(), const SignOutRequestEvent()), const SignOutBlockedState(5));
  });

  test('nothing unsynced asks first, and a confirm signs out', () async {
    final bloc = _bloc();

    expect(await _after(bloc, const SignOutRequestEvent()), const SignOutConfirmingState());
    expect(await _after(bloc, const SignOutConfirmEvent()), const SignOutDoneState());
    expect(_owners.releases, 1);
    expect(_auth.signOutCalls, 1);
  });

  test('a cancel goes back to idle and signs nothing out', () async {
    final bloc = _bloc();
    await _after(bloc, const SignOutRequestEvent());

    expect(await _after(bloc, const SignOutCancelEvent()), const SignOutIdleState());
    expect(_auth.signOutCalls, 0);
  });

  test('a confirm with nothing asked does nothing', () async {
    expect(await _after(_bloc(), const SignOutConfirmEvent()), const SignOutIdleState());
    expect(_auth.signOutCalls, 0);
  });

  test('a failed wipe is an error, and can be tried again', () async {
    _owners.releaseResult = const GPErr(GPDatabaseFailure());
    final bloc = _bloc();
    await _after(bloc, const SignOutRequestEvent());

    expect(await _after(bloc, const SignOutConfirmEvent()), const SignOutErrorState(GPDatabaseFailure()));
    expect(await _after(bloc, const SignOutRequestEvent()), const SignOutConfirmingState());
  });

  test('after a sign-out, a later sign-out on the same screen is asked again', () async {
    final bloc = _bloc();
    await _after(bloc, const SignOutRequestEvent());
    await _after(bloc, const SignOutConfirmEvent());

    expect(await _after(bloc, const SignOutRequestEvent()), const SignOutConfirmingState());
  });
}
