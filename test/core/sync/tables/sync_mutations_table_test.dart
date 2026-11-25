import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';

const _now = 1795000000000; // 2026-11-17 UTC

void main() {
  late GPAppDatabase db;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('stores every column, the error code null until a push fails', () async {
    await db.into(db.syncMutationsTable).insert(_mutation());

    final row = await db.select(db.syncMutationsTable).getSingle();

    expect(row.id, 'm-1');
    expect(row.entityType, 'transaction');
    expect(row.entityId, 'tx-1');
    expect(row.operation, 'upsert');
    expect(row.payloadJson, '{"id":"tx-1"}');
    expect(row.idempotencyKey, 'k-1');
    expect(row.createdAt, _now);
    expect(row.attemptCount, 0);
    expect(row.nextAttemptAt, _now);
    expect(row.status, 'pending');
    expect(row.lastErrorCode, isNull);
  });

  test('refuses a second mutation with the same idempotency key', () async {
    await db.into(db.syncMutationsTable).insert(_mutation());

    await expectLater(db.into(db.syncMutationsTable).insert(_mutation(id: 'm-2', entityId: 'tx-2')), throwsA(_constraint('UNIQUE')));
    expect(await db.select(db.syncMutationsTable).get(), hasLength(1));
  });

  test('refuses a negative attempt count', () async {
    await expectLater(db.into(db.syncMutationsTable).insert(_mutation(attemptCount: -1)), throwsA(_constraint('CHECK')));
  });

  test('refuses a mutation with no next attempt time', () async {
    // Below the companion, which cannot express the NULL.
    await expectLater(
      db.customStatement(
        'INSERT INTO sync_mutations (id, entity_type, entity_id, operation, payload_json, idempotency_key, created_at, attempt_count, next_attempt_at, status) '
        "VALUES ('m-1', 'transaction', 'tx-1', 'upsert', '{}', 'k-1', $_now, 0, NULL, 'pending')",
      ),
      throwsA(_constraint('NOT NULL')),
    );
  });

  test('the mutations ready to push are one range on the status index, with no table scan', () async {
    final plan = await db
        .customSelect("EXPLAIN QUERY PLAN SELECT * FROM sync_mutations WHERE status = 'pending' AND next_attempt_at <= ?", variables: [Variable.withInt(_now)])
        .get();

    expect(plan.map((row) => row.read<String>('detail')), ['SEARCH sync_mutations USING INDEX sync_mutations_status_next_attempt_at (status=? AND next_attempt_at<?)']);
  });
}

SyncMutationsTableCompanion _mutation({String id = 'm-1', String entityId = 'tx-1', int attemptCount = 0}) => SyncMutationsTableCompanion.insert(
  id: id,
  entityType: 'transaction',
  entityId: entityId,
  operation: 'upsert',
  payloadJson: '{"id":"$entityId"}',
  idempotencyKey: 'k-1',
  createdAt: _now,
  attemptCount: attemptCount,
  nextAttemptAt: _now,
  status: 'pending',
);

Matcher _constraint(String kind) => isA<SqliteException>().having((e) => e.message, 'message', contains('$kind constraint failed'));
