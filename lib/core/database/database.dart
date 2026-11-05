import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:meta/meta.dart';

import '../../features/accounts/data/tables/accounts_table.dart';
import '../../features/categories/data/tables/categories_table.dart';
import '../../features/transactions/data/tables/transactions_table.dart';
import 'tables/settings_table.dart';

part 'database.g.dart';

/// The only persistent store, so golden rule 3 is one transaction; auth tokens alone go to secure storage (ADR-0001).
@DriftDatabase(tables: [SettingsTable, AccountsTable, CategoriesTable, TransactionsTable])
final class GPAppDatabase extends _$GPAppDatabase {
  /// [name] is the file's: a benchmark run opens its own, so it never touches the real data (ADR-0026).
  GPAppDatabase({String name = 'pockit'}) : super(openAppConnection(name: name));

  GPAppDatabase.forTesting(super.e);

  /// A bump needs a case in `_upgradeTo`, a migration test and a dump in `drift_schemas/` (§6).
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => _commitAt(schemaVersion, m.createAll),

    // One step per version, in order, so a device that skipped releases runs every step it missed; each commits on its own (ADR-0029).
    onUpgrade: (m, from, to) async {
      for (var version = from + 1; version <= to; version++) {
        await _commitAt(version, () => _upgradeTo(version, m));
      }
    },
    beforeOpen: (details) async {
      // SQLite turns foreign keys off by default, per connection, so this runs on every open.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Drift writes `user_version` only after the whole migration returns, outside any transaction: a kill in between re-runs a step that
  /// already committed, and its `CREATE INDEX` then fails on every launch (ADR-0029).
  Future<void> _commitAt(int version, Future<void> Function() step) => transaction(() async {
    await step();
    await customStatement('PRAGMA user_version = $version');
  });

  Future<void> _upgradeTo(int version, Migrator m) async {
    switch (version) {
      case 2:
        // `createTable` skips `@TableIndex` indexes, so each is created here or upgraded devices would lack it.
        await m.createTable(accountsTable);
        await m.createIndex(accountsOwnerIdIsArchived);
      case 3:
        await m.createTable(categoriesTable);
        await m.createIndex(categoriesOwnerIdType);
        await m.createIndex(categoriesOwnerIdNameKey);
      case 4:
        await m.createTable(transactionsTable);
        await m.createIndex(transactionsOwnerIdOccurredAtId);
        // As v4 shipped them, not as declared now: a migration that stops at 4 must leave the v4 schema.
        await m.createIndex(_v4AccountIndex);
        await m.createIndex(_v4DestinationAccountIndex);
        await m.createIndex(transactionsCategoryIdOccurredAtId);
      case 5:
        // Same names, wider columns (ADR-0027). SQLite cannot alter an index, so each is dropped and rebuilt from the rows already there.
        await m.drop(transactionsAccountIdOccurredAtId);
        await m.drop(transactionsDestinationAccountIdOccurredAtId);
        await m.createIndex(transactionsAccountIdOccurredAtId);
        await m.createIndex(transactionsDestinationAccountIdOccurredAtId);
      default:
        throw StateError('No migration step to v$version');
    }
  }
}

final _v4AccountIndex = Index(
  'transactions_account_id_occurred_at_id',
  'CREATE INDEX transactions_account_id_occurred_at_id ON transactions (account_id, occurred_at, id)',
);
final _v4DestinationAccountIndex = Index(
  'transactions_destination_account_id_occurred_at_id',
  'CREATE INDEX transactions_destination_account_id_occurred_at_id ON transactions (destination_account_id, occurred_at, id)',
);

/// Off the UI isolate by `drift_flutter`'s default. `shareAcrossIsolates`: a second isolate (background sync) joins this instance instead of racing it
/// for the write lock (ADR-0001). The parameters exist for the test that pins this; the app passes none.
@visibleForTesting
QueryExecutor openAppConnection({String name = 'pockit', Future<Object> Function()? databaseDirectory, Future<String?> Function()? tempDirectoryPath}) => driftDatabase(
  name: name,
  native: DriftNativeOptions(shareAcrossIsolates: true, databaseDirectory: databaseDirectory, tempDirectoryPath: tempDirectoryPath),
);
