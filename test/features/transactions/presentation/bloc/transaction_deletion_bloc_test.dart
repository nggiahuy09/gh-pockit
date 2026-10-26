import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_deletion_bloc.dart';

import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/results.dart';

late InMemoryRepositories _repositories;

void main() {
  setUp(() {
    _repositories = InMemoryRepositories();
    getIt.registerSingleton<TransactionRepository>(_repositories.transactions);
  });

  tearDown(() async {
    await getIt.reset();
    await _repositories.close();
  });

  test('delete writes at once, and restore brings the same transaction back', () async {
    final (_, transaction) = await _seed();
    final deletion = _bloc()..add(TransactionDeletionDeleteEvent(transaction.id));

    await expectLater(deletion.stream, emitsInOrder([const TransactionDeletionDeleteLoadingState(), TransactionDeletionDeletedState(transaction.id)]));
    expect(await _listed(), isEmpty);

    deletion.add(TransactionDeletionRestoreEvent(transaction.id));

    await expectLater(deletion.stream, emitsInOrder([const TransactionDeletionRestoreLoadingState(), const TransactionDeletionRestoredState()]));
    expect((await _listed()).single.id, transaction.id);
  });

  test('offering the undo for a delete written elsewhere writes nothing', () async {
    final (_, transaction) = await _seed();
    final deletion = _bloc()..add(TransactionDeletionUndoOfferEvent(transaction.id));

    await expectLater(deletion.stream, emits(TransactionDeletionDeletedState(transaction.id)));
    expect((await _listed()).single.id, transaction.id);
  });

  test('a restore refused because the account went meanwhile is reported, and the transaction stays deleted', () async {
    final (account, transaction) = await _seed();
    final deletion = _bloc()..add(TransactionDeletionDeleteEvent(transaction.id));
    await deletion.stream.firstWhere((state) => state is TransactionDeletionDeletedState);
    await _repositories.accounts.deleteAccount(account.id);

    deletion.add(TransactionDeletionRestoreEvent(transaction.id));

    await expectLater(deletion.stream, emitsThrough(const TransactionDeletionRestoreErrorState(GPNotFoundFailure())));
    expect(await _listed(), isEmpty);
  });

  test('a delete of a transaction already gone is reported as not found', () async {
    final deletion = _bloc()..add(const TransactionDeletionDeleteEvent('tx-missing'));

    await expectLater(deletion.stream, emitsThrough(const TransactionDeletionDeleteErrorState(GPNotFoundFailure())));
  });

  test('the same failure twice is emitted twice: the loading state sits between them', () async {
    final deletion = _bloc()
      ..add(const TransactionDeletionDeleteEvent('tx-missing'))
      ..add(const TransactionDeletionDeleteEvent('tx-missing'));

    await expectLater(
      deletion.stream,
      emitsInOrder([
        const TransactionDeletionDeleteLoadingState(),
        const TransactionDeletionDeleteErrorState(GPNotFoundFailure()),
        const TransactionDeletionDeleteLoadingState(),
        const TransactionDeletionDeleteErrorState(GPNotFoundFailure()),
      ]),
    );
  });
}

TransactionDeletionBloc _bloc() {
  final created = TransactionDeletionBloc();
  addTearDown(created.close);
  return created;
}

Future<(AccountEntity, TransactionEntity)> _seed() async {
  final account = okValue(await _repositories.accounts.createAccount(initialBalance: Money(0, 'VND'), type: AccountType.cash, name: 'Ví'));
  final transaction = okValue(
    await _repositories.transactions.createTransaction(amount: Money(45000, 'VND'), type: TransactionType.expense, occurredAt: DateTime.utc(2026, 10, 13), accountId: account.id),
  );
  return (account, transaction);
}

Future<List<TransactionEntity>> _listed() async => (await _repositories.transactions.watchTransactions(TransactionQuery(limit: 10)).first).transactions;
