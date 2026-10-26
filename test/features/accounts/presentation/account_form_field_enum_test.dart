import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/features/accounts/presentation/account_form_field_enum.dart';

void main() {
  test('puts both name refusals on the name field', () {
    for (final code in const [GPValidationCode.accountNameEmpty, GPValidationCode.accountNameTooLong]) {
      expect(AccountFormField.fromFailure(GPValidationFailure(code)), AccountFormField.name, reason: code.name);
    }
  });

  test('a refused delete, another form’s codes and every other failure belong to no field', () {
    const failures = [
      GPValidationFailure(GPValidationCode.accountHasTransactions),
      GPValidationFailure(GPValidationCode.transactionAmountNotPositive),
      GPConflictFailure(entityId: 'acc-1', localVersion: 1, remoteVersion: 2),
      GPNotFoundFailure(),
    ];

    for (final failure in failures) {
      expect(AccountFormField.fromFailure(failure), isNull, reason: '$failure');
    }
  });
}
