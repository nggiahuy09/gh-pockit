import 'package:meta/meta.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';

/// Email first: the first refusal is the topmost field (ADR-0016).
@immutable
final class AuthCredentials {
  const AuthCredentials._(this.email, this.password);

  /// Sign-up only; matches `minimum_password_length` in `supabase/config.toml`.
  static const int passwordMinLength = 6;

  /// Length is left to the server: an account may predate a stricter client.
  static GPResult<AuthCredentials> forSignIn({required String email, required String password}) => _create(email: email, password: password, checkLength: false);

  static GPResult<AuthCredentials> forSignUp({required String email, required String password}) => _create(email: email, password: password, checkLength: true);

  static GPResult<AuthCredentials> _create({required String email, required String password, required bool checkLength}) {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) return const GPErr(GPValidationFailure(GPValidationCode.authEmailEmpty));
    if (!_emailShape.hasMatch(trimmedEmail)) return const GPErr(GPValidationFailure(GPValidationCode.authEmailInvalid));
    // Never trimmed: a space is a legal password character.
    if (password.isEmpty) return const GPErr(GPValidationFailure(GPValidationCode.authPasswordEmpty));
    if (checkLength && password.length < passwordMinLength) return const GPErr(GPValidationFailure(GPValidationCode.authPasswordTooShort));

    return GPOk(AuthCredentials._(trimmedEmail, password));
  }

  // Shape only; the server decides the rest.
  static final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final String email;
  final String password;

  @override
  String toString() => 'AuthCredentials(***)';
}
