import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

/// `TransactionType` (W4 T2).
void main() {
  test('stores the strings the schema and the wire expect', () {
    // Written out rather than derived from `name` — the argument against drift's `textEnum` is in `AccountType`'s doc. `'transfer'` matters twice: the
    // table's CHECK at W4 T3 names it as a literal (ADR-0009), so changing it would be a table rebuild as well as a data migration.
    expect(TransactionType.expense.storageValue, 'expense');
    expect(TransactionType.income.storageValue, 'income');
    expect(TransactionType.transfer.storageValue, 'transfer');
  });

  test('round-trips every value through storage', () {
    for (final type in TransactionType.values) {
      expect(TransactionType.fromStorage(type.storageValue), type);
    }
  });

  test('returns null for a value it does not know', () {
    // A corrupt row or one from a newer build. Null lets the mapper count the row as unreadable (ADR-0011) instead of the enum guessing — a fallback here
    // would hide the bad value and write the guess back on the next edit.
    expect(TransactionType.fromStorage('refund'), isNull);
    expect(TransactionType.fromStorage('Transfer'), isNull);
    expect(TransactionType.fromStorage(''), isNull);
  });
}
