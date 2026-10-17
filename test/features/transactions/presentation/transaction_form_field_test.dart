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

  test("puts a transfer's three refusals on the destination", () {
    expect(fieldOf(GPValidationCode.transactionDestinationMissing), TransactionFormField.destination);
    expect(fieldOf(GPValidationCode.transactionDestinationSameAsSource), TransactionFormField.destination);
    expect(fieldOf(GPValidationCode.transactionTransferCurrenciesDiffer), TransactionFormField.destination);
  });

  test('another form’s codes and every failure that is not a validation belong to no field', () {
    expect(fieldOf(GPValidationCode.accountNameEmpty), isNull);
    expect(transactionFormFieldOf(const GPNotFoundFailure()), isNull);
    expect(transactionFormFieldOf(const GPDatabaseFailure()), isNull);
    expect(transactionFormFieldOf(const GPConflictFailure(entityId: 'tx-1', localVersion: 1, remoteVersion: 2)), isNull);
  });
}
