import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/sync/sync_entity_type.dart';
import 'package:ghpockit/core/sync/sync_mutation_status.dart';
import 'package:ghpockit/core/sync/sync_operation.dart';

void main() {
  // Pinned literally: a stored value that changes orphans every mutation already queued with the old one.
  test('the stored values are the ones queued mutations hold', () {
    expect(
      {for (final type in GPSyncEntityType.values) type: type.storageValue},
      {
        GPSyncEntityType.account: 'account',
        GPSyncEntityType.category: 'category',
        GPSyncEntityType.transaction: 'transaction',
      },
    );
    expect(
      {for (final operation in GPSyncOperation.values) operation: operation.storageValue},
      {
        GPSyncOperation.create: 'create',
        GPSyncOperation.update: 'update',
        GPSyncOperation.delete: 'delete',
      },
    );
    expect(
      {for (final status in GPSyncMutationStatus.values) status: status.storageValue},
      {
        GPSyncMutationStatus.pending: 'pending',
        GPSyncMutationStatus.processing: 'processing',
        GPSyncMutationStatus.conflict: 'conflict',
        GPSyncMutationStatus.failed: 'failed',
      },
    );
  });

  test('every stored value reads back, and an unknown one reads as nothing rather than a guess', () {
    for (final type in GPSyncEntityType.values) {
      expect(GPSyncEntityType.fromStorage(type.storageValue), type);
    }
    for (final operation in GPSyncOperation.values) {
      expect(GPSyncOperation.fromStorage(operation.storageValue), operation);
    }
    for (final status in GPSyncMutationStatus.values) {
      expect(GPSyncMutationStatus.fromStorage(status.storageValue), status);
    }

    expect(GPSyncEntityType.fromStorage('budget'), isNull);
    expect(GPSyncOperation.fromStorage('upsert'), isNull);
    expect(GPSyncMutationStatus.fromStorage('completed'), isNull);
    // The Dart name is not the stored value.
    expect(GPSyncMutationStatus.fromStorage('Pending'), isNull);
  });

  group('two writes the server has seen neither of fold into one operation', () {
    const create = GPSyncOperation.create;
    const update = GPSyncOperation.update;
    const delete = GPSyncOperation.delete;

    // A restore is an update (ADR-0017), so "delete, then restore" is the delete → update row.
    final cases = {
      (create, update): create,
      (create, delete): create,
      (create, create): create,
      (update, update): update,
      (update, delete): delete,
      (delete, update): update,
      (delete, delete): delete,
    };

    for (final MapEntry(key: (first, next), value: expected) in cases.entries) {
      test('${first.name} then ${next.name} → ${expected.name}', () {
        expect(first.followedBy(next), expected);
      });
    }
  });
}
