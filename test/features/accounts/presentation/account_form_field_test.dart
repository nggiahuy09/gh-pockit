import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/features/accounts/presentation/account_form_field.dart';

void main() {
  test('puts both name refusals on the name field', () {
    expect(accountFormFieldOf(const GPValidationFailure(GPValidationCode.accountNameEmpty)), AccountFormField.name);
    expect(accountFormFieldOf(const GPValidationFailure(GPValidationCode.accountNameTooLong)), AccountFormField.name);
  });

  test('a refused delete, another form’s codes and every other failure belong to no field', () {
    expect(accountFormFieldOf(const GPValidationFailure(GPValidationCode.accountHasTransactions)), isNull);
    expect(accountFormFieldOf(const GPValidationFailure(GPValidationCode.transactionAmountNotPositive)), isNull);
    expect(accountFormFieldOf(const GPConflictFailure(entityId: 'acc-1', localVersion: 1, remoteVersion: 2)), isNull);
    expect(accountFormFieldOf(const GPNotFoundFailure()), isNull);
  });
}
