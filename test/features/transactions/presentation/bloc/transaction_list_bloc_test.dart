import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
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
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_list_bloc.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_transaction_repository.dart';
import '../../../../helpers/fake_uuid_generator.dart';
import '../../../../helpers/recording_logger.dart';
import '../../../../helpers/results.dart';

const int _page = TransactionListBloc.pageSize;

void main() {
  late FakeTransactionRepository repository;

  setUp(() => getIt.registerSingleton<TransactionRepository>(repository = FakeTransactionRepository()));
  tearDown(getIt.reset);

  group('TransactionListState', () {
    test('starts with nothing watched and nothing to show', () {
      final bloc = _fresh();

      expect(bloc.state, const TransactionListInitState());
      expect(bloc.state.query, isNull);
      expect(bloc.state.hasMore, isFalse);
    });

    test('with rows on screen, hasMore is the window having come back full', () {
      final query = TransactionQuery(limit: _page);

      expect(TransactionListLoadedState(query, _snapshotOf(limit: _page, rows: _page)).hasMore, isTrue);
      expect(TransactionListLoadedState(query, _snapshotOf(limit: _page, rows: 3)).hasMore, isFalse);
    });

    group('equality', () {
      test('is by value: the same filter in another order, fresh instances of the same rows', () {
        expect(_errorState(), _errorState(accountIds: {'acc-bank', 'acc-cash'}));
        expect(_errorState().hashCode, _errorState(accountIds: {'acc-bank', 'acc-cash'}).hashCode);
      });

      test('differs when the query, the rows or the failure differs', () {
        expect(_errorState(), isNot(_errorState(accountIds: {'acc-cash'})));
        expect(_errorState(), isNot(_errorState(rows: 3)));
        expect(_errorState(), isNot(_errorState(failure: const GPNotFoundFailure())));
        expect(_errorState(), isNot(TransactionListLoadedState(TransactionQuery(accountIds: const {'acc-cash', 'acc-bank'}, limit: _page), _snapshotOf(limit: _page, rows: 2))));
      });
    });

    test('prints ids and counts, never an amount or a note (golden rule 9)', () {
      final printed = TransactionListLoadedState(TransactionQuery(limit: _page), _snapshotOf(limit: _page, rows: 2)).toString();

      expect(printed, isNot(contains('Phở')));
      expect(printed, isNot(contains('125000')));
    });
  });

  group('starting', () {
    test('watches every transaction, newest first, one page deep, as soon as it is built', () async {
      final bloc = _fresh();

      expect(await _statesDuring(bloc, () {}), [TransactionListLoadingState(TransactionQuery(limit: _page), null)]);
      expect(repository.watches.single.query, TransactionQuery(limit: _page));
    });
  });

  group('TransactionListFilterChangeEvent', () {
    test('sent right after the bloc is built, applies once the first page has started', () async {
      final bloc = _fresh();

      final states = await _statesAfter([
        const TransactionListFilterChangeEvent(types: {TransactionType.income}),
      ], bloc);

      expect(states, [
        TransactionListLoadingState(TransactionQuery(limit: _page), null),
        TransactionListLoadingState(TransactionQuery(types: const {TransactionType.income}, limit: _page), null),
      ]);
    });

    test('starts the new filter over at one page, with neither the rows nor the failure of the old one', () async {
      final bloc = await _started();
      await _statesAfter([
        const TransactionListFilterChangeEvent(types: {TransactionType.expense}),
      ], bloc);
      await _statesDuring(bloc, () => repository.watches.last.emit(_snapshotOf(limit: _page, rows: _page)));
      await _statesAfter([const TransactionListLoadMoreEvent()], bloc);
      await _statesDuring(bloc, () => repository.watches.last.emit(_snapshotOf(limit: 2 * _page, rows: 2 * _page)));
      await _statesDuring(bloc, () => repository.watches.last.fail(const GPDatabaseFailure()));
      expect(bloc.state, isA<TransactionListLoadErrorState>());

      final states = await _statesAfter([
        const TransactionListFilterChangeEvent(types: {TransactionType.income}),
      ], bloc);

      expect(states, [
        TransactionListLoadingState(TransactionQuery(types: const {TransactionType.income}, limit: _page), null),
      ]);
    });

    test('replaces the whole filter rather than patching the old one', () async {
      final bloc = await _started();
      await _statesAfter([
        const TransactionListFilterChangeEvent(accountIds: {'acc-cash'}, types: {TransactionType.expense}),
      ], bloc);

      final states = await _statesAfter([
        const TransactionListFilterChangeEvent(types: {TransactionType.expense}),
      ], bloc);

      expect(states, [
        TransactionListLoadingState(TransactionQuery(types: const {TransactionType.expense}, limit: _page), null),
      ]);
    });

    test('the filter it already has changes nothing: not the window, not the rows', () async {
      final from = DateTime.utc(2026, 9, 30, 17);
      final to = DateTime.utc(2026, 10, 31, 17);
      final bloc = await _started();
      await _statesAfter([
        TransactionListFilterChangeEvent(accountIds: const {'acc-cash', 'acc-bank'}, from: from, to: to),
      ], bloc);
      await _statesDuring(bloc, () => repository.watches.last.emit(_snapshotOf(limit: _page, rows: _page)));
      await _statesAfter([const TransactionListLoadMoreEvent()], bloc);
      await _statesDuring(bloc, () => repository.watches.last.emit(_snapshotOf(limit: 2 * _page, rows: 2 * _page)));

      // Another set order, and an empty set — which `TransactionQuery` reads as no filter, like null: still the filter in force.
      final states = await _statesAfter([
        TransactionListFilterChangeEvent(accountIds: const {'acc-bank', 'acc-cash'}, categoryIds: const {}, from: from, to: to),
      ], bloc);

      expect(states, isEmpty);
      expect(bloc.state.query?.limit, 2 * _page);
    });

    test('a range that ends before it starts is a bug, and it is not swallowed', () async {
      final errors = <Object>[];
      // A handler's error is rethrown into the zone the bloc was created in.
      final bloc = runZonedGuarded(TransactionListBloc.new, (error, _) => errors.add(error))!;
      addTearDown(bloc.close);

      final states = await _statesAfter([
        TransactionListFilterChangeEvent(from: DateTime.utc(2026, 10, 5), to: DateTime.utc(2026, 10, 4)),
      ], bloc);

      expect(errors, [isA<ArgumentError>()]);
      expect(states, [TransactionListLoadingState(TransactionQuery(limit: _page), null)]);
    });
  });

  group('TransactionListLoadMoreEvent', () {
    test('grows a full window by one page, keeping its filter and its rows on screen meanwhile', () async {
      final rows = _snapshotOf(limit: _page, rows: _page);
      final bloc = await _started();
      await _statesAfter([
        const TransactionListFilterChangeEvent(types: {TransactionType.expense}),
      ], bloc);
      await _statesDuring(bloc, () => repository.watches.last.emit(rows));

      final states = await _statesAfter([const TransactionListLoadMoreEvent()], bloc);

      expect(states, [
        TransactionListLoadingState(TransactionQuery(types: const {TransactionType.expense}, limit: 2 * _page), rows),
      ]);
    });

    test('asks once, however often a scroll listener sends it', () async {
      final bloc = await _loaded(repository, _snapshotOf(limit: _page, rows: _page));

      final states = await _statesAfter(List.filled(5, const TransactionListLoadMoreEvent()), bloc);

      expect(states, hasLength(1));
      expect(states.single.query?.limit, 2 * _page);
    });

    test('counts the rows it could not read toward the window', () async {
      // 48 mapped + 2 unreadable fill the window; counting the mapped rows alone would ask for 98.
      final bloc = await _loaded(repository, _snapshotOf(limit: _page, rows: _page - 2, unreadable: 2));

      final states = await _statesAfter([const TransactionListLoadMoreEvent()], bloc);

      expect(states.single.query?.limit, 2 * _page);
    });

    test('is ignored when the window came back short: the list has ended', () async {
      final bloc = await _loaded(repository, _snapshotOf(limit: _page, rows: _page - 1));

      expect(await _statesAfter([const TransactionListLoadMoreEvent()], bloc), isEmpty);
    });

    test('is ignored before the first rows arrive', () async {
      final bloc = await _started();

      expect(await _statesAfter([const TransactionListLoadMoreEvent()], bloc), isEmpty);
    });

    test('drops the failure, which belonged to the watch the larger window replaces', () async {
      final rows = _snapshotOf(limit: _page, rows: _page);
      final bloc = await _loaded(repository, rows);
      await _statesDuring(bloc, () => repository.watches.single.fail(const GPDatabaseFailure()));

      final states = await _statesAfter([const TransactionListLoadMoreEvent()], bloc);

      expect(states, [TransactionListLoadingState(TransactionQuery(limit: 2 * _page), rows)]);
    });

    test('does not grow past a larger window whose watch failed', () async {
      final rows = _snapshotOf(limit: _page, rows: _page);
      final bloc = await _loaded(repository, rows);
      await _statesAfter([const TransactionListLoadMoreEvent()], bloc);
      await _statesDuring(bloc, () => repository.watches.last.fail(const GPDatabaseFailure()));
      expect(bloc.state, TransactionListLoadErrorState(TransactionQuery(limit: 2 * _page), rows, const GPDatabaseFailure()));

      expect(await _statesAfter([const TransactionListLoadMoreEvent()], bloc), isEmpty);
    });
  });

  group('watching', () {
    test('the first page opens one watch, and what it emits is what the list shows', () async {
      final bloc = await _started();
      final rows = _snapshotOf(limit: _page, rows: 3);

      final states = await _statesDuring(bloc, () => repository.watches.single.emit(rows));

      expect(states, [TransactionListLoadedState(TransactionQuery(limit: _page), rows)]);
    });

    test('a failure before any row arrived is the error state, with nothing on screen', () async {
      final bloc = await _started();

      final states = await _statesDuring(bloc, () => repository.watches.single.fail(const GPDatabaseFailure()));

      expect(states, [TransactionListLoadErrorState(TransactionQuery(limit: _page), null, const GPDatabaseFailure())]);
    });

    test('a new filter cancels the old watch before the new one starts', () async {
      final bloc = await _started();

      await _statesAfter([
        const TransactionListFilterChangeEvent(types: {TransactionType.income}),
      ], bloc);

      expect(repository.log, ['listen #0', 'cancel #0', 'listen #1']);
      expect(repository.watches.last.query, TransactionQuery(types: const {TransactionType.income}, limit: _page));
    });

    test('an emission of the old filter that lands after the change never reaches the screen', () async {
      final bloc = await _started();

      final states = await _statesDuring(bloc, () {
        bloc.add(const TransactionListFilterChangeEvent(types: {TransactionType.income}));
        // Delivered after the filter change and before `restartable` cancels the old watch.
        repository.watches.first.emit(_snapshotOf(limit: _page, rows: 3));
      });

      expect(states, [
        TransactionListLoadingState(TransactionQuery(types: const {TransactionType.income}, limit: _page), null),
      ]);
    });

    test('a failure of the old filter that lands after the change never reaches the screen', () async {
      final bloc = await _started();

      final states = await _statesDuring(bloc, () {
        bloc.add(const TransactionListFilterChangeEvent(types: {TransactionType.income}));
        repository.watches.first.fail(const GPDatabaseFailure());
      });

      expect(states, [
        TransactionListLoadingState(TransactionQuery(types: const {TransactionType.income}, limit: _page), null),
      ]);
    });

    test('a filter change while a larger window loads drops both the old rows and that window', () async {
      final bloc = await _loaded(repository, _snapshotOf(limit: _page, rows: _page));
      await _statesAfter([const TransactionListLoadMoreEvent()], bloc);

      await _statesAfter([
        const TransactionListFilterChangeEvent(types: {TransactionType.income}),
      ], bloc);

      expect(bloc.state, TransactionListLoadingState(TransactionQuery(types: const {TransactionType.income}, limit: _page), null));
      expect(repository.log, ['listen #0', 'cancel #0', 'listen #1', 'cancel #1', 'listen #2']);
    });

    test('load more keeps the rows on screen until the larger window answers on its own watch', () async {
      final firstPage = _snapshotOf(limit: _page, rows: _page);
      final bloc = await _loaded(repository, firstPage);

      await _statesAfter([const TransactionListLoadMoreEvent()], bloc);

      expect(bloc.state, TransactionListLoadingState(TransactionQuery(limit: 2 * _page), firstPage));
      expect(repository.log, ['listen #0', 'cancel #0', 'listen #1']);
      expect(repository.watches.last.query.limit, 2 * _page);

      final twoPages = _snapshotOf(limit: 2 * _page, rows: 2 * _page);
      await _statesDuring(bloc, () => repository.watches.last.emit(twoPages));

      expect(bloc.state, TransactionListLoadedState(TransactionQuery(limit: 2 * _page), twoPages));
    });

    test('five load-more requests open one more watch, not five', () async {
      final bloc = await _loaded(repository, _snapshotOf(limit: _page, rows: _page));

      await _statesAfter(List.filled(5, const TransactionListLoadMoreEvent()), bloc);

      expect(repository.watches, hasLength(2));
    });

    test('a failure keeps the rows, and the next emission of the same watch clears it', () async {
      final rows = _snapshotOf(limit: _page, rows: 3);
      final bloc = await _loaded(repository, rows);
      final watch = repository.watches.single;

      await _statesDuring(bloc, () => watch.fail(const GPDatabaseFailure()));

      expect(bloc.state, TransactionListLoadErrorState(TransactionQuery(limit: _page), rows, const GPDatabaseFailure()));

      await _statesDuring(bloc, () => watch.emit(rows));

      expect(bloc.state, TransactionListLoadedState(TransactionQuery(limit: _page), rows));
      expect(watch.isListened, isTrue);
    });

    test('an error that is not a GPFailure is a bug, and it is not swallowed', () async {
      final errors = <Object>[];
      final bloc = runZonedGuarded(TransactionListBloc.new, (error, _) => errors.add(error))!;
      addTearDown(bloc.close);
      await pumpEventQueue();

      final states = await _statesDuring(bloc, () => repository.watches.single.fail(StateError('bug')));

      expect(errors, [isA<StateError>()]);
      expect(states, isEmpty);
    });

    test('close cancels the running watch', () async {
      final bloc = TransactionListBloc();
      await pumpEventQueue();

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
        clock: clock,
        dao: TransactionDao(db),
        logger: RecordingLogger(clock),
        uuidGenerator: FakeUuidGenerator(),
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
      await getIt.unregister<TransactionRepository>();
      getIt.registerSingleton<TransactionRepository>(transactions);

      final bloc = _fresh();
      await expectLater(bloc.stream, emitsThrough(predicate<TransactionListState>((state) => state.snapshot?.transactions.isEmpty ?? false)));

      final updated = expectLater(bloc.stream, emitsThrough(predicate<TransactionListState>((state) => state.snapshot?.transactions.length == 1)));
      final created = await transactions.createTransaction(
        amount: Money(45000, 'VND'),
        type: TransactionType.expense,
        occurredAt: DateTime.utc(2026, 10, 6, 8),
        accountId: 'acc-cash',
      );

      expect(created, isA<GPOk<TransactionEntity>>());
      await updated;
    });
  });
}

TransactionListState _errorState({Set<String> accountIds = const {'acc-cash', 'acc-bank'}, GPFailure failure = const GPDatabaseFailure(), int rows = 2}) =>
    TransactionListLoadErrorState(TransactionQuery(accountIds: accountIds, limit: _page), _snapshotOf(limit: _page, rows: rows), failure);

TransactionEntity _transaction(int n) => okValue(
  TransactionEntity.create(
    amount: Money(125000, 'VND'),
    type: TransactionType.expense,
    createdAt: DateTime.utc(2026, 10, 4, 6),
    occurredAt: DateTime.utc(2026, 10, 4, 5, 30),
    updatedAt: DateTime.utc(2026, 10, 4, 6),
    accountId: 'acc-cash',
    id: 'tx-$n',
    note: 'Phở bò',
  ),
);

/// `hasMore` exactly as the repository sets it, so every state a test reaches is one it can produce.
TransactionListSnapshot _snapshotOf({required int limit, required int rows, int unreadable = 0}) {
  assert(rows + unreadable <= limit, 'a window never returns more rows than its limit');

  return TransactionListSnapshot(transactions: [for (var i = 0; i < rows; i++) _transaction(i)], unreadableCount: unreadable, hasMore: rows + unreadable == limit);
}

TransactionListBloc _fresh() {
  final bloc = TransactionListBloc();
  addTearDown(bloc.close);
  return bloc;
}

/// The first page is watched and has not answered yet.
Future<TransactionListBloc> _started() async {
  final bloc = _fresh();
  await pumpEventQueue();
  return bloc;
}

/// The first page has answered with [snapshot].
Future<TransactionListBloc> _loaded(FakeTransactionRepository repository, TransactionListSnapshot snapshot) async {
  final bloc = await _started();
  await _statesDuring(bloc, () => repository.watches.single.emit(snapshot));
  return bloc;
}

Future<List<TransactionListState>> _statesDuring(TransactionListBloc bloc, void Function() act) async {
  final states = <TransactionListState>[];
  final subscription = bloc.stream.listen(states.add);

  act.call();
  await pumpEventQueue();

  await subscription.cancel();
  return states;
}

Future<List<TransactionListState>> _statesAfter(List<TransactionListEvent> events, TransactionListBloc bloc) => _statesDuring(bloc, () => events.forEach(bloc.add));
