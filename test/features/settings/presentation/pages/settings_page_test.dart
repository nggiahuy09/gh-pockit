import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/settings/presentation/pages/settings_page.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

import '../../../../helpers/fake_account_repository.dart';
import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_transaction_repository.dart';
import '../../../../helpers/localization_harness.dart';
import '../../../../helpers/results.dart';

/// Fakes, not drift: the write starts from a tap inside the widget test's fake zone, where drift's query timers never fire.
void main() {
  group('debug tools', () {
    testWidgets('are absent from a release build', (tester) async {
      await tester.pumpWidget(localizedHarness(localization: await localizationFor(GPLocale.en), child: const SettingsPage(showsDebugTools: false)));

      expect(find.text('Add a sample transaction'), findsNothing);
    });

    group('in a debug build', () {
      late _RecordingTransactionRepository transactions;

      setUp(() {
        final account = okValue(
          AccountEntity.create(
            initialBalance: Money.zero('VND'),
            type: AccountType.cash,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            id: 'acc-cash',
            name: 'Cash',
          ),
        );
        getIt
          ..registerSingleton<AccountRepository>(FakeAccountRepository(Stream.value([account])))
          ..registerSingleton<TransactionRepository>(transactions = _RecordingTransactionRepository())
          ..registerSingleton<GPClock>(FakeClock());
      });
      tearDown(getIt.reset);

      testWidgets('add a sample transaction in the UI language and say so', (tester) async {
        await tester.pumpWidget(localizedHarness(localization: await localizationFor(GPLocale.en), child: const SettingsPage()));
        await tester.tap(find.text('Add a sample transaction'));
        await tester.pumpAndSettle();

        expect(transactions.notes, ['Sample transaction']);
        expect(find.text('Sample transaction added.'), findsOneWidget);
      });

      testWidgets('show the failure instead when the write is refused', (tester) async {
        transactions.refuseWith = const GPDatabaseFailure();
        final localization = await localizationFor(GPLocale.en);
        await tester.pumpWidget(localizedHarness(localization: localization, child: const SettingsPage()));
        await tester.tap(find.text('Add a sample transaction'));
        await tester.pumpAndSettle();

        expect(find.text(localization.current.error.database), findsOneWidget);
      });
    });
  });
}

final class _RecordingTransactionRepository extends FakeTransactionRepository {
  final List<String?> _notes = [];

  GPFailure? refuseWith;

  List<String?> get notes => List.unmodifiable(_notes);

  @override
  Future<GPResult<TransactionEntity>> createTransaction({
    required Money amount,
    required TransactionType type,
    required DateTime occurredAt,
    required String accountId,
    String? categoryId,
    String? destinationAccountId,
    String? note,
  }) async {
    final refusal = refuseWith;
    if (refusal != null) return GPErr(refusal);

    _notes.add(note);
    return TransactionEntity.create(
      amount: amount,
      type: type,
      createdAt: occurredAt,
      occurredAt: occurredAt,
      updatedAt: occurredAt,
      accountId: accountId,
      id: 'tx-1',
      note: note,
    );
  }
}
