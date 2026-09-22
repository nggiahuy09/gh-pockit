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

/// The offline-first half of [CategoryRepository] (W3 T6).
///
/// Same division of labour as `AccountRepositoryImpl`, and it is worth stating once more only because this is the second time it holds: the DAO has no
/// clock, no id generator and no owner, and this class supplies all three so exactly one layer decides the id (`v7`, golden rule 4), the instant (one read
/// of `GPClock` per operation), the owner, and what zero rows written means.
///
/// **One thing is genuinely new: two writers.** Accounts are only ever written by a user action; categories are also written by `CategorySeeder` at every
/// launch. Nothing here has to coordinate with it — the seeder's ids are derived and its insert is `INSERT OR IGNORE`, so the two writers cannot produce the
/// same row twice — but it is why [createCategory] mints a `v7` and never a `v5`: a category the user invented has nothing to derive an id from, and
/// borrowing the seeder's scheme would let two different user-made categories with the same name collide.
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
                    // **The whole list fails rather than the bad row being skipped** — the same policy W2 T6 chose for accounts, and for the same reason at
                    // the same scale: a picker quietly missing one category is worse than a screen that says it could not read local data, and golden rule 1
                    // leaves no remote copy to reconcile against.
                    //
                    // It is a *re*-decision rather than a copy, because the policy is scale-dependent and ROADMAP W4 T6 says so out loud: at 50k
                    // transactions the same rule hides a year of history. Tens of categories is the accounts case, not the transactions one.
                    _logRejectedRow(row.id, reason);
                    sink.addError(failure);
                    return;
                }
              }

              sink.add(entities);
            },
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
          ),
        );
  }

  @override
  Future<GPResult<CategoryEntity>> createCategory({required String name, required CategoryType type, String? iconKey, String? colorKey}) async {
    final now = _clock.nowUtc();

    // No `nameKey` and `isSystem` left at its default of false: a category created through this interface is user-made by definition, and the absence of a
    // parameter is what guarantees it rather than a check somewhere.
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
    // No validation branch: a `CategoryEntity` cannot exist unvalidated, so a blank rename has already been refused by `update` and shown under the field.
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

        // Zero rows is three situations the guarded UPDATE cannot tell apart, so this asks — inside the transaction, or a concurrent delete would make it
        // report a conflict against a row that is already gone. `findById` is the one read that sees tombstones, which is what distinguishes "deleted" from
        // "never existed".
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
      // Unguarded by version: deleting is terminal and idempotent, so there is no merge to lose and refusing because a rename landed first would only make
      // the user press delete twice. Zero rows therefore means one thing — no live row with that id.
      final written = await _dao.softDelete(id, now: _clock.nowEpochMillis());

      if (written == 0) return const GPErr<void>(GPNotFoundFailure());

      return const GPOk<void>(null);
    } on Exception catch (error, stackTrace) {
      return _databaseFailure<void>('category delete failed', id, error, stackTrace);
    }
  }

  /// An id, an entity type and a reason code — the three things golden rule 9 allows. The row's name is in scope at both call sites and is not logged.
  void _logRejectedRow(String id, CategoryMapperReason reason) =>
      _logger.error('category row could not be mapped', fields: {'entity': 'category', 'id': id, 'reason': reason.name});

  /// `on Exception`, never `on Object`: an `Error` is a bug in this code and must not be dressed up as "could not read local data" (ADR-0006).
  GPResult<T> _databaseFailure<T>(String message, String id, Object error, StackTrace stackTrace) {
    _logger.error(message, fields: {'entity': 'category', 'id': id}, error: error, stackTrace: stackTrace);

    return GPErr<T>(const GPDatabaseFailure());
  }
}
