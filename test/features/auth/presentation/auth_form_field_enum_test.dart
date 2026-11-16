import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/features/auth/presentation/auth_form_field_enum.dart';

void main() {
  test('puts every email refusal on the email field', () {
    for (final code in const [GPValidationCode.authEmailEmpty, GPValidationCode.authEmailInvalid, GPValidationCode.authEmailTaken]) {
      expect(AuthFormField.fromFailure(GPValidationFailure(code)), AuthFormField.email, reason: code.name);
    }
  });

  test('puts every password refusal on the password field', () {
    for (final code in const [GPValidationCode.authPasswordEmpty, GPValidationCode.authPasswordTooShort, GPValidationCode.authPasswordWeak]) {
      expect(AuthFormField.fromFailure(GPValidationFailure(code)), AuthFormField.password, reason: code.name);
    }
  });

  test('wrong credentials, a rate limit, the network and another form’s codes belong to no field', () {
    const failures = [
      GPValidationFailure(GPValidationCode.authInvalidCredentials),
      GPValidationFailure(GPValidationCode.accountNameEmpty),
      GPRateLimitedFailure(),
      GPNetworkFailure(),
      GPBackendUnavailableFailure(),
      GPUnknownFailure(),
    ];

    for (final failure in failures) {
      expect(AuthFormField.fromFailure(failure), isNull, reason: '$failure');
    }
  });
}
