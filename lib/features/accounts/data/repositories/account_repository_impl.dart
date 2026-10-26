import 'dart:async';

import '../../../../core/database/database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/uuid_generator.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/entities/account_type.dart';
import '../../domain/repositories/account_repository.dart';
import '../daos/account_dao.dart';
import '../mapper/account_mapper.dart';

final class AccountRepositoryImpl implements AccountRepository {
  const AccountRepositoryImpl({
    required GPClock clock,
    required AccountDao dao,
    required GPAppLogger logger,
    required GPUuidGenerator uuidGenerator,
    required String ownerId,
  }) : _clock = clock,
       _dao = dao,
       _logger = logger,
       _uuidGenerator = uuidGenerator,
       _ownerId = ownerId;

  final GPClock _clock;
  final AccountDao _dao;
  final GPAppLogger _logger;
  final GPUuidGenerator _uuidGenerator;
  final String _ownerId;

  @override
  Stream<List<AccountEntity>> watchAccounts([bool includeArchived = false]) {
    return _dao
        .watchAccounts(_ownerId, includeArchived: includeArchived)
        .transform(
          StreamTransformer<List<AccountRow>, List<AccountEntity>>.fromHandlers(
            handleData: (rows, sink) {
              final entities = <AccountEntity>[];
              for (final row in rows) {
                switch (row.toDomain()) {
                  case MappedAccount(:final account):
                    entities.add(account);
                  case UnmappableAccountRow(:final reason, :final failure):
                    // The whole list fails rather than silently dropping an account; transactions decide differently (ADR-0011).
                    _logRejectedRow(reason, row.id);
                    sink.addError(failure);
                    return;
                }
              }

              sink.add(entities);
            },
            handleError: (error, stackTrace, sink) => _reportQueryError(error: error, sink: sink, stackTrace: stackTrace, message: 'account list read failed'),
          ),
        );
  }

  @override
  Stream<AccountEntity?> watchAccount(String id) {
    return _dao
        .watchAccount(id: id, ownerId: _ownerId)
        .transform(
          StreamTransformer<AccountRow?, AccountEntity?>.fromHandlers(
            handleData: (row, sink) {
              if (row == null) {
                sink.add(null);
                return;
              }

              switch (row.toDomain()) {
                case MappedAccount(:final account):
                  sink.add(account);
                case UnmappableAccountRow(:final reason, :final failure):
                  _logRejectedRow(reason, row.id);
                  sink.addError(failure);
              }
            },
            handleError: (error, stackTrace, sink) => _reportQueryError(error: error, sink: sink, stackTrace: stackTrace, id: id, message: 'account read failed'),
          ),
        );
  }

  @override
  Future<GPResult<AccountEntity>> createAccount({required Money initialBalance, required AccountType type, required String name}) async {
    final now = _clock.nowUtc();
    final created = AccountEntity.create(initialBalance: initialBalance, type: type, createdAt: now, updatedAt: now, id: _uuidGenerator.v7(), name: name);

    switch (created) {
      case GPErr():
        return created;
      case GPOk(:final value):
        try {
          await _dao.insertAccount(value.toInsert(_ownerId));
          return GPOk(value);
        } on Exception catch (error, stackTrace) {
          return _databaseFailure(error: error, stackTrace: stackTrace, id: value.id, message: 'account insert failed');
        }
    }
  }

  @override
  Future<GPResult<AccountEntity>> updateAccount(AccountEntity account) async {
    final now = _clock.nowUtc();
    final stamped = account.withUpdatedAt(now);

    try {
      return await _dao.transaction(() async {
        final written = await _dao.updateAccount(stamped.id, patch: stamped.toPatch(), baseVersion: account.version, now: now.millisecondsSinceEpoch);
        if (written == 1) return GPOk(stamped);

        // Zero rows: a conflict, or no live row. Re-read inside the transaction, so a delete cannot land between the write and the lookup.
        final current = await _dao.findById(stamped.id);
        if (current == null || current.deletedAt != null) return const GPErr(GPNotFoundFailure());

        return GPErr(GPConflictFailure(entityId: stamped.id, localVersion: account.version, remoteVersion: current.version));
      });
    } on Exception catch (error, stackTrace) {
      return _databaseFailure(error: error, stackTrace: stackTrace, id: stamped.id, message: 'account update failed');
    }
  }

  @override
  Future<GPResult<void>> archiveAccount(String id) => _write(
    failureMessage: 'account archive failed',
    id: id,
    write: (now) => _dao.archive(id, now: now),
  );

  @override
  Future<GPResult<void>> unarchiveAccount(String id) => _write(
    failureMessage: 'account unarchive failed',
    id: id,
    write: (now) => _dao.unarchive(id, now: now),
  );

  @override
  Future<GPResult<void>> deleteAccount(String id) => _write(
    failureMessage: 'account delete failed',
    id: id,
    write: (now) => _dao.softDelete(id, now: now),
  );

  /// Unguarded writes: zero rows can only mean no live row.
  Future<GPResult<void>> _write({required String failureMessage, required String id, required Future<int> Function(int now) write}) async {
    try {
      final written = await write.call(_clock.nowEpochMillis());
      if (written == 0) return const GPErr(GPNotFoundFailure());

      return const GPOk(null);
    } on Exception catch (error, stackTrace) {
      return _databaseFailure(error: error, stackTrace: stackTrace, id: id, message: failureMessage);
    }
  }

  void _logRejectedRow(AccountMapperReason reason, String id) => _logger.error('account row could not be mapped', fields: {'entity': 'account', 'id': id, 'reason': reason.name});

  /// For `on Exception` catches only: an `Error` is a bug and must not be dressed up as a failure (ADR-0006).
  GPResult<T> _databaseFailure<T>({required Object error, required StackTrace stackTrace, required String id, required String message}) {
    _logger.error(message, fields: {'entity': 'account', 'id': id}, error: error, stackTrace: stackTrace);

    return GPErr<T>(const GPDatabaseFailure());
  }

  /// Anything but an [Exception] is a bug, forwarded untouched for the crash reporter. Drift's isolate errors arrive as `DriftRemoteException`.
  void _reportQueryError<T>({required Object error, required EventSink<T> sink, required StackTrace stackTrace, String? id, required String message}) {
    if (error is! Exception) {
      sink.addError(error, stackTrace);
      return;
    }

    _logger.error(message, fields: {'entity': 'account', 'id': ?id}, error: error, stackTrace: stackTrace);
    sink.addError(const GPDatabaseFailure());
  }
}
