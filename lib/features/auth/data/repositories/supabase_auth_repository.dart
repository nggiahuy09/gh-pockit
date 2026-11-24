import 'dart:async';

import 'package:supabase/supabase.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/auth_status.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/supabase_session_keeper.dart';
import '../mapper/user_mapper.dart';

/// Logs the GoTrue code and HTTP status only (golden rule 9).
final class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository({required GoTrueClient auth, required SupabaseSessionKeeper keeper, required GPAppLogger logger}) : _auth = auth, _keeper = keeper, _logger = logger;

  final GoTrueClient _auth;
  final SupabaseSessionKeeper _keeper;
  final GPAppLogger _logger;

  /// Reads the current session per event, since the stream replays history; a controller, as an `async*` hangs on cancel.
  @override
  Stream<AuthStatus> watchAuthStatus() {
    StreamSubscription<AuthState>? subscription;
    AuthStatus? last;
    late final StreamController<AuthStatus> controller;

    void emitCurrent() {
      final status = _currentStatus();
      if (status == last) return;

      last = status;
      controller.add(status);
    }

    controller = StreamController<AuthStatus>(
      onListen: () {
        emitCurrent();
        // Errors are failed refreshes; the session stays.
        subscription = _auth.onAuthStateChange.listen((_) => emitCurrent(), onError: (Object _) {});
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<GPResult<void>> restoreSession() async {
    _keeper.start();
    await _keeper.restore();
    return const GPOk(null);
  }

  @override
  Future<GPResult<UserEntity>> signUp({required String email, required String password}) => _authenticate(
    () => _auth.signUp(email: email, password: password),
    failedMessage: 'sign up failed',
    noSessionMessage: 'sign up returned no session',
  );

  @override
  Future<GPResult<UserEntity>> signIn({required String email, required String password}) => _authenticate(
    () => _auth.signInWithPassword(email: email, password: password),
    failedMessage: 'sign in failed',
    noSessionMessage: 'sign in returned no session',
  );

  @override
  Future<GPResult<void>> signOut() async {
    // GoTrue drops the local session before calling the server.
    try {
      await _auth.signOut();
    } on AuthException catch (error) {
      _logger.warn('sign out revoke failed', fields: _errorFields(error));
    }

    return const GPOk(null);
  }

  AuthStatus _currentStatus() => switch (_auth.currentSession?.user.toDomain()) {
    final user? => AuthSignedIn(user),
    null => const AuthSignedOut(),
  };

  Future<GPResult<UserEntity>> _authenticate(Future<AuthResponse> Function() request, {required String failedMessage, required String noSessionMessage}) async {
    final AuthResponse response;
    try {
      response = await request();
    } on AuthException catch (error) {
      return GPErr(_reportAuthError(error, message: failedMessage));
    } on Exception catch (error, stackTrace) {
      // An unparseable 200: only the type is logged, the body may hold a token.
      _logger.error(failedMessage, fields: {'error': error.runtimeType.toString()}, stackTrace: stackTrace);
      return const GPErr(GPUnknownFailure());
    }

    final session = response.session;
    // No session: the project requires email confirmation (off on dev, ADR-0032).
    if (session == null) {
      _logger.error(noSessionMessage);
      return const GPErr(GPUnknownFailure());
    }

    final user = session.user.toDomain();
    if (user == null) {
      _logger.error('auth user has no email', fields: {'user_id': session.user.id});
      return const GPErr(GPUnknownFailure());
    }

    return GPOk(user);
  }

  GPFailure _reportAuthError(AuthException error, {required String message}) {
    final failure = _toFailure(error);
    _logger.warn(message, fields: {..._errorFields(error), 'failure': failure.runtimeType.toString()});

    return failure;
  }

  Map<String, Object?> _errorFields(AuthException error) => {'error': error.runtimeType.toString(), 'code': error.code, 'status': error.statusCode};

  // `validation_failed` names no field (bad email and empty password alike); client validation catches both.
  static GPFailure _toFailure(AuthException error) => switch (error) {
    AuthWeakPasswordException() => const GPValidationFailure(GPValidationCode.authPasswordWeak),
    AuthRetryableFetchException(statusCode: null) => const GPNetworkFailure(),
    AuthException(code: 'invalid_credentials') => const GPValidationFailure(GPValidationCode.authInvalidCredentials),
    AuthException(code: 'user_already_exists' || 'email_exists') => const GPValidationFailure(GPValidationCode.authEmailTaken),
    AuthException(code: 'email_address_invalid') => const GPValidationFailure(GPValidationCode.authEmailInvalid),
    AuthException(code: 'over_request_rate_limit' || 'over_email_send_rate_limit') || AuthException(statusCode: '429') => const GPRateLimitedFailure(),
    _ => const GPUnknownFailure(),
  };
}
