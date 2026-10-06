import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_list_snapshot.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/domain/usecases/watch_transactions_use_case.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_list_bloc.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_transaction_repository.dart';
import '../../../../helpers/fake_uuid_generator.dart';
import '../../../../helpers/recording_logger.dart';

void main() {
  const page = TransactionListBloc.pageSize;

  late FakeTransactionRepository repository;

  setUp(() => repository = FakeTransactionRepository());

  TransactionEntity transaction(int n) {
    final created = TransactionEntity.create(
      id: 'tx-$n',
      type: TransactionType.expense,
      accountId: 'acc-cash',
      amount: Money(125000, 'VND'),
      occurredAt: DateTime.utc(2026, 10, 4, 5, 30),
      createdAt: DateTime.utc(2026, 10, 4, 6),
      updatedAt: DateTime.utc(2026, 10, 4, 6),
      note: 'Phở bò',
    );

    return (created as GPOk<TransactionEntity>).value;
  }

  /// `hasMore` exactly as the repository sets it, so every seeded state is one it can produce.
  TransactionListSnapshot snapshotOf({required int limit, required int rows, int unreadable = 0}) {
    assert(rows + unreadable <= limit, 'a window never returns more rows than its limit');

    return TransactionListSnapshot(transactions: [for (var i = 0; i < rows; i++) transaction(i)], unreadableCount: unreadable, hasMore: rows + unreadable == limit);
  }

  TransactionListBloc listOver(TransactionRepository transactions) => TransactionListBloc(watchTransactions: WatchTransactionsUseCase(transactionRepository: transactions));

  TransactionListBloc fresh() {
    final bloc = listOver(repository);
    addTearDown(bloc.close);
    return bloc;
  }

  TransactionListBloc seeded(TransactionListState seed) {
    final bloc = _SeededTransactionListBloc(seed, WatchTransactionsUseCase(transactionRepository: repository));
    addTearDown(bloc.close);
    return bloc;
  }

  /// Reads states off `bloc.stream` by hand: `bloc_test` does not resolve on this SDK (see `pubspec.yaml`).
  Future<List<TransactionListState>> statesDuring(TransactionListBloc bloc, void Function() act) async {
    final states = <TransactionListState>[];
    final subscription = bloc.stream.listen(states.add);

    act();
    // Events and fake emissions are delivered asynchronously.
    await pumpEventQueue();

    await subscription.cancel();
    return states;
  }

  Future<List<TransactionListState>> statesAfter(TransactionListBloc bloc, List<TransactionListEvent> events) => statesDuring(bloc, () => events.forEach(bloc.add));

  group('TransactionListState', () {
    test('before Started: nothing watched, and loading — the first frame is a progress indicator, not a blank', () {
      const state = TransactionListState();

      expect(state.query, isNull);
      expect(state.isLoading, isTrue);
      expect(state.hasMore, isFalse);
      expect(state.isLoadingMore, isFalse);
    });

    test('a failure before any row arrived is the error state, not loading', () {
      final state = TransactionListState(
        query: TransactionQuery(limit: page),
        failure: const GPDatabaseFailure(),
      );

      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
    });

    test('with rows on screen, hasMore is the window having come back full', () {
      final query = TransactionQuery(limit: page);
      final full = TransactionListState(
        query: query,
        snapshot: snapshotOf(limit: page, rows: page),
      );
      final short = TransactionListState(
        query: query,
        snapshot: snapshotOf(limit: page, rows: 3),
      );

      expect(full.isLoading, isFalse);
      expect(full.hasMore, isTrue);
      expect(short.hasMore, isFalse);
      expect(full.isLoadingMore, isFalse);
    });

    group('isLoadingMore', () {
      final grown = TransactionQuery(limit: 2 * page);

      test('while the rows on screen came back full from a smaller window than the one watched', () {
        expect(
          TransactionListState(
            query: grown,
            snapshot: snapshotOf(limit: page, rows: page),
          ).isLoadingMore,
          isTrue,
        );
      });

      test('ends with the first emission of the larger window, whether it fills it or comes back short', () {
        expect(
          TransactionListState(
            query: grown,
            snapshot: snapshotOf(limit: 2 * page, rows: 2 * page),
          ).isLoadingMore,
          isFalse,
        );
        expect(
          TransactionListState(
            query: grown,
            snapshot: snapshotOf(limit: 2 * page, rows: page + 7),
          ).isLoadingMore,
          isFalse,
        );
        // Exactly one window's worth of rows in the table: the larger window returns the same rows, and this time they do not fill it.
        expect(
          TransactionListState(
            query: grown,
            snapshot: snapshotOf(limit: 2 * page, rows: page),
          ).isLoadingMore,
          isFalse,
        );
      });

      test('ends with a failure, which is the larger window answering', () {
        final failed = TransactionListState(
          query: grown,
          snapshot: snapshotOf(limit: page, rows: page),
          failure: const GPDatabaseFailure(),
        );

        expect(failed.isLoadingMore, isFalse);
        expect(failed.snapshot, isNotNull);
      });
    });

    group('equality', () {
      TransactionListState state({Set<String> accountIds = const {'acc-cash', 'acc-bank'}, int rows = 2, GPFailure? failure = const GPDatabaseFailure()}) => TransactionListState(
        query: TransactionQuery(limit: page, accountIds: accountIds),
        snapshot: snapshotOf(limit: page, rows: rows),
        failure: failure,
      );

      test('is by value: the same filter in another order, fresh instances of the same rows', () {
        expect(state(), state(accountIds: {'acc-bank', 'acc-cash'}));
        expect(state().hashCode, state(accountIds: {'acc-bank', 'acc-cash'}).hashCode);
      });

      test('differs when the query, the rows or the failure differs', () {
        expect(state(), isNot(state(accountIds: {'acc-cash'})));
        expect(state(), isNot(state(rows: 3)));
        expect(state(), isNot(state(failure: null)));
        expect(state(), isNot(state(failure: const GPNotFoundFailure())));
      });
    });

    test('prints ids and counts, never an amount or a note (golden rule 9)', () {
      final printed = TransactionListState(
        query: TransactionQuery(limit: page),
        snapshot: snapshotOf(limit: page, rows: 2),
      ).toString();

      expect(printed, isNot(contains('Phở')));
      expect(printed, isNot(contains('125000')));
    });
  });

  group('TransactionListStarted', () {
    test('watches every transaction, newest first, one page deep', () async {
      expect(await statesAfter(fresh(), [const TransactionListStarted()]), [TransactionListState(query: TransactionQuery(limit: page))]);
    });

    test('a second one does not start a scrolled list over', () async {
      final bloc = seeded(
        TransactionListState(
          query: TransactionQuery(limit: 2 * page),
          snapshot: snapshotOf(limit: 2 * page, rows: 2 * page),
        ),
      );

      expect(await statesAfter(bloc, [const TransactionListStarted()]), isEmpty);
    });
  });

  group('TransactionListFilterChanged', () {
    test('is ignored before Started: there is nothing to filter yet', () async {
      expect(
        await statesAfter(fresh(), [
          const TransactionListFilterChanged(types: {TransactionType.income}),
        ]),
        isEmpty,
      );
    });

    test('starts the new filter over at one page, with neither the rows nor the failure of the old one', () async {
      final bloc = seeded(
        TransactionListState(
          query: TransactionQuery(limit: 3 * page, types: const {TransactionType.expense}),
          snapshot: snapshotOf(limit: 3 * page, rows: 3 * page),
          failure: const GPDatabaseFailure(),
        ),
      );

      final states = await statesAfter(bloc, [
        const TransactionListFilterChanged(types: {TransactionType.income}),
      ]);

      expect(states, [
        TransactionListState(
          query: TransactionQuery(limit: page, types: const {TransactionType.income}),
        ),
      ]);
      expect(states.single.isLoading, isTrue);
    });

    test('replaces the whole filter rather than patching the old one', () async {
      final bloc = seeded(
        TransactionListState(
          query: TransactionQuery(limit: page, accountIds: const {'acc-cash'}, types: const {TransactionType.expense}),
        ),
      );

      final states = await statesAfter(bloc, [
        const TransactionListFilterChanged(types: {TransactionType.expense}),
      ]);

      expect(states, [
        TransactionListState(
          query: TransactionQuery(limit: page, types: const {TransactionType.expense}),
        ),
      ]);
    });

    test('the filter it already has changes nothing: not the window, not the rows', () async {
      final from = DateTime.utc(2026, 9, 30, 17);
      final to = DateTime.utc(2026, 10, 31, 17);
      final bloc = seeded(
        TransactionListState(
          query: TransactionQuery(limit: 2 * page, accountIds: const {'acc-cash', 'acc-bank'}, from: from, to: to),
          snapshot: snapshotOf(limit: 2 * page, rows: 2 * page),
        ),
      );

      // Another set order, and an empty set — which `TransactionQuery` reads as no filter, like null: still the filter in force.
      final states = await statesAfter(bloc, [
        TransactionListFilterChanged(accountIds: const {'acc-bank', 'acc-cash'}, categoryIds: const {}, from: from, to: to),
      ]);

      expect(states, isEmpty);
    });

    test('a range that ends before it starts is a bug, and it is not swallowed', () async {
      final errors = <Object>[];
      // A handler's error is rethrown into the zone the bloc was created in.
      final bloc = runZonedGuarded(() => listOver(repository), (Object error, StackTrace _) => errors.add(error))!;
      addTearDown(bloc.close);

      final states = await statesAfter(bloc, [
        const TransactionListStarted(),
        TransactionListFilterChanged(from: DateTime.utc(2026, 10, 5), to: DateTime.utc(2026, 10, 4)),
      ]);

      expect(errors, [isA<ArgumentError>()]);
      expect(states, [TransactionListState(query: TransactionQuery(limit: page))]);
    });
  });

  group('TransactionListLoadMoreRequested', () {
    test('grows a full window by one page, keeping its filter and its rows on screen meanwhile', () async {
      final rows = snapshotOf(limit: page, rows: page);
      final bloc = seeded(
        TransactionListState(
          query: TransactionQuery(limit: page, types: const {TransactionType.expense}),
          snapshot: rows,
        ),
      );

      final states = await statesAfter(bloc, [const TransactionListLoadMoreRequested()]);

      expect(states, [
        TransactionListState(
          query: TransactionQuery(limit: 2 * page, types: const {TransactionType.expense}),
          snapshot: rows,
        ),
      ]);
      expect(states.single.isLoadingMore, isTrue);
    });

    test('asks once, however often a scroll listener sends it', () async {
      final bloc = seeded(
        TransactionListState(
          query: TransactionQuery(limit: page),
          snapshot: snapshotOf(limit: page, rows: page),
        ),
      );

      final states = await statesAfter(bloc, List.filled(5, const TransactionListLoadMoreRequested()));

      expect(states, hasLength(1));
      expect(states.single.query?.limit, 2 * page);
    });

    test('counts the rows it could not read toward the window', () async {
      // 48 mapped + 2 unreadable fill the window; counting the mapped rows alone would ask for 98.
      final bloc = seeded(
        TransactionListState(
          query: TransactionQuery(limit: page),
          snapshot: snapshotOf(limit: page, rows: page - 2, unreadable: 2),
        ),
      );

      final states = await statesAfter(bloc, [const TransactionListLoadMoreRequested()]);

      expect(states.single.query?.limit, 2 * page);
    });

    test('is ignored when the window came back short: the list has ended', () async {
      final bloc = seeded(
        TransactionListState(
          query: TransactionQuery(limit: page),
          snapshot: snapshotOf(limit: page, rows: page - 1),
        ),
      );

      expect(await statesAfter(bloc, [const TransactionListLoadMoreRequested()]), isEmpty);
    });

    test('is ignored before the first rows arrive', () async {
      final states = await statesAfter(fresh(), [const TransactionListStarted(), const TransactionListLoadMoreRequested()]);

      expect(states, [TransactionListState(query: TransactionQuery(limit: page))]);
    });

    test('drops the failure, which belonged to the watch the larger window replaces', () async {
      final rows = snapshotOf(limit: page, rows: page);
      final bloc = seeded(
        TransactionListState(
          query: TransactionQuery(limit: page),
          snapshot: rows,
          failure: const GPDatabaseFailure(),
        ),
      );

      final states = await statesAfter(bloc, [const TransactionListLoadMoreRequested()]);

      expect(states, [
        TransactionListState(
          query: TransactionQuery(limit: 2 * page),
          snapshot: rows,
        ),
      ]);
    });

    test('does not grow past a larger window whose watch failed', () async {
      final bloc = seeded(
        TransactionListState(
          query: TransactionQuery(limit: 2 * page),
          snapshot: snapshotOf(limit: page, rows: page),
          failure: const GPDatabaseFailure(),
        ),
      );

      expect(await statesAfter(bloc, [const TransactionListLoadMoreRequested()]), isEmpty);
    });
  });

  group('watching', () {
    Future<TransactionListBloc> started() async {
      final bloc = fresh();
      await statesAfter(bloc, [const TransactionListStarted()]);
      return bloc;
    }

    test('Started opens one watch on the first page, and what it emits is what the list shows', () async {
      final bloc = await started();
      final rows = snapshotOf(limit: page, rows: 3);

      final states = await statesDuring(bloc, () => repository.watches.single.emit(rows));

      expect(repository.watches.single.query, TransactionQuery(limit: page));
      expect(states, [
        TransactionListState(
          query: TransactionQuery(limit: page),
          snapshot: rows,
        ),
      ]);
    });

    test('a new filter cancels the old watch before the new one starts', () async {
      final bloc = await started();

      await statesAfter(bloc, [
        const TransactionListFilterChanged(types: {TransactionType.income}),
      ]);

      expect(repository.log, ['listen #0', 'cancel #0', 'listen #1']);
      expect(repository.watches.last.query, TransactionQuery(limit: page, types: const {TransactionType.income}));
    });

    test('an emission of the old filter that lands after the change never reaches the screen', () async {
      final bloc = await started();

      final states = await statesDuring(bloc, () {
        bloc.add(const TransactionListFilterChanged(types: {TransactionType.income}));
        // Delivered after the filter change and before `restartable` cancels the old watch.
        repository.watches.first.emit(snapshotOf(limit: page, rows: 3));
      });

      expect(states, [
        TransactionListState(
          query: TransactionQuery(limit: page, types: const {TransactionType.income}),
        ),
      ]);
    });

    test('load more keeps the rows on screen until the larger window answers on its own watch', () async {
      final bloc = await started();
      final firstPage = snapshotOf(limit: page, rows: page);
      await statesDuring(bloc, () => repository.watches.first.emit(firstPage));

      await statesAfter(bloc, [const TransactionListLoadMoreRequested()]);

      expect(bloc.state.snapshot, firstPage);
      expect(bloc.state.isLoadingMore, isTrue);
      expect(repository.log, ['listen #0', 'cancel #0', 'listen #1']);
      expect(repository.watches.last.query.limit, 2 * page);

      final twoPages = snapshotOf(limit: 2 * page, rows: 2 * page);
      await statesDuring(bloc, () => repository.watches.last.emit(twoPages));

      expect(bloc.state.snapshot, twoPages);
      expect(bloc.state.isLoadingMore, isFalse);
    });

    test('five load-more requests open one more watch, not five', () async {
      final bloc = await started();
      await statesDuring(bloc, () => repository.watches.first.emit(snapshotOf(limit: page, rows: page)));

      await statesAfter(bloc, List.filled(5, const TransactionListLoadMoreRequested()));

      expect(repository.watches, hasLength(2));
    });

    test('a failure keeps the rows, and the next emission of the same watch clears it', () async {
      final bloc = await started();
      final watch = repository.watches.single;
      final rows = snapshotOf(limit: page, rows: 3);
      await statesDuring(bloc, () => watch.emit(rows));

      await statesDuring(bloc, () => watch.fail(const GPDatabaseFailure()));

      expect(bloc.state.failure, const GPDatabaseFailure());
      expect(bloc.state.snapshot, rows);

      await statesDuring(bloc, () => watch.emit(rows));

      expect(bloc.state.failure, isNull);
      expect(watch.isListened, isTrue);
    });

    test('an error that is not a GPFailure is a bug, and it is not swallowed', () async {
      final errors = <Object>[];
      final bloc = runZonedGuarded(() => listOver(repository), (Object error, StackTrace _) => errors.add(error))!;
      addTearDown(bloc.close);
      await statesAfter(bloc, [const TransactionListStarted()]);

      final states = await statesDuring(bloc, () => repository.watches.single.fail(StateError('bug')));

      expect(errors, [isA<StateError>()]);
      expect(states, isEmpty);
    });

    test('close cancels the running watch', () async {
      final bloc = listOver(repository);
      await statesAfter(bloc, [const TransactionListStarted()]);

      await bloc.close();

      expect(repository.log, ['listen #0', 'cancel #0']);
    });
  });

  group('over the real repository', () {
    test('a row written to the database reaches the list with no event sent', () async {
      final db = GPAppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = FakeClock(DateTime.utc(2026, 10, 6, 9));
      final transactions = TransactionRepositoryImpl(
        dao: TransactionDao(db),
        clock: clock,
        uuidGenerator: FakeUuidGenerator(),
        logger: RecordingLogger(clock: clock),
        ownerId: localOwnerId,
      );
      await db
          .into(db.accountsTable)
          .insert(
            AccountsTableCompanion.insert(
              id: 'acc-cash',
              ownerId: localOwnerId,
              name: 'Cash',
              type: 'cash',
              currencyCode: 'VND',
              initialBalance: 0,
              isArchived: false,
              createdAt: 0,
              updatedAt: 0,
              version: 1,
            ),
          );

      final bloc = listOver(transactions)..add(const TransactionListStarted());
      addTearDown(bloc.close);
      await expectLater(bloc.stream, emitsThrough(predicate<TransactionListState>((state) => state.snapshot?.transactions.isEmpty ?? false)));

      final updated = expectLater(bloc.stream, emitsThrough(predicate<TransactionListState>((state) => state.snapshot?.transactions.length == 1)));
      final created = await transactions.createTransaction(
        type: TransactionType.expense,
        accountId: 'acc-cash',
        amount: Money(45000, 'VND'),
        occurredAt: DateTime.utc(2026, 10, 6, 8),
      );

      expect(created, isA<GPOk<TransactionEntity>>());
      await updated;
    });
  });
}

/// `bloc_test`'s `seed`: starts from a state without driving a watch to it. `emit` is protected, so only a subclass may call it.
class _SeededTransactionListBloc extends TransactionListBloc {
  _SeededTransactionListBloc(TransactionListState seed, WatchTransactionsUseCase watchTransactions) : super(watchTransactions: watchTransactions) {
    emit(seed);
  }
}
