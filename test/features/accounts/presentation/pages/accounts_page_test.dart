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

/// The first screen that reads the database (W3 flex), tested the way the user meets it: through the real `AccountRepositoryImpl` on in-memory Drift.
///
/// A fake repository would make the list, the empty state and the error state easy to stage — and would also make the two claims worth testing
/// unfalsifiable: that a row written to SQLite reaches the screen with no refresh (golden rule 1), and that its integer minor units arrive as the amount the
/// user entered (ADR-0007). So the fake is used only for what the real repository cannot produce on request: a list that has not arrived yet, and an error
/// that is not a `GPFailure`.
///
/// No test here configures `getIt`. That is the property the constructor-injected repository exists for, asserted by every test rather than by one.
void main() {
  late GPAppDatabase db;
  late AccountRepositoryImpl repository;

  setUp(() {
    // `closeStreamsSynchronously`: by default drift keeps a cancelled stream cached for one event-loop turn behind `Timer.run`, so the `StreamBuilder`'s
    // subscription outlives the widget tree by one timer — and a widget test fails on any timer still pending when the tree is torn down.
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
    // A stream that never emits. The real repository answers within a frame, which is too fast to catch reliably and says nothing about this state.
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

    // Integer minor units in, the amount the user entered out — exponent 0 for VND, 2 for USD, and no `double` anywhere between the row and this text.
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
    // Separators and symbol placement both move with the language — the same row reads `₫1,500,000` in English. The space is intl's non-breaking one.
    expect(find.text('1.500.000 ₫'), findsOneWidget);
  });

  testWidgets('shows an account created after it opened, with no refresh', (WidgetTester tester) async {
    // Golden rule 1 on screen: the page never asks again — the write lands in SQLite and the stream tells it.
    await pumpPage(tester);
    await tester.pumpAndSettle();
    expect(find.text('No accounts yet'), findsOneWidget);

    await create('Vietcombank', AccountType.bank, Money(25000000, 'VND'));
    await tester.pumpAndSettle();

    expect(find.text('Vietcombank'), findsOneWidget);
    expect(find.text('No accounts yet'), findsNothing);
  });

  testWidgets('shows the failure message when a stored row cannot be read', (WidgetTester tester) async {
    // A type this build does not know — a corrupt row, or one written by a newer version. The repository fails the whole list rather than hiding an
    // account (ADR-0006), and this is the screen that decision produces.
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
    // Only a `GPFailure` is an outcome with a sentence; anything else on the error channel is a bug, and ADR-0006 wants it loud and in the crash report.
    final errors = StreamController<List<AccountEntity>>();
    addTearDown(errors.close);
    await pumpPage(tester, using: FakeAccountRepository(accounts: errors.stream));

    errors.addError(StateError('broken invariant'));
    await tester.pump();

    expect(tester.takeException(), isA<StateError>());
    expect(find.text('Something went wrong.'), findsNothing);
  });
}
