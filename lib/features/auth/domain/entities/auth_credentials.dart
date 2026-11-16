import 'package:meta/meta.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';

/// Checked in form order, email then password, so the first refusal is the topmost field (ADR-0016).
@immutable
final class AuthCredentials {
  const AuthCredentials._(this.email, this.password);

  /// Sign-up only. Matches the server's `minimum_password_length` (`supabase/config.toml`); the server stays the authority.
  static const int passwordMinLength = 6;

  /// The password must not be empty; its length is the server's call, since an account may predate a stricter client.
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

  // Shape only (something@something.tld, no spaces): the server decides what it accepts.
  static final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final String email;
  final String password;

  @override
  String toString() => 'AuthCredentials(***)';
}
