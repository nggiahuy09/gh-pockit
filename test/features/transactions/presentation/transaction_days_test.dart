import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_days.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(initializeDateFormatting);

  // Local wall-clock times, so the tests read the same in any time zone.
  TransactionEntity at(String id, DateTime local) {
    final created = TransactionEntity.create(
      id: id,
      type: TransactionType.expense,
      accountId: 'acc-cash',
      amount: Money(45000, 'VND'),
      occurredAt: local,
      createdAt: DateTime.utc(2026, 10, 6),
      updatedAt: DateTime.utc(2026, 10, 6),
    );

    return (created as GPOk<TransactionEntity>).value;
  }

  group('groupByLocalDay', () {
    test('groups by local calendar day and keeps the list order', () {
      final days = groupByLocalDay([
        at('tx-4', DateTime(2026, 10, 5, 21)),
        at('tx-3', DateTime(2026, 10, 5, 8)),
        at('tx-2', DateTime(2026, 10, 4, 23, 59)),
        at('tx-1', DateTime(2026, 10, 4)),
      ]);

      expect(days.map((day) => day.date), [DateTime(2026, 10, 5), DateTime(2026, 10, 4)]);
      expect(days.first.transactions.map((t) => t.id), ['tx-4', 'tx-3']);
      expect(days.last.transactions.map((t) => t.id), ['tx-2', 'tx-1']);
    });

    test('splits at local midnight, not at UTC midnight', () {
      final days = groupByLocalDay([
        at('tx-2', DateTime(2026, 10, 5, 0, 1)),
        at('tx-1', DateTime(2026, 10, 4, 23, 59)),
      ]);

      expect(days, hasLength(2));
    });

    test('an empty list has no days', () {
      expect(groupByLocalDay(const []), isEmpty);
    });
  });

  group('dayLabel', () {
    final today = DateTime(2026, 10, 6, 14);

    test('names today and yesterday in the active language', () {
      expect(dayLabel(DateTime(2026, 10, 6), today: today, l10n: const GPLocaleEn()), 'Today');
      expect(dayLabel(DateTime(2026, 10, 5), today: today, l10n: const GPLocaleVi()), 'Hôm qua');
    });

    test('yesterday crosses a month boundary', () {
      expect(dayLabel(DateTime(2026, 9, 30), today: DateTime(2026, 10, 1, 9), l10n: const GPLocaleEn()), 'Yesterday');
    });

    test('an earlier day this year carries no year', () {
      expect(dayLabel(DateTime(2026, 10, 4), today: today, l10n: const GPLocaleEn()), 'Sunday, October 4');
      expect(dayLabel(DateTime(2026, 10, 4), today: today, l10n: const GPLocaleVi()), 'Chủ Nhật, 4 tháng 10');
    });

    test('a day in another year carries its year', () {
      expect(dayLabel(DateTime(2025, 12, 31), today: today, l10n: const GPLocaleEn()), 'Wednesday, December 31, 2025');
    });
  });
}
