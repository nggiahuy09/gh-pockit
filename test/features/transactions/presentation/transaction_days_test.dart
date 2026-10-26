import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_days.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../helpers/results.dart';

void main() {
  setUpAll(initializeDateFormatting);

  group('groupByLocalDay', () {
    test('groups by local calendar day and keeps the list order', () {
      final days = groupByLocalDay([
        _at(DateTime(2026, 10, 5, 21), 'tx-4'),
        _at(DateTime(2026, 10, 5, 8), 'tx-3'),
        _at(DateTime(2026, 10, 4, 23, 59), 'tx-2'),
        _at(DateTime(2026, 10, 4), 'tx-1'),
      ]);

      expect(days.map((day) => day.date), [DateTime(2026, 10, 5), DateTime(2026, 10, 4)]);
      expect(days.first.transactions.map((t) => t.id), ['tx-4', 'tx-3']);
      expect(days.last.transactions.map((t) => t.id), ['tx-2', 'tx-1']);
    });

    test('splits at local midnight, not at UTC midnight', () {
      final days = groupByLocalDay([
        _at(DateTime(2026, 10, 5, 0, 1), 'tx-2'),
        _at(DateTime(2026, 10, 4, 23, 59), 'tx-1'),
      ]);

      expect(days, hasLength(2));
    });

    test('an empty list has no days', () {
      expect(groupByLocalDay(const []), isEmpty);
    });
  });

  group('getDayLabel', () {
    final today = DateTime(2026, 10, 6, 14);

    test('names today and yesterday in the active language', () {
      expect(getDayLabel(locale: const GPLocaleEn(), date: DateTime(2026, 10, 6), today: today), 'Today');
      expect(getDayLabel(locale: const GPLocaleVi(), date: DateTime(2026, 10, 5), today: today), 'Hôm qua');
    });

    test('yesterday crosses a month boundary', () {
      expect(getDayLabel(locale: const GPLocaleEn(), date: DateTime(2026, 9, 30), today: DateTime(2026, 10, 1, 9)), 'Yesterday');
    });

    test('an earlier day this year carries no year', () {
      expect(getDayLabel(locale: const GPLocaleEn(), date: DateTime(2026, 10, 4), today: today), 'Sunday, October 4');
      expect(getDayLabel(locale: const GPLocaleVi(), date: DateTime(2026, 10, 4), today: today), 'Chủ Nhật, 4 tháng 10');
    });

    test('a day in another year carries its year', () {
      expect(getDayLabel(locale: const GPLocaleEn(), date: DateTime(2025, 12, 31), today: today), 'Wednesday, December 31, 2025');
    });
  });
}

// Local wall-clock times, so the tests read the same in any time zone.
TransactionEntity _at(DateTime local, String id) => okValue(
  TransactionEntity.create(
    amount: Money(45000, 'VND'),
    type: TransactionType.expense,
    createdAt: DateTime.utc(2026, 10, 6),
    occurredAt: local,
    updatedAt: DateTime.utc(2026, 10, 6),
    accountId: 'acc-cash',
    id: id,
  ),
);
