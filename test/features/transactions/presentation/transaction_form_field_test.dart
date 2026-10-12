import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_form_field.dart';

void main() {
  TransactionFormField? fieldOf(GPValidationCode code) => transactionFormFieldOf(GPValidationFailure(code));

  test('puts each refusal the form can meet on the field that fixes it', () {
    expect(fieldOf(GPValidationCode.transactionAmountNotPositive), TransactionFormField.amount);
    expect(fieldOf(GPValidationCode.transactionCurrencyMismatch), TransactionFormField.account);
    expect(fieldOf(GPValidationCode.transactionCategoryTypeMismatch), TransactionFormField.category);
    expect(fieldOf(GPValidationCode.transactionNoteTooLong), TransactionFormField.note);
  });

  test("leaves a transfer's refusals to the banner while the form has no destination field", () {
    expect(fieldOf(GPValidationCode.transactionDestinationMissing), isNull);
    expect(fieldOf(GPValidationCode.transactionDestinationSameAsSource), isNull);
    expect(fieldOf(GPValidationCode.transactionTransferCurrenciesDiffer), isNull);
  });

  test('another form’s codes and every failure that is not a validation belong to no field', () {
    expect(fieldOf(GPValidationCode.accountNameEmpty), isNull);
    expect(transactionFormFieldOf(const GPNotFoundFailure()), isNull);
    expect(transactionFormFieldOf(const GPDatabaseFailure()), isNull);
    expect(transactionFormFieldOf(const GPConflictFailure(entityId: 'tx-1', localVersion: 1, remoteVersion: 2)), isNull);
  });
}
