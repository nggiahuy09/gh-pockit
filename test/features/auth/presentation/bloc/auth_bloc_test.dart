import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/features/auth/domain/entities/auth_status.dart';
import 'package:ghpockit/features/auth/domain/entities/user_entity.dart';
import 'package:ghpockit/features/auth/domain/repositories/auth_repository.dart';
import 'package:ghpockit/features/auth/presentation/bloc/auth_bloc.dart';

import '../../../../helpers/fake_auth_repository.dart';

late FakeAuthRepository _repository;

const _user = UserEntity(id: 'u-1', email: 'huy@example.com');

AuthBloc _bloc() {
  final bloc = AuthBloc();
  addTearDown(bloc.close);
  return bloc;
}

void main() {
  setUp(() {
    _repository = FakeAuthRepository();
    getIt.registerSingleton<AuthRepository>(_repository);
  });

  tearDown(getIt.reset);

  test('starts unknown and does not restore: the bootstrap already did', () async {
    final bloc = _bloc();
    await pumpEventQueue();

    expect(bloc.state, const AuthUnknownState());
    expect(_repository.restoreCalls, 0);
  });

  test('follows each status the repository sends', () async {
    final bloc = _bloc();
    final states = <AuthBlocState>[];
    bloc.stream.listen(states.add);
    await pumpEventQueue();

    _repository.statuses
      ..add(const AuthSignedOut())
      ..add(const AuthSignedIn(_user))
      ..add(const AuthSignedOut());
    await pumpEventQueue();

    expect(states, [const AuthSignedOutState(), const AuthSignedInState(_user), const AuthSignedOutState()]);
  });

  test('a build with no backend is local-only', () async {
    final bloc = _bloc();
    await pumpEventQueue();

    _repository.statuses.add(const AuthLocalOnly());
    await pumpEventQueue();

    expect(bloc.state, const AuthLocalOnlyState());
  });

  test('a signed-in state prints the user id, never the email', () {
    expect(const AuthSignedInState(_user).toString(), 'AuthSignedInState(u-1)');
  });
}
