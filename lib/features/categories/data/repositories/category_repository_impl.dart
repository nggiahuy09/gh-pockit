import 'dart:async';

import '../../../../core/database/database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/uuid_generator.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/category_type.dart';
import '../../domain/repositories/category_repository.dart';
import '../daos/category_dao.dart';
import '../mapper/category_mapper.dart';

final class CategoryRepositoryImpl implements CategoryRepository {
  const CategoryRepositoryImpl({
    required GPClock clock,
    required CategoryDao dao,
    required GPAppLogger logger,
    required GPUuidGenerator uuidGenerator,
    required String ownerId,
  }) : _clock = clock,
       _dao = dao,
       _logger = logger,
       _uuidGenerator = uuidGenerator,
       _ownerId = ownerId;

  final GPClock _clock;
  final CategoryDao _dao;
  final GPAppLogger _logger;
  final GPUuidGenerator _uuidGenerator;
  final String _ownerId;

  @override
  Stream<List<CategoryEntity>> watchCategories([CategoryType? type]) {
    return _dao
        .watchCategories(ownerId: _ownerId, type: type?.storageValue)
        .transform(
          StreamTransformer<List<CategoryRow>, List<CategoryEntity>>.fromHandlers(
            handleData: (rows, sink) {
              final entities = <CategoryEntity>[];
              for (final row in rows) {
                switch (row.toDomain()) {
                  case MappedCategory(:final category):
                    entities.add(category);
                  case UnmappableCategoryRow(:final reason, :final failure):
                    // One bad row fails the whole list, unlike transactions (ADR-0011): a picker silently missing a category is worse.
                    _logRejectedRow(reason, row.id);
                    sink.addError(failure);
                    return;
                }
              }

              sink.add(entities);
            },
            handleError: (error, stackTrace, sink) => _reportQueryError(error: error, sink: sink, stackTrace: stackTrace, message: 'category list read failed'),
          ),
        );
  }

  @override
  Stream<CategoryEntity?> watchCategory(String id) {
    return _dao
        .watchCategory(id: id, ownerId: _ownerId)
        .transform(
          StreamTransformer<CategoryRow?, CategoryEntity?>.fromHandlers(
            handleData: (row, sink) {
              if (row == null) {
                sink.add(null);
                return;
              }

              switch (row.toDomain()) {
                case MappedCategory(:final category):
                  sink.add(category);
                case UnmappableCategoryRow(:final reason, :final failure):
                  _logRejectedRow(reason, row.id);
                  sink.addError(failure);
              }
            },
            handleError: (error, stackTrace, sink) => _reportQueryError(error: error, sink: sink, stackTrace: stackTrace, id: id, message: 'category read failed'),
          ),
        );
  }

  @override
  Future<GPResult<CategoryEntity>> createCategory({required CategoryType type, String? colorKey, String? iconKey, required String name}) async {
    final now = _clock.nowUtc();
    final created = CategoryEntity.create(type: type, createdAt: now, updatedAt: now, colorKey: colorKey, iconKey: iconKey, id: _uuidGenerator.v7(), name: name);

    switch (created) {
      case GPErr():
        return created;
      case GPOk(:final value):
        try {
          await _dao.insertCategory(value.toInsert(_ownerId));
          return GPOk(value);
        } on Exception catch (error, stackTrace) {
          return _databaseFailure(error: error, stackTrace: stackTrace, id: value.id, message: 'category insert failed');
        }
    }
  }

  @override
  Future<GPResult<CategoryEntity>> updateCategory(CategoryEntity category) async {
    final now = _clock.nowUtc();
    final stamped = category.withUpdatedAt(now);

    try {
      return await _dao.transaction(() async {
        final written = await _dao.updateCategory(stamped.id, patch: stamped.toPatch(), baseVersion: category.version, now: now.millisecondsSinceEpoch);
        if (written == 1) return GPOk(stamped);

        // Zero rows: missing, deleted or stale. Asked inside the transaction so a concurrent delete cannot pass for a conflict.
        final current = await _dao.findById(stamped.id);
        if (current == null || current.deletedAt != null) return const GPErr(GPNotFoundFailure());

        return GPErr(GPConflictFailure(entityId: stamped.id, localVersion: category.version, remoteVersion: current.version));
      });
    } on Exception catch (error, stackTrace) {
      return _databaseFailure(error: error, stackTrace: stackTrace, id: stamped.id, message: 'category update failed');
    }
  }

  @override
  Future<GPResult<void>> deleteCategory(String id) async {
    try {
      // Not version-guarded: a delete has nothing to merge, so a rename that landed first must not block it.
      final written = await _dao.softDelete(id, now: _clock.nowEpochMillis());
      if (written == 0) return const GPErr(GPNotFoundFailure());

      return const GPOk(null);
    } on Exception catch (error, stackTrace) {
      return _databaseFailure(error: error, stackTrace: stackTrace, id: id, message: 'category delete failed');
    }
  }

  void _logRejectedRow(CategoryMapperReason reason, String id) =>
      _logger.error('category row could not be mapped', fields: {'entity': 'category', 'id': id, 'reason': reason.name});

  /// For `on Exception` catches only: an `Error` is a bug, not "could not read local data" (ADR-0006).
  GPResult<T> _databaseFailure<T>({required Object error, required StackTrace stackTrace, required String id, required String message}) {
    _logger.error(message, fields: {'entity': 'category', 'id': id}, error: error, stackTrace: stackTrace);

    return GPErr<T>(const GPDatabaseFailure());
  }

  /// Anything but an [Exception] is a bug, forwarded unlogged so the crash reporter sees it once.
  void _reportQueryError<T>({required Object error, required EventSink<T> sink, required StackTrace stackTrace, String? id, required String message}) {
    if (error is! Exception) {
      sink.addError(error, stackTrace);
      return;
    }

    _logger.error(message, fields: {'entity': 'category', 'id': ?id}, error: error, stackTrace: stackTrace);
    sink.addError(const GPDatabaseFailure());
  }
}
