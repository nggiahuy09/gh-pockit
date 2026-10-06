import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/money/money_formatter.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_labels.dart';

void main() {
  const locales = <GPLocaleBase>[GPLocaleEn(), GPLocaleVi()];

  TransactionEntity transaction(TransactionType type, {String? note}) {
    final created = TransactionEntity.create(
      id: 'tx-${type.name}',
      type: type,
      accountId: 'acc-cash',
      destinationAccountId: type == TransactionType.transfer ? 'acc-bank' : null,
      amount: Money(45000, 'VND'),
      occurredAt: DateTime.utc(2026, 10, 5, 3),
      createdAt: DateTime.utc(2026, 10, 5, 4),
      updatedAt: DateTime.utc(2026, 10, 5, 4),
      note: note,
    );

    return (created as GPOk<TransactionEntity>).value;
  }

  group('TransactionTypeLabel', () {
    test('every type has its own non-empty label in every language we ship', () {
      for (final locale in locales) {
        final labels = TransactionType.values.map((type) => type.labelIn(locale)).toList();

        expect(labels, everyElement(isNotEmpty), reason: locale.locale.languageCode);
        expect(labels.toSet(), hasLength(labels.length), reason: locale.locale.languageCode);
      }
    });

    test('the two languages actually differ', () {
      expect(TransactionType.transfer.labelIn(const GPLocaleEn()), 'Transfer');
      expect(TransactionType.transfer.labelIn(const GPLocaleVi()), 'Chuyển khoản');
    });
  });

  group('titleIn', () {
    test('is the note when there is one', () {
      expect(transaction(TransactionType.expense, note: 'Phở bò').titleIn(const GPLocaleVi()), 'Phở bò');
    });

    test('falls back to the type', () {
      expect(transaction(TransactionType.income).titleIn(const GPLocaleVi()), 'Thu nhập');
    });
  });

  group('amountLabel', () {
    test('signs an expense negative, an income positive, and a transfer not at all', () {
      const vi = GPMoneyFormatter(GPLocale.vi);

      expect(transaction(TransactionType.expense).amountLabel(vi), '-45.000 ₫');
      expect(transaction(TransactionType.income).amountLabel(vi), '+45.000 ₫');
      expect(transaction(TransactionType.transfer).amountLabel(vi), '45.000 ₫');
    });

    test('puts the sign ahead of a leading symbol', () {
      const en = GPMoneyFormatter(GPLocale.en);

      expect(transaction(TransactionType.expense).amountLabel(en), '-₫45,000');
      expect(transaction(TransactionType.income).amountLabel(en), '+₫45,000');
    });
  });
}
