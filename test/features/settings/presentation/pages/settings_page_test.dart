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

/// Fakes, not drift: the write starts from a tap inside the widget test's fake zone, where drift's query timers never fire.
/// `create_sample_transaction_use_case_test.dart` covers the real database.
void main() {
  group('debug tools', () {
    testWidgets('are absent from a release build', (WidgetTester tester) async {
      await tester.pumpWidget(localizedHarness(child: const SettingsPage(showDebugTools: false), localization: await localizationFor(GPLocale.en)));

      expect(find.text('Add a sample transaction'), findsNothing);
    });

    group('in a debug build', () {
      late _RecordingTransactionRepository transactions;

      setUp(() {
        final account = AccountEntity.create(
          id: 'acc-cash',
          name: 'Cash',
          type: AccountType.cash,
          initialBalance: Money.zero('VND'),
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        getIt
          ..registerSingleton<AccountRepository>(FakeAccountRepository(accounts: Stream<List<AccountEntity>>.value(<AccountEntity>[(account as GPOk<AccountEntity>).value])))
          ..registerSingleton<TransactionRepository>(transactions = _RecordingTransactionRepository())
          ..registerSingleton<GPClock>(FakeClock());
      });
      tearDown(getIt.reset);

      testWidgets('add a sample transaction in the UI language and say so', (WidgetTester tester) async {
        await tester.pumpWidget(localizedHarness(child: const SettingsPage(), localization: await localizationFor(GPLocale.en)));
        await tester.tap(find.text('Add a sample transaction'));
        await tester.pumpAndSettle();

        expect(transactions.notes, <String?>['Sample transaction']);
        expect(find.text('Sample transaction added.'), findsOneWidget);
      });

      testWidgets('show the failure instead when the write is refused', (WidgetTester tester) async {
        transactions.refuseWith = const GPDatabaseFailure();
        final localization = await localizationFor(GPLocale.en);
        await tester.pumpWidget(localizedHarness(child: const SettingsPage(), localization: localization));
        await tester.tap(find.text('Add a sample transaction'));
        await tester.pumpAndSettle();

        expect(find.text(localization.current.error.database), findsOneWidget);
      });
    });
  });
}

class _RecordingTransactionRepository extends FakeTransactionRepository {
  final List<String?> notes = <String?>[];
  GPFailure? refuseWith;

  @override
  Future<GPResult<TransactionEntity>> createTransaction({
    required TransactionType type,
    required String accountId,
    required Money amount,
    required DateTime occurredAt,
    String? destinationAccountId,
    String? categoryId,
    String? note,
  }) async {
    final refusal = refuseWith;
    if (refusal != null) return GPErr<TransactionEntity>(refusal);

    notes.add(note);
    return TransactionEntity.create(id: 'tx-1', type: type, accountId: accountId, amount: amount, occurredAt: occurredAt, createdAt: occurredAt, updatedAt: occurredAt, note: note);
  }
}
