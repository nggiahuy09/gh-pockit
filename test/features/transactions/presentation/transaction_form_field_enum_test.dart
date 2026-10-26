import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_form_field_enum.dart';

void main() {
  test('puts each refusal the form can meet on the field that fixes it', () {
    expect(_fieldOf(GPValidationCode.transactionAmountNotPositive), TransactionFormField.amount);
    expect(_fieldOf(GPValidationCode.transactionCurrencyMismatch), TransactionFormField.account);
    expect(_fieldOf(GPValidationCode.transactionCategoryTypeMismatch), TransactionFormField.category);
    expect(_fieldOf(GPValidationCode.transactionNoteTooLong), TransactionFormField.note);
  });

  test("puts a transfer's three refusals on the destination", () {
    for (final code in const [
      GPValidationCode.transactionDestinationMissing,
      GPValidationCode.transactionDestinationSameAsSource,
      GPValidationCode.transactionTransferCurrenciesDiffer,
    ]) {
      expect(_fieldOf(code), TransactionFormField.destination, reason: code.name);
    }
  });

  test('another form’s codes and every failure that is not a validation belong to no field', () {
    expect(_fieldOf(GPValidationCode.accountNameEmpty), isNull);
    for (final failure in const [GPNotFoundFailure(), GPDatabaseFailure(), GPConflictFailure(entityId: 'tx-1', localVersion: 1, remoteVersion: 2)]) {
      expect(TransactionFormField.fromFailure(failure), isNull, reason: '$failure');
    }
  });
}

TransactionFormField? _fieldOf(GPValidationCode code) => TransactionFormField.fromFailure(GPValidationFailure(code));
