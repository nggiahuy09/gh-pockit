import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

void main() {
  test('stores the strings the schema and the wire expect', () {
    // Changing one means a migration, and for 'transfer' a table rebuild too: the table's CHECK names it.
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
    expect(TransactionType.fromStorage('refund'), isNull);
    expect(TransactionType.fromStorage('Transfer'), isNull);
    expect(TransactionType.fromStorage(''), isNull);
  });

  test('files an expense and an income under their own kind of category, and a transfer under none', () {
    expect(TransactionType.expense.categoryType, CategoryType.expense);
    expect(TransactionType.income.categoryType, CategoryType.income);
    expect(TransactionType.transfer.categoryType, isNull);
  });
}
