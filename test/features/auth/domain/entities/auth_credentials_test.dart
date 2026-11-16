import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/auth/domain/entities/auth_credentials.dart';

import '../../../../helpers/results.dart';

GPResult<AuthCredentials> _signUp(String email, String password) => AuthCredentials.forSignUp(email: email, password: password);

GPResult<AuthCredentials> _signIn(String email, String password) => AuthCredentials.forSignIn(email: email, password: password);

GPResult<AuthCredentials> _refused(GPValidationCode code) => GPErr(GPValidationFailure(code));

void main() {
  group('email', () {
    test('is trimmed', () {
      expect(okValue(_signIn('  huy@example.com \n', 'secret')).email, 'huy@example.com');
    });

    test('empty or blank is refused', () {
      expect(_signIn('', 'secret'), _refused(GPValidationCode.authEmailEmpty));
      expect(_signIn('   ', 'secret'), _refused(GPValidationCode.authEmailEmpty));
    });

    test('without an @, a domain or a dot in the domain is refused', () {
      for (final email in ['huy', 'huy@', '@example.com', 'huy@example', 'huy @example.com', 'huy@exa mple.com']) {
        expect(_signUp(email, 'secret-1'), _refused(GPValidationCode.authEmailInvalid), reason: email);
      }
    });

    test('a plus, a subdomain or an uppercase letter is accepted: the server decides past the shape', () {
      for (final email in ['huy+pockit@example.com', 'huy@mail.example.co.uk', 'Huy@Example.com']) {
        expect(_signUp(email, 'secret-1'), isA<GPOk<AuthCredentials>>(), reason: email);
      }
    });

    test('is checked before the password: the first refusal is the topmost field', () {
      expect(_signUp('', ''), _refused(GPValidationCode.authEmailEmpty));
    });
  });

  group('password', () {
    test('empty is refused on both', () {
      expect(_signIn('huy@example.com', ''), _refused(GPValidationCode.authPasswordEmpty));
      expect(_signUp('huy@example.com', ''), _refused(GPValidationCode.authPasswordEmpty));
    });

    test('is never trimmed', () {
      expect(okValue(_signIn('huy@example.com', ' pass ')).password, ' pass ');
    });

    test('sign-up refuses one under the minimum and accepts the minimum', () {
      final short = 'x' * (AuthCredentials.passwordMinLength - 1);
      final exact = 'x' * AuthCredentials.passwordMinLength;

      expect(_signUp('huy@example.com', short), _refused(GPValidationCode.authPasswordTooShort));
      expect(okValue(_signUp('huy@example.com', exact)).password, exact);
    });

    test('sign-in leaves a short password to the server', () {
      expect(_signIn('huy@example.com', '123'), isA<GPOk<AuthCredentials>>());
    });

    test('the minimum matches the server', () {
      expect(AuthCredentials.passwordMinLength, 6);
    });
  });

  test('toString prints neither field', () {
    final printed = okValue(_signUp('huy@example.com', 'correct-horse')).toString();

    expect(printed, isNot(contains('huy')));
    expect(printed, isNot(contains('horse')));
  });
}
