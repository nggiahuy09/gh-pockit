import 'package:supabase/supabase.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../mapper/user_mapper.dart';

/// Logs a failure's GoTrue code and HTTP status only: never the email, the password, a token or the server's message (golden rule 9).
final class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository({required GoTrueClient auth, required GPAppLogger logger}) : _auth = auth, _logger = logger;

  final GoTrueClient _auth;
  final GPAppLogger _logger;

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
    // GoTrue drops the local session before it calls the server, so by the time this throws the device is already signed out.
    try {
      await _auth.signOut();
    } on AuthException catch (error) {
      _logger.warn('sign out revoke failed', fields: _errorFields(error));
    }

    return const GPOk(null);
  }

  Future<GPResult<UserEntity>> _authenticate(Future<AuthResponse> Function() request, {required String failedMessage, required String noSessionMessage}) async {
    final AuthResponse response;
    try {
      response = await request();
    } on AuthException catch (error) {
      return GPErr(_reportAuthError(error, message: failedMessage));
    } on Exception catch (error, stackTrace) {
      // A 200 whose body GoTrue cannot parse (`FormatException`). Only the type is logged: the body may hold a token.
      _logger.error(failedMessage, fields: {'error': error.runtimeType.toString()}, stackTrace: stackTrace);
      return const GPErr(GPUnknownFailure());
    }

    final session = response.session;
    // No session means the project wants the email confirmed first; dev has that off (ADR-0032).
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

  // `validation_failed` stays unknown on purpose: GoTrue sends it for a malformed email and for an empty password alike, so it names no field.
  // Client-side validation is what catches both, before a request.
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
