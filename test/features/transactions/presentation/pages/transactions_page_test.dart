import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_list_snapshot.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_list_bloc.dart';
import 'package:ghpockit/features/transactions/presentation/pages/transactions_page.dart';
import 'package:ghpockit/features/transactions/presentation/widgets/transaction_list_widget.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_transaction_repository.dart';
import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/localization_harness.dart';
import '../../../../helpers/results.dart';

const _en = GPLocaleEn();
const int _page = TransactionListBloc.pageSize;
// Sunday 11 October 2026, noon local: every date below is local, so the test reads the same in any time zone.
final _clock = FakeClock(DateTime(2026, 10, 11, 12));
late FakeTransactionRepository _repository;
var _ids = 0;

void main() {
  setUpAll(initializeDateFormatting);
  setUp(() => getIt.registerSingleton<TransactionRepository>(_repository = FakeTransactionRepository()));
  tearDown(getIt.reset);

  // The bloc hands a snapshot on through a few microtask hops before the next frame shows it.

  group('states', () {
    testWidgets('shows the skeleton until the first window arrives', (tester) async {
      await _pumpPage(tester);

      expect(find.byType(TransactionListSkeletonWidget), findsOneWidget);
    });

    testWidgets('shows the empty state when there are no rows', (tester) async {
      await _pumpPage(tester);
      _watch().emit(_snapshot(const []));
      await _flush(tester);

      expect(find.text(_en.transactions.emptyTitle), findsOneWidget);
      expect(find.text(_en.transactions.emptyBody), findsOneWidget);
    });

    testWidgets('a failure before any row is a full-_page error with no retry', (tester) async {
      await _pumpPage(tester);
      _watch().fail(const GPDatabaseFailure());
      await _flush(tester);

      expect(find.text(_en.error.database), findsOneWidget);
      expect(find.text(_en.transactions.errorBody), findsOneWidget);
      expect(find.byType(ButtonStyleButton), findsNothing);
    });

    testWidgets('a failure after rows keeps the rows under a banner', (tester) async {
      await _pumpPage(tester);
      _watch().emit(_snapshot([_transaction(at: DateTime(2026, 10, 11, 9), note: 'Cà phê sáng')]));
      await _flush(tester);
      _watch().fail(const GPDatabaseFailure());
      await _flush(tester);

      expect(find.widgetWithText(TransactionListBannerWidget, _en.error.database), findsOneWidget);
      expect(find.text('Cà phê sáng'), findsOneWidget);
    });

    testWidgets('unreadable rows get a notice above the ones that read', (tester) async {
      await _pumpPage(tester);
      _watch().emit(_snapshot([_transaction(at: DateTime(2026, 10, 11, 9), note: 'Cà phê sáng')], unreadable: 2));
      await _flush(tester);

      expect(find.widgetWithText(TransactionListBannerWidget, "2 transactions can't be shown"), findsOneWidget);
      expect(find.text('Cà phê sáng'), findsOneWidget);
    });

    testWidgets('only unreadable rows is a notice, not the empty state', (tester) async {
      await _pumpPage(tester);
      _watch().emit(_snapshot(const [], unreadable: 1));
      await _flush(tester);

      expect(find.text("1 transaction can't be shown"), findsOneWidget);
      expect(find.text(_en.transactions.emptyTitle), findsNothing);
    });
  });

  group('rows', () {
    testWidgets('groups by local day under Today, Yesterday and a full date', (tester) async {
      await _pumpPage(tester);
      _watch().emit(
        _snapshot([
          _transaction(at: DateTime(2026, 10, 11, 9), note: 'Morning coffee'),
          _transaction(type: TransactionType.income, at: DateTime(2026, 10, 10, 23, 59), note: 'October salary', amount: 18500000),
          _transaction(type: TransactionType.transfer, at: DateTime(2026, 10, 7, 0, 1), amount: 2000000),
        ]),
      );
      await _flush(tester);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Wednesday, October 7'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Today')).dy, lessThan(tester.getTopLeft(find.text('Morning coffee')).dy));
      expect(tester.getTopLeft(find.text('Yesterday')).dy, lessThan(tester.getTopLeft(find.text('October salary')).dy));
    });

    testWidgets('a row shows the note or the type, the signed amount, and a transfer icon', (tester) async {
      await _pumpPage(tester);
      _watch().emit(
        _snapshot([
          _transaction(at: DateTime(2026, 10, 11, 9), note: 'Morning coffee'),
          _transaction(type: TransactionType.income, at: DateTime(2026, 10, 11, 8)),
          _transaction(type: TransactionType.transfer, at: DateTime(2026, 10, 11, 7), amount: 2000000),
        ]),
      );
      await _flush(tester);

      expect(find.text('Morning coffee'), findsOneWidget);
      expect(find.text('-₫45,000'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('+₫45,000'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('₫2,000,000'), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });

    testWidgets('speaks Vietnamese when the app does', (tester) async {
      await _pumpPage(tester, locale: GPLocale.vi);
      _watch().emit(_snapshot([_transaction(at: DateTime(2026, 10, 11, 9)), _transaction(at: DateTime(2025, 12, 31, 9))]));
      await _flush(tester);

      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('Thứ Tư, 31 tháng 12, 2025'), findsOneWidget);
      expect(find.text('Chi tiêu'), findsNWidgets(2));
    });

    testWidgets('at 130% text a long note is cut and the amount is not', (tester) async {
      await _pumpPage(tester, textScale: 1.3);
      _watch().emit(
        _snapshot([
          _transaction(at: DateTime(2026, 10, 11, 9), note: 'Team lunch at the broken-rice place on Nguyen Trai street', amount: 18500000),
        ]),
      );
      await _flush(tester);

      final amount = find.text('-₫18,500,000');
      expect(tester.takeException(), isNull);
      expect(tester.getRect(amount).right, lessThanOrEqualTo(390 - 16 - 16));
      expect(tester.getSize(find.byType(TransactionRowWidget)).height, greaterThan(TransactionRowWidget.minHeight));
    });
  });

  group('scrolling', () {
    testWidgets('the day header stays pinned while its rows scroll under it', (tester) async {
      await _pumpPage(tester);
      _watch().emit(_snapshot(_today(30)));
      await _flush(tester);
      final pinnedAt = tester.getTopLeft(find.text('Today')).dy;

      await tester.drag(find.byType(CustomScrollView), const Offset(0.0, -600.0));
      await tester.pump();

      expect(tester.getTopLeft(find.text('Row 0')).dy, lessThan(pinnedAt), reason: 'the rows must have scrolled past the header');
      expect(tester.getTopLeft(find.text('Today')).dy, closeTo(pinnedAt, 1.0));
    });

    testWidgets('a full window shows the footer, and scrolling near it asks for the next window', (tester) async {
      await _pumpPage(tester);
      _watch().emit(_snapshot(_today(_page), hasMore: true));
      await _flush(tester);
      expect(_repository.watches, hasLength(1));

      await tester.drag(find.byType(CustomScrollView), const Offset(0.0, -20000.0));
      await tester.pump();

      expect(find.byType(TransactionListFooterWidget), findsOneWidget);
      expect(_repository.watches, hasLength(2));
      expect(_watch().query.limit, _page * 2);
    });

    testWidgets('a window that is not full has no footer and asks for nothing', (tester) async {
      await _pumpPage(tester);
      _watch().emit(_snapshot(_today(20)));
      await _flush(tester);

      await tester.drag(find.byType(CustomScrollView), const Offset(0.0, -20000.0));
      await tester.pump();

      expect(find.byType(TransactionListFooterWidget), findsNothing);
      expect(_repository.watches, hasLength(1));
    });
  });

  group('over the real _repository', () {
    testWidgets('Done when: a row written to the database shows up with no refresh', (tester) async {
      final repos = InMemoryRepositories(_clock);
      addTearDown(repos.close);
      await getIt.unregister<TransactionRepository>();
      getIt.registerSingleton<TransactionRepository>(repos.transactions);

      await _pumpPage(tester);
      await tester.pumpAndSettle();
      expect(find.text(_en.transactions.emptyTitle), findsOneWidget);

      final account = okValue(await repos.accounts.createAccount(initialBalance: Money.zero('VND'), type: AccountType.cash, name: 'Cash'));
      await repos.transactions.createTransaction(
        amount: Money(45000, 'VND'),
        type: TransactionType.expense,
        occurredAt: _clock.nowUtc(),
        accountId: account.id,
        note: 'Cà phê sáng',
      );
      await tester.pumpAndSettle();

      expect(find.text('Cà phê sáng'), findsOneWidget);
      expect(find.text('-₫45,000'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });
  });
}

TransactionListSnapshot _snapshot(List<TransactionEntity> rows, {int unreadable = 0, bool hasMore = false}) =>
    TransactionListSnapshot(transactions: rows, unreadableCount: unreadable, hasMore: hasMore);

TransactionEntity _transaction({TransactionType type = TransactionType.expense, required DateTime at, String? note, int amount = 45000}) => okValue(
  TransactionEntity.create(
    amount: Money(amount, 'VND'),
    type: type,
    createdAt: at.toUtc(),
    occurredAt: at.toUtc(),
    updatedAt: at.toUtc(),
    accountId: 'acc-cash',
    destinationAccountId: type.isTransfer ? 'acc-bank' : null,
    id: 'tx-${_ids++}',
    note: note,
  ),
);

List<TransactionEntity> _today(int count) => [for (var i = 0; i < count; i++) _transaction(at: DateTime(2026, 10, 11, 11, 59 - i), note: 'Row $i')];

Future<void> _pumpPage(WidgetTester tester, {GPLocale locale = GPLocale.en, double textScale = 1.0}) async {
  tester.view
    ..physicalSize = const Size(390.0, 844.0)
    ..devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    localizedHarness(
      localization: await localizationFor(locale),
      child: TransactionsPage(clock: _clock),
    ),
  );
  await tester.pump();
}

FakeWatch _watch() => _repository.watches.last;

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
}
