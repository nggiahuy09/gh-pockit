import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/data/daos/account_dao.dart';
import 'package:ghpockit/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/presentation/pages/accounts_page.dart';

import '../../../../helpers/fake_account_repository.dart';
import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_uuid_generator.dart';
import '../../../../helpers/localization_harness.dart';
import '../../../../helpers/recording_logger.dart';

/// Through the real repository on in-memory drift; the fake stages only what that cannot: a list not yet arrived, an error that is not a `GPFailure`.
void main() {
  late GPAppDatabase db;
  late AccountRepositoryImpl repository;

  setUp(() {
    // Otherwise drift keeps a cancelled stream cached behind `Timer.run`, and a widget test fails on a timer still pending at teardown.
    db = GPAppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final clock = FakeClock();
    repository = AccountRepositoryImpl(
      dao: AccountDao(db),
      clock: clock,
      uuidGenerator: FakeUuidGenerator(),
      logger: RecordingLogger(clock: clock),
      ownerId: localOwnerId,
    );
  });

  tearDown(() => db.close());

  Future<void> pumpPage(WidgetTester tester, {AccountRepository? using, GPLocale locale = GPLocale.en}) async {
    await tester.pumpWidget(
      localizedHarness(
        child: AccountsPage(repository: using ?? repository),
        localization: await localizationFor(locale),
      ),
    );
  }

  Future<void> create(String name, AccountType type, Money initialBalance) async {
    final result = await repository.createAccount(name: name, type: type, initialBalance: initialBalance);
    expect(result, isA<GPOk<AccountEntity>>());
  }

  testWidgets('shows a progress indicator until the first list arrives', (WidgetTester tester) async {
    final pending = StreamController<List<AccountEntity>>();
    addTearDown(pending.close);

    await pumpPage(tester, using: FakeAccountRepository(accounts: pending.stream));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no accounts', (WidgetTester tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('No accounts yet'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('lists each account with its type and its opening balance', (WidgetTester tester) async {
    await create('Ví tiền mặt', AccountType.cash, Money(1500000, 'VND'));
    await create('Chase', AccountType.bank, Money(1234, 'USD'));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Ví tiền mặt'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('₫1,500,000'), findsOneWidget);
    expect(find.text('Chase'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text(r'$12.34'), findsOneWidget);
  });

  testWidgets('speaks the active language in the type and in the amount', (WidgetTester tester) async {
    await create('Ví tiền mặt', AccountType.cash, Money(1500000, 'VND'));

    await pumpPage(tester, locale: GPLocale.vi);
    await tester.pumpAndSettle();

    expect(find.text('Tiền mặt'), findsOneWidget);
    // The space is intl's non-breaking one.
    expect(find.text('1.500.000 ₫'), findsOneWidget);
  });

  testWidgets('shows an account created after it opened, with no refresh', (WidgetTester tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();
    expect(find.text('No accounts yet'), findsOneWidget);

    await create('Vietcombank', AccountType.bank, Money(25000000, 'VND'));
    await tester.pumpAndSettle();

    expect(find.text('Vietcombank'), findsOneWidget);
    expect(find.text('No accounts yet'), findsNothing);
  });

  testWidgets('shows the failure message when a stored row cannot be read', (WidgetTester tester) async {
    // 'savings' is a type this build does not know.
    await db
        .into(db.accountsTable)
        .insert(
          AccountsTableCompanion.insert(
            id: 'broken',
            ownerId: localOwnerId,
            name: 'Ví hỏng',
            type: 'savings',
            currencyCode: 'VND',
            initialBalance: 0,
            isArchived: false,
            createdAt: 0,
            updatedAt: 0,
            version: 1,
          ),
        );

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Could not read local data.'), findsOneWidget);
    expect(find.text('Ví hỏng'), findsNothing);
  });

  testWidgets('does not dress up a bug as a message', (WidgetTester tester) async {
    final errors = StreamController<List<AccountEntity>>();
    addTearDown(errors.close);
    await pumpPage(tester, using: FakeAccountRepository(accounts: errors.stream));

    errors.addError(StateError('broken invariant'));
    await tester.pump();

    expect(tester.takeException(), isA<StateError>());
    expect(find.text('Something went wrong.'), findsNothing);
  });
}
