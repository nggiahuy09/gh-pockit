import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/money/money_formatter.dart';
import 'package:ghpockit/core/widgets/money_text.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_entity_extension.dart';

import '../../../helpers/results.dart';

void main() {
  group('getTitle', () {
    test('is the note when there is one', () {
      expect(_transaction(TransactionType.expense, note: 'Phở bò').getTitle(const GPLocaleVi()), 'Phở bò');
    });

    test('falls back to the type', () {
      expect(_transaction(TransactionType.income).getTitle(const GPLocaleVi()), 'Thu nhập');
    });
  });

  group('moneyTone', () {
    test('signs an expense negative, an income positive, and a transfer not at all', () {
      const vi = GPMoneyFormatter(GPLocale.vi);

      expect(_amount(vi, _transaction(TransactionType.expense)), '-45.000\u00a0₫');
      expect(_amount(vi, _transaction(TransactionType.income)), '+45.000\u00a0₫');
      expect(_amount(vi, _transaction(TransactionType.transfer)), '45.000\u00a0₫');
    });

    test('puts the sign ahead of a leading symbol', () {
      const en = GPMoneyFormatter(GPLocale.en);

      expect(_amount(en, _transaction(TransactionType.expense)), '-₫45,000');
      expect(_amount(en, _transaction(TransactionType.income)), '+₫45,000');
    });
  });
}

String _amount(GPMoneyFormatter formatter, TransactionEntity transaction) => GPMoneyText.label(transaction.amount, formatter, transaction.moneyTone);

TransactionEntity _transaction(TransactionType type, {String? note}) => okValue(
  TransactionEntity.create(
    amount: Money(45000, 'VND'),
    type: type,
    createdAt: DateTime.utc(2026, 10, 5, 4),
    occurredAt: DateTime.utc(2026, 10, 5, 3),
    updatedAt: DateTime.utc(2026, 10, 5, 4),
    accountId: 'acc-cash',
    destinationAccountId: type.isTransfer ? 'acc-bank' : null,
    id: 'tx-${type.name}',
    note: note,
  ),
);
