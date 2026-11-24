import 'dart:async';

import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/auth/domain/entities/auth_status.dart';
import 'package:ghpockit/features/auth/domain/entities/user_entity.dart';
import 'package:ghpockit/features/auth/domain/repositories/auth_repository.dart';

/// Answers with [result]; [gate], when set, holds every call until the test completes it.
final class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({this.result = const GPOk(UserEntity(id: 'u-1', email: 'huy@example.com'))});

  GPResult<UserEntity> result;
  Completer<void>? gate;

  final List<({String method, String email, String password})> calls = [];
  int signOutCalls = 0;
  int restoreCalls = 0;

  /// What `watchAuthStatus` emits; a test adds to it.
  final StreamController<AuthStatus> statuses = StreamController<AuthStatus>.broadcast();

  /// Sent first to every new watcher, like the real repository's current status. Null sends nothing until [statuses] does.
  AuthStatus? currentStatus;

  @override
  Stream<AuthStatus> watchAuthStatus() async* {
    final current = currentStatus;
    if (current != null) yield current;
    yield* statuses.stream;
  }

  @override
  Future<GPResult<void>> restoreSession() async {
    restoreCalls++;
    return const GPOk(null);
  }

  @override
  Future<GPResult<UserEntity>> signUp({required String email, required String password}) => _answer('signUp', email, password);

  @override
  Future<GPResult<UserEntity>> signIn({required String email, required String password}) => _answer('signIn', email, password);

  @override
  Future<GPResult<void>> signOut() async {
    signOutCalls++;
    // As the real one does: the session's end reaches every watcher.
    if (statuses.hasListener) statuses.add(const AuthSignedOut());
    return const GPOk(null);
  }

  Future<GPResult<UserEntity>> _answer(String method, String email, String password) async {
    calls.add((method: method, email: email, password: password));
    await gate?.future;
    return result;
  }
}
