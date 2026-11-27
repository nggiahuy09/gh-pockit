import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/sync/drift_sync_queue_repository.dart';
import 'package:ghpockit/core/sync/sync_entity_type.dart';
import 'package:ghpockit/core/sync/sync_mutation.dart';
import 'package:ghpockit/core/sync/sync_mutation_status.dart';
import 'package:ghpockit/core/sync/sync_operation.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/fake_uuid_generator.dart';
import '../../helpers/recording_logger.dart';

final _start = DateTime.utc(2026, 11, 25, 3);

void main() {
  late GPAppDatabase db;
  late FakeClock clock;
  late RecordingLogger logger;
  late GPDriftSyncQueueRepository queue;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    clock = FakeClock(_start);
    logger = RecordingLogger(clock);
    queue = GPDriftSyncQueueRepository(database: db, clock: clock, uuidGenerator: FakeUuidGenerator('m'), logger: logger);
  });

  tearDown(() => db.close());

  Future<List<SyncMutationRow>> rows() => (db.select(db.syncMutationsTable)..orderBy([(t) => OrderingTerm(expression: t.createdAt), (t) => OrderingTerm(expression: t.id)])).get();

  Future<GPSyncMutation> write(String entityId, GPSyncOperation operation, [Map<String, Object?>? payload]) =>
      queue.enqueue(entityType: GPSyncEntityType.transaction, entityId: entityId, operation: operation, payload: payload ?? {'id': entityId});

  group('enqueue', () {
    test('queues a pending mutation, ready now, with a time-ordered id and a random key of its own', () async {
      final queued = await write('tx-1', GPSyncOperation.create, {'id': 'tx-1', 'amount_minor': 125000});

      final row = (await rows()).single;
      expect(row.id, 'm-v7-1');
      expect(row.idempotencyKey, 'm-v4-1');
      expect(row.status, 'pending');
      expect(row.attemptCount, 0);
      expect(row.createdAt, _start.millisecondsSinceEpoch);
      expect(row.nextAttemptAt, _start.millisecondsSinceEpoch);
      expect(row.payloadJson, '{"id":"tx-1","amount_minor":125000}');
      expect(queued.id, row.id);
    });

    test('folds a later write of the same entity into its unsent mutation: one row, the newest payload, its place kept', () async {
      final first = await write('tx-1', GPSyncOperation.create, {'id': 'tx-1', 'note': 'Phở'});
      clock.advance(const Duration(minutes: 5));

      final folded = await write('tx-1', GPSyncOperation.update, {'id': 'tx-1', 'note': 'Phở bò'});

      final row = (await rows()).single;
      expect([row.id, row.idempotencyKey, row.createdAt], [first.id, first.idempotencyKey, _start.millisecondsSinceEpoch]);
      expect(row.operation, 'create', reason: 'the server never had it');
      expect(row.payloadJson, '{"id":"tx-1","note":"Phở bò"}');
      expect(folded, first.coalescedWith(operation: GPSyncOperation.update, payload: {'id': 'tx-1', 'note': 'Phở bò'}));
    });

    test('a delete then a restore fold into one update', () async {
      await write('tx-1', GPSyncOperation.delete);
      await write('tx-1', GPSyncOperation.update);

      expect((await rows()).single.operation, 'update');
    });

    test('never folds into a mutation already sent: the server may hold its key for the old payload', () async {
      final sent = await write('tx-1', GPSyncOperation.update, {'id': 'tx-1', 'note': 'old'});
      await queue.markSending(sent.id);

      await write('tx-1', GPSyncOperation.update, {'id': 'tx-1', 'note': 'new'});

      final all = await rows();
      expect(all, hasLength(2));
      expect(all.first.payloadJson, '{"id":"tx-1","note":"old"}');
      expect(all.last.payloadJson, '{"id":"tx-1","note":"new"}');
      expect(all.last.idempotencyKey, isNot(all.first.idempotencyKey));
    });

    test('never folds into a mutation orphaned mid-push and reset at launch', () async {
      final sent = await write('tx-1', GPSyncOperation.update);
      await queue.markSending(sent.id);
      await queue.resetOrphans();

      await write('tx-1', GPSyncOperation.update);

      expect(await rows(), hasLength(2));
    });

    test('keeps entities apart, by id and by type', () async {
      await write('tx-1', GPSyncOperation.create);
      await write('tx-2', GPSyncOperation.create);
      await queue.enqueue(entityType: GPSyncEntityType.account, entityId: 'tx-1', operation: GPSyncOperation.create, payload: const {'id': 'tx-1'});

      expect(await rows(), hasLength(3));
    });

    test("commits with the caller's transaction and rolls back with it", () async {
      await expectLater(
        db.transaction(() async {
          await db.into(db.syncMetadataTable).insert(SyncMetadataTableCompanion.insert(key: 'probe', value: 'entity write'));
          await write('tx-1', GPSyncOperation.create);
          throw StateError('crash after both writes');
        }),
        throwsStateError,
      );

      expect(await rows(), isEmpty);
      expect(await db.select(db.syncMetadataTable).get(), isEmpty);
    });

    test("a write it refuses rolls the caller's entity write back too", () async {
      await write('tx-1', GPSyncOperation.update);

      await expectLater(
        db.transaction(() async {
          await db.into(db.syncMetadataTable).insert(SyncMetadataTableCompanion.insert(key: 'probe', value: 'entity write'));
          // A create after an update is a caller's bug (ADR-0044).
          await write('tx-1', GPSyncOperation.create);
        }),
        throwsArgumentError,
      );

      expect(await db.select(db.syncMetadataTable).get(), isEmpty);
      expect((await rows()).single.operation, 'update');
    });

    test('sets aside an unsent row it cannot read, marked failed, and queues the write afresh', () async {
      await db.into(db.syncMutationsTable).insert(_raw('bad', operation: 'upsert'));

      final queued = await write('tx-1', GPSyncOperation.update);

      final byId = {for (final row in await rows()) row.id: row};
      expect(byId['bad']!.status, 'failed');
      expect(byId['bad']!.lastErrorCode, GPDriftSyncQueueRepository.unreadableRowCode);
      expect(byId[queued.id]!.status, 'pending');
      expect(logger.last.fields, {'mutation_id': 'bad', 'reason': 'unknownOperation'});
    });

    test('finds the unsent mutation through the partial index, never a scan', () async {
      final plan = await db
          .customSelect('EXPLAIN QUERY PLAN ${GPDriftSyncQueueRepository.unattemptedSql}', variables: [Variable.withString('transaction'), Variable.withString('tx-1')])
          .get();

      expect(plan.map((row) => row.read<String>('detail')), ['SEARCH sync_mutations USING INDEX sync_mutations_unattempted_entity (entity_type=? AND entity_id=?)']);
    });
  });

  group('getReadyMutations', () {
    test('returns pending mutations that are due, in the order they were written, up to the limit', () async {
      final a = await write('tx-a', GPSyncOperation.create);
      clock.advance(const Duration(seconds: 1));
      final b = await write('tx-b', GPSyncOperation.create);
      clock.advance(const Duration(seconds: 1));
      final c = await write('tx-c', GPSyncOperation.create);

      expect((await queue.getReadyMutations()).map((m) => m.id), [a.id, b.id, c.id]);
      expect((await queue.getReadyMutations(limit: 2)).map((m) => m.id), [a.id, b.id]);
    });

    test('leaves out what is in flight, in conflict, failed or not yet due', () async {
      final inFlight = await write('tx-1', GPSyncOperation.create);
      final conflicted = await write('tx-2', GPSyncOperation.create);
      final failed = await write('tx-3', GPSyncOperation.create);
      final waiting = await write('tx-4', GPSyncOperation.create);
      final due = await write('tx-5', GPSyncOperation.create);
      for (final id in [inFlight.id, conflicted.id, failed.id, waiting.id]) {
        await queue.markSending(id);
      }
      await queue.markConflict(conflicted.id, errorCode: 'version_mismatch');
      await queue.markFailed(failed.id, errorCode: 'validation');
      await queue.scheduleRetry(waiting.id, nextAttemptAt: _start.add(const Duration(seconds: 8)), errorCode: 'network');

      expect((await queue.getReadyMutations()).map((m) => m.id), [due.id]);
    });

    test('marks a row it cannot read failed, logs why, and returns the rest', () async {
      await db.into(db.syncMutationsTable).insert(_raw('bad', payloadJson: '{"id":'));
      // Another entity: the unreadable row, failed now, still holds its own entity's later ones.
      final good = await write('tx-2', GPSyncOperation.create);

      expect((await queue.getReadyMutations()).map((m) => m.id), [good.id]);
      expect((await rows()).firstWhere((row) => row.id == 'bad').status, 'failed');
      expect(logger.last.message, 'unreadable sync mutation marked failed');
      expect(logger.last.fields, {'mutation_id': 'bad', 'reason': 'malformedPayload'});
    });

    test("reads the due range off the status index, and each entity's older mutations off the entity index", () async {
      final plan = await db
          .customSelect('EXPLAIN QUERY PLAN ${GPDriftSyncQueueRepository.readySql}', variables: [Variable.withInt(_start.millisecondsSinceEpoch), Variable.withInt(50)])
          .get();

      // The sort runs over the due rows only, a handful: nothing orders them by `created_at` within the range.
      expect(plan.map((row) => row.read<String>('detail')), [
        'SEARCH m USING INDEX sync_mutations_status_next_attempt_at (status=? AND next_attempt_at<?)',
        'CORRELATED SCALAR SUBQUERY 1',
        'SEARCH e USING COVERING INDEX sync_mutations_entity (entity_type=? AND entity_id=? AND rowid<?)',
        'USE TEMP B-TREE FOR ORDER BY',
      ]);
    });

    group('one entity, in order (ADR-0044)', () {
      Future<(GPSyncMutation, GPSyncMutation)> sentThenWrittenAgain() async {
        final first = await write('tx-1', GPSyncOperation.create, {'id': 'tx-1', 'note': 'old'});
        await queue.markSending(first.id);
        await queue.scheduleRetry(first.id, nextAttemptAt: _start.add(const Duration(minutes: 1)), errorCode: 'network');
        final second = await write('tx-1', GPSyncOperation.update, {'id': 'tx-1', 'note': 'new'});
        return (first, second);
      }

      test('holds a later mutation while an earlier one of its entity waits in backoff, then sends them in order', () async {
        final (first, second) = await sentThenWrittenAgain();
        final other = await write('tx-2', GPSyncOperation.create);

        expect((await queue.getReadyMutations()).map((m) => m.id), [other.id], reason: 'another entity is not held');

        clock.advance(const Duration(minutes: 1));
        expect((await queue.getReadyMutations()).map((m) => m.id), [first.id, other.id]);

        await queue.markSending(first.id);
        await queue.complete(first.id);
        // Written in the same millisecond as `other`, and minted before it.
        expect((await queue.getReadyMutations()).map((m) => m.id), [second.id, other.id]);
      });

      test('a failed or conflicted earlier mutation holds the later ones until it is resolved', () async {
        final first = await write('tx-1', GPSyncOperation.create);
        await queue.markSending(first.id);
        await queue.markFailed(first.id, errorCode: 'validation');
        final second = await write('tx-1', GPSyncOperation.update);

        expect(await queue.getReadyMutations(), isEmpty);
        expect(await queue.markSending(second.id), isNull);

        await queue.complete(first.id);
        expect((await queue.getReadyMutations()).single.id, second.id);
      });

      test('markSending refuses a later mutation while an earlier one is queued, even one not yet due', () async {
        final (_, second) = await sentThenWrittenAgain();

        expect(await queue.markSending(second.id), isNull);
        expect((await rows()).map((row) => (row.status, row.attemptCount)), [('pending', 1), ('pending', 0)]);
      });

      test("a clock set back cannot put the later write ahead: the order is the queue's, not the clock's", () async {
        final first = await write('tx-1', GPSyncOperation.create);
        await queue.markSending(first.id);
        await queue.scheduleRetry(first.id, nextAttemptAt: _start, errorCode: 'network');
        clock.rewindForTest(const Duration(hours: 1));
        final second = await write('tx-1', GPSyncOperation.update);
        clock.advance(const Duration(hours: 1));

        expect((await queue.getReadyMutations()).map((m) => m.id), [first.id]);
        expect(await queue.markSending(second.id), isNull);
      });

      test('finds an older mutation of the entity through the entity index', () async {
        final plan = await db.customSelect('EXPLAIN QUERY PLAN ${GPDriftSyncQueueRepository.olderOfEntitySql}', variables: [Variable.withString('m-1')]).get();

        expect(plan.map((row) => row.read<String>('detail')), contains('SEARCH e USING COVERING INDEX sync_mutations_entity (entity_type=? AND entity_id=? AND rowid<?)'));
      });
    });
  });

  group('markSending', () {
    test('counts the attempt and marks it in flight, in the table too', () async {
      final queued = await write('tx-1', GPSyncOperation.create);

      final sent = await queue.markSending(queued.id);

      expect(sent!.status, GPSyncMutationStatus.processing);
      expect(sent.attemptCount, 1);
      final row = (await rows()).single;
      expect([row.status, row.attemptCount], ['processing', 1]);
    });

    test('hands back a write that folded in after the ready list was read, not the older copy', () async {
      await write('tx-1', GPSyncOperation.update, {'id': 'tx-1', 'note': 'old'});
      final stale = (await queue.getReadyMutations()).single;
      await write('tx-1', GPSyncOperation.update, {'id': 'tx-1', 'note': 'new'});

      final sent = await queue.markSending(stale.id);

      expect(sent!.payload, {'id': 'tx-1', 'note': 'new'});
    });

    test('returns null for a mutation gone or no longer pending, and changes nothing', () async {
      final queued = await write('tx-1', GPSyncOperation.create);
      await queue.markSending(queued.id);

      expect(await queue.markSending(queued.id), isNull);
      expect(await queue.markSending('missing'), isNull);
      expect((await rows()).single.attemptCount, 1);
    });

    test('returns null for a row it cannot read, and marks it failed', () async {
      await db.into(db.syncMutationsTable).insert(_raw('bad', status: 'completed'));

      expect(await queue.markSending('bad'), isNull);
      expect((await rows()).single.status, 'failed');
    });
  });

  group('settling a mutation in flight', () {
    late GPSyncMutation sent;

    setUp(() async {
      final queued = await write('tx-1', GPSyncOperation.create);
      sent = (await queue.markSending(queued.id))!;
    });

    test('complete deletes it, and only it', () async {
      final other = await write('tx-2', GPSyncOperation.create);

      await queue.complete(sent.id);

      expect((await rows()).map((row) => row.id), [other.id]);
    });

    test('scheduleRetry puts it back for later without counting the attempt twice', () async {
      await queue.scheduleRetry(sent.id, nextAttemptAt: _start.add(const Duration(seconds: 8)), errorCode: 'network');

      final row = (await rows()).single;
      expect([row.status, row.attemptCount, row.lastErrorCode], ['pending', 1, 'network']);
      expect(await queue.getReadyMutations(), isEmpty);
      clock.advance(const Duration(seconds: 8));
      expect((await queue.getReadyMutations()).single.id, sent.id);
    });

    test('markConflict and markFailed keep it, with the code, out of the ready list', () async {
      final second = (await queue.markSending((await write('tx-2', GPSyncOperation.create)).id))!;

      await queue.markConflict(sent.id, errorCode: 'version_mismatch');
      await queue.markFailed(second.id, errorCode: 'validation');

      final byId = {for (final row in await rows()) row.id: row};
      expect([byId[sent.id]!.status, byId[sent.id]!.lastErrorCode], ['conflict', 'version_mismatch']);
      expect([byId[second.id]!.status, byId[second.id]!.lastErrorCode], ['failed', 'validation']);
      expect(await queue.getReadyMutations(), isEmpty);
    });

    test('an answer for a mutation not in flight is ignored', () async {
      final pending = await write('tx-2', GPSyncOperation.create);

      await queue.scheduleRetry(pending.id, nextAttemptAt: _start.add(const Duration(hours: 1)), errorCode: 'network');
      await queue.markConflict(pending.id, errorCode: 'version_mismatch');
      await queue.markFailed(pending.id, errorCode: 'validation');

      final row = (await rows()).firstWhere((row) => row.id == pending.id);
      expect([row.status, row.nextAttemptAt, row.lastErrorCode], ['pending', _start.millisecondsSinceEpoch, null]);
    });
  });

  group('resetOrphans', () {
    test('puts every mutation in flight back to pending, its attempt still counted, and logs how many', () async {
      for (final id in ['tx-1', 'tx-2']) {
        await queue.markSending((await write(id, GPSyncOperation.create)).id);
      }
      await write('tx-3', GPSyncOperation.create);

      expect(await queue.resetOrphans(), 2);

      expect((await rows()).map((row) => (row.status, row.attemptCount)), [('pending', 1), ('pending', 1), ('pending', 0)]);
      expect(logger.last.fields, {'count': 2});
    });

    test('with nothing in flight changes nothing and logs nothing', () async {
      await write('tx-1', GPSyncOperation.create);

      expect(await queue.resetOrphans(), 0);
      expect(logger.records, isEmpty);
    });
  });

  group('countUnsyncedEntities', () {
    test('counts each entity once, whatever state its mutations are in', () async {
      expect(await queue.countUnsyncedEntities(), 0);

      final sent = await write('tx-1', GPSyncOperation.update);
      await queue.markSending(sent.id);
      await write('tx-1', GPSyncOperation.update);
      final failing = await write('tx-2', GPSyncOperation.create);
      await queue.markSending(failing.id);
      await queue.markFailed(failing.id, errorCode: 'validation');
      await queue.enqueue(entityType: GPSyncEntityType.account, entityId: 'tx-1', operation: GPSyncOperation.create, payload: const {'id': 'tx-1'});

      expect(await queue.countUnsyncedEntities(), 3);
    });
  });
}

SyncMutationsTableCompanion _raw(String id, {String operation = 'update', String status = 'pending', String payloadJson = '{"id":"tx-1"}'}) => SyncMutationsTableCompanion.insert(
  id: id,
  entityType: 'transaction',
  entityId: 'tx-1',
  operation: operation,
  payloadJson: payloadJson,
  idempotencyKey: 'k-$id',
  createdAt: _start.millisecondsSinceEpoch - 1000,
  attemptCount: 0,
  nextAttemptAt: _start.millisecondsSinceEpoch - 1000,
  status: status,
);
