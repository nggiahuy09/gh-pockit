import 'dart:async';

import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/core/utils/uuid_generator.dart';
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';
import 'package:ghpockit/features/categories/data/mapper/category_mapper.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  const CategoryRepositoryImpl({
    required CategoryDao dao,
    required GPClock clock,
    required GPUuidGenerator uuidGenerator,
    required GPAppLogger logger,
    required String ownerId,
    CategoryMapper mapper = const CategoryMapper(),
  }) : _dao = dao,
       _clock = clock,
       _uuidGenerator = uuidGenerator,
       _logger = logger,
       _ownerId = ownerId,
       _mapper = mapper;

  final CategoryDao _dao;
  final GPClock _clock;
  final GPUuidGenerator _uuidGenerator;
  final GPAppLogger _logger;
  final CategoryMapper _mapper;

  /// `localOwnerId` today; the signed-in uid from W10.
  final String _ownerId;

  @override
  Stream<List<CategoryEntity>> watchCategories({CategoryType? type}) {
    return _dao
        .watchCategories(_ownerId, type: type?.storageValue)
        .transform(
          StreamTransformer<List<CategoryRow>, List<CategoryEntity>>.fromHandlers(
            handleData: (rows, sink) {
              final entities = <CategoryEntity>[];

              for (final row in rows) {
                switch (_mapper.toEntity(row)) {
                  case MappedCategory(:final category):
                    entities.add(category);
                  case UnmappableCategoryRow(:final reason, :final failure):
                    // One bad row fails the whole list, unlike transactions (ADR-0006, ADR-0011): a picker silently missing a category is worse.
                    _logRejectedRow(row.id, reason);
                    sink.addError(failure);
                    return;
                }
              }

              sink.add(entities);
            },
            handleError: (error, stackTrace, sink) => _reportQueryError('category list read failed', error, stackTrace, sink),
          ),
        );
  }

  @override
  Stream<CategoryEntity?> watchCategory(String id) {
    return _dao
        .watchCategory(_ownerId, id)
        .transform(
          StreamTransformer<CategoryRow?, CategoryEntity?>.fromHandlers(
            handleData: (row, sink) {
              if (row == null) {
                sink.add(null);
                return;
              }

              switch (_mapper.toEntity(row)) {
                case MappedCategory(:final category):
                  sink.add(category);
                case UnmappableCategoryRow(:final reason, :final failure):
                  _logRejectedRow(row.id, reason);
                  sink.addError(failure);
              }
            },
            handleError: (error, stackTrace, sink) => _reportQueryError('category read failed', error, stackTrace, sink, id: id),
          ),
        );
  }

  @override
  Future<GPResult<CategoryEntity>> createCategory({required String name, required CategoryType type, String? iconKey, String? colorKey}) async {
    final now = _clock.nowUtc();
    final created = CategoryEntity.create(id: _uuidGenerator.v7(), name: name, type: type, iconKey: iconKey, colorKey: colorKey, createdAt: now, updatedAt: now);

    switch (created) {
      case GPErr<CategoryEntity>():
        return created;
      case GPOk<CategoryEntity>(:final value):
        try {
          await _dao.insertCategory(_mapper.toInsert(value, ownerId: _ownerId));

          return GPOk<CategoryEntity>(value);
        } on Exception catch (error, stackTrace) {
          return _databaseFailure<CategoryEntity>('category insert failed', value.id, error, stackTrace);
        }
    }
  }

  @override
  Future<GPResult<CategoryEntity>> updateCategory(CategoryEntity category) async {
    final now = _clock.nowUtc();
    // No validation branch: a `CategoryEntity` is valid by construction.
    final stamped = category.stampedAt(now);

    try {
      return await _dao.transaction(() async {
        final written = await _dao.updateCategory(
          stamped.id,
          baseVersion: category.version,
          patch: _mapper.toPatch(stamped),
          now: now.millisecondsSinceEpoch,
        );

        if (written == 1) return GPOk<CategoryEntity>(stamped);

        // Zero rows: missing, deleted or stale. Asked inside the transaction so a concurrent delete cannot pass for a conflict.
        final current = await _dao.findById(stamped.id);

        if (current == null || current.deletedAt != null) return const GPErr<CategoryEntity>(GPNotFoundFailure());

        return GPErr<CategoryEntity>(GPConflictFailure(entityId: stamped.id, localVersion: category.version, remoteVersion: current.version));
      });
    } on Exception catch (error, stackTrace) {
      return _databaseFailure<CategoryEntity>('category update failed', stamped.id, error, stackTrace);
    }
  }

  @override
  Future<GPResult<void>> deleteCategory(String id) async {
    try {
      // Not version-guarded: a delete has nothing to merge, so a rename that landed first must not block it.
      final written = await _dao.softDelete(id, now: _clock.nowEpochMillis());

      if (written == 0) return const GPErr<void>(GPNotFoundFailure());

      return const GPOk<void>(null);
    } on Exception catch (error, stackTrace) {
      return _databaseFailure<void>('category delete failed', id, error, stackTrace);
    }
  }

  /// Id, entity type and reason code only, never the name (golden rule 9).
  void _logRejectedRow(String id, CategoryMapperReason reason) =>
      _logger.error('category row could not be mapped', fields: {'entity': 'category', 'id': id, 'reason': reason.name});

  /// Callers catch `on Exception` only: an `Error` is a bug, not "could not read local data" (ADR-0006).
  GPResult<T> _databaseFailure<T>(String message, String id, Object error, StackTrace stackTrace) {
    _logger.error(message, fields: {'entity': 'category', 'id': id}, error: error, stackTrace: stackTrace);

    return GPErr<T>(const GPDatabaseFailure());
  }

  /// The stream side of [_databaseFailure]: an [Exception] (in the app, a `DriftRemoteException` from the database isolate) is logged and becomes
  /// [GPDatabaseFailure]; anything else is a bug, forwarded unlogged so the crash reporter sees it once.
  void _reportQueryError<T>(String message, Object error, StackTrace stackTrace, EventSink<T> sink, {String? id}) {
    if (error is! Exception) {
      sink.addError(error, stackTrace);
      return;
    }

    _logger.error(message, fields: {'entity': 'category', 'id': ?id}, error: error, stackTrace: stackTrace);
    sink.addError(const GPDatabaseFailure());
  }
}
