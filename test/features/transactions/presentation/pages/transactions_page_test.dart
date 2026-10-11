import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_list_snapshot.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_list_bloc.dart';
import 'package:ghpockit/features/transactions/presentation/pages/transactions_page.dart';
import 'package:ghpockit/features/transactions/presentation/widgets/transaction_list_parts.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_transaction_repository.dart';
import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/localization_harness.dart';

void main() {
  const en = GPLocaleEn();
  const page = TransactionListBloc.pageSize;
  // Sunday 11 October 2026, noon local: every date below is local, so the test reads the same in any time zone.
  final clock = FakeClock(DateTime(2026, 10, 11, 12));

  late FakeTransactionRepository repository;

  setUpAll(initializeDateFormatting);
  setUp(() => getIt.registerSingleton<TransactionRepository>(repository = FakeTransactionRepository()));
  tearDown(getIt.reset);

  var ids = 0;
  TransactionEntity transaction({required DateTime at, TransactionType type = TransactionType.expense, int amount = 45000, String? note}) {
    final created = TransactionEntity.create(
      id: 'tx-${ids++}',
      type: type,
      accountId: 'acc-cash',
      destinationAccountId: type == TransactionType.transfer ? 'acc-bank' : null,
      amount: Money(amount, 'VND'),
      occurredAt: at.toUtc(),
      createdAt: at.toUtc(),
      updatedAt: at.toUtc(),
      note: note,
    );
    return (created as GPOk<TransactionEntity>).value;
  }

  TransactionListSnapshot snapshot(List<TransactionEntity> rows, {int unreadable = 0, bool hasMore = false}) =>
      TransactionListSnapshot(transactions: rows, unreadableCount: unreadable, hasMore: hasMore);

  List<TransactionEntity> today(int count) => <TransactionEntity>[for (var i = 0; i < count; i++) transaction(at: DateTime(2026, 10, 11, 11, 59 - i), note: 'Row $i')];

  Future<void> pumpPage(WidgetTester tester, {GPLocale locale = GPLocale.en, double textScale = 1}) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      localizedHarness(
        localization: await localizationFor(locale),
        child: BlocProvider<TransactionListBloc>(
          create: (_) => TransactionListBloc()..add(const TransactionListStarted()),
          child: TransactionsPage(clock: clock),
        ),
      ),
    );
    await tester.pump();
  }

  FakeWatch watch() => repository.watches.last;

  /// The bloc hands a snapshot on through a few microtask hops before the next frame shows it.
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
  }

  group('states', () {
    testWidgets('shows the skeleton until the first window arrives', (WidgetTester tester) async {
      await pumpPage(tester);

      expect(find.byType(TransactionListSkeleton), findsOneWidget);
    });

    testWidgets('shows the empty state when there are no rows', (WidgetTester tester) async {
      await pumpPage(tester);
      watch().emit(snapshot(const <TransactionEntity>[]));
      await flush(tester);

      expect(find.text(en.transactions.emptyTitle), findsOneWidget);
      expect(find.text(en.transactions.emptyMessage), findsOneWidget);
    });

    testWidgets('a failure before any row is a full-page error with no retry', (WidgetTester tester) async {
      await pumpPage(tester);
      watch().fail(const GPDatabaseFailure());
      await flush(tester);

      expect(find.text(en.error.database), findsOneWidget);
      expect(find.text(en.transactions.errorMessage), findsOneWidget);
      expect(find.byType(ButtonStyleButton), findsNothing);
    });

    testWidgets('a failure after rows keeps the rows under a banner', (WidgetTester tester) async {
      await pumpPage(tester);
      watch().emit(snapshot(<TransactionEntity>[transaction(at: DateTime(2026, 10, 11, 9), note: 'Cà phê sáng')]));
      await flush(tester);
      watch().fail(const GPDatabaseFailure());
      await flush(tester);

      expect(find.widgetWithText(TransactionListBanner, en.error.database), findsOneWidget);
      expect(find.text('Cà phê sáng'), findsOneWidget);
    });

    testWidgets('unreadable rows get a notice above the ones that read', (WidgetTester tester) async {
      await pumpPage(tester);
      watch().emit(snapshot(<TransactionEntity>[transaction(at: DateTime(2026, 10, 11, 9), note: 'Cà phê sáng')], unreadable: 2));
      await flush(tester);

      expect(find.widgetWithText(TransactionListBanner, "2 transactions can't be shown"), findsOneWidget);
      expect(find.text('Cà phê sáng'), findsOneWidget);
    });

    testWidgets('only unreadable rows is a notice, not the empty state', (WidgetTester tester) async {
      await pumpPage(tester);
      watch().emit(snapshot(const <TransactionEntity>[], unreadable: 1));
      await flush(tester);

      expect(find.text("1 transaction can't be shown"), findsOneWidget);
      expect(find.text(en.transactions.emptyTitle), findsNothing);
    });
  });

  group('rows', () {
    testWidgets('groups by local day under Today, Yesterday and a full date', (WidgetTester tester) async {
      await pumpPage(tester);
      watch().emit(
        snapshot(<TransactionEntity>[
          transaction(at: DateTime(2026, 10, 11, 9), note: 'Morning coffee'),
          transaction(at: DateTime(2026, 10, 10, 23, 59), type: TransactionType.income, amount: 18500000, note: 'October salary'),
          transaction(at: DateTime(2026, 10, 7, 0, 1), type: TransactionType.transfer, amount: 2000000),
        ]),
      );
      await flush(tester);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Wednesday, October 7'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Today')).dy, lessThan(tester.getTopLeft(find.text('Morning coffee')).dy));
      expect(tester.getTopLeft(find.text('Yesterday')).dy, lessThan(tester.getTopLeft(find.text('October salary')).dy));
    });

    testWidgets('a row shows the note or the type, the signed amount, and a transfer icon', (WidgetTester tester) async {
      await pumpPage(tester);
      watch().emit(
        snapshot(<TransactionEntity>[
          transaction(at: DateTime(2026, 10, 11, 9), note: 'Morning coffee'),
          transaction(at: DateTime(2026, 10, 11, 8), type: TransactionType.income),
          transaction(at: DateTime(2026, 10, 11, 7), type: TransactionType.transfer, amount: 2000000),
        ]),
      );
      await flush(tester);

      expect(find.text('Morning coffee'), findsOneWidget);
      expect(find.text('-₫45,000'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('+₫45,000'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('₫2,000,000'), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });

    testWidgets('speaks Vietnamese when the app does', (WidgetTester tester) async {
      await pumpPage(tester, locale: GPLocale.vi);
      watch().emit(snapshot(<TransactionEntity>[transaction(at: DateTime(2026, 10, 11, 9)), transaction(at: DateTime(2025, 12, 31, 9))]));
      await flush(tester);

      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('Thứ Tư, 31 tháng 12, 2025'), findsOneWidget);
      expect(find.text('Chi tiêu'), findsNWidgets(2));
    });

    testWidgets('at 130% text a long note is cut and the amount is not', (WidgetTester tester) async {
      await pumpPage(tester, textScale: 1.3);
      watch().emit(
        snapshot(<TransactionEntity>[
          transaction(at: DateTime(2026, 10, 11, 9), amount: 18500000, note: 'Team lunch at the broken-rice place on Nguyen Trai street'),
        ]),
      );
      await flush(tester);

      final amount = find.text('-₫18,500,000');
      expect(tester.takeException(), isNull);
      expect(tester.getRect(amount).right, lessThanOrEqualTo(390 - 16 - 16));
      expect(tester.getSize(find.byType(TransactionRow)).height, greaterThan(TransactionRow.minHeight));
    });
  });

  group('scrolling', () {
    testWidgets('the day header stays pinned while its rows scroll under it', (WidgetTester tester) async {
      await pumpPage(tester);
      watch().emit(snapshot(today(30)));
      await flush(tester);
      final pinnedAt = tester.getTopLeft(find.text('Today')).dy;

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();

      expect(tester.getTopLeft(find.text('Row 0')).dy, lessThan(pinnedAt), reason: 'the rows must have scrolled past the header');
      expect(tester.getTopLeft(find.text('Today')).dy, closeTo(pinnedAt, 1));
    });

    testWidgets('a full window shows the footer, and scrolling near it asks for the next window', (WidgetTester tester) async {
      await pumpPage(tester);
      watch().emit(snapshot(today(page), hasMore: true));
      await flush(tester);
      expect(repository.watches, hasLength(1));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -20000));
      await tester.pump();

      expect(find.byType(TransactionListFooter), findsOneWidget);
      expect(repository.watches, hasLength(2));
      expect(watch().query.limit, page * 2);
    });

    testWidgets('a window that is not full has no footer and asks for nothing', (WidgetTester tester) async {
      await pumpPage(tester);
      watch().emit(snapshot(today(20)));
      await flush(tester);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -20000));
      await tester.pump();

      expect(find.byType(TransactionListFooter), findsNothing);
      expect(repository.watches, hasLength(1));
    });
  });

  group('over the real repository', () {
    testWidgets('Done when: a row written to the database shows up with no refresh', (WidgetTester tester) async {
      final repos = InMemoryRepositories(clock: clock);
      addTearDown(repos.close);
      await getIt.unregister<TransactionRepository>();
      getIt.registerSingleton<TransactionRepository>(repos.transactions);

      await pumpPage(tester);
      await tester.pumpAndSettle();
      expect(find.text(en.transactions.emptyTitle), findsOneWidget);

      final account = await repos.accounts.createAccount(name: 'Cash', type: AccountType.cash, initialBalance: Money.zero('VND'));
      await repos.transactions.createTransaction(
        type: TransactionType.expense,
        accountId: (account as GPOk<AccountEntity>).value.id,
        amount: Money(45000, 'VND'),
        occurredAt: clock.nowUtc(),
        note: 'Cà phê sáng',
      );
      await tester.pumpAndSettle();

      expect(find.text('Cà phê sáng'), findsOneWidget);
      expect(find.text('-₫45,000'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });
  });
}
