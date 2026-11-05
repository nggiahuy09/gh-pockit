import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:meta/meta.dart';

import '../../features/accounts/data/tables/accounts_table.dart';
import '../../features/categories/data/tables/categories_table.dart';
import '../../features/transactions/data/tables/transactions_table.dart';
import 'database.steps.dart';
import 'database_too_new_exception.dart';
import 'tables/settings_table.dart';

part 'database.g.dart';

/// The only persistent store, so golden rule 3 is one transaction; auth tokens alone go to secure storage (ADR-0001).
@DriftDatabase(tables: [SettingsTable, AccountsTable, CategoriesTable, TransactionsTable])
final class GPAppDatabase extends _$GPAppDatabase {
  /// [name] is the file's: a benchmark run opens its own, so it never touches the real data (ADR-0026).
  GPAppDatabase({String name = 'pockit'}) : super(openAppConnection(name: name));

  GPAppDatabase.forTesting(super.e);

  /// A bump needs a dump in `drift_schemas/`, a regenerated `database.steps.dart`, a `fromNToM` step and a migration test (§6, §9).
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => _commitAt(schemaVersion, m.createAll),

    // One step per version, in order, so a device that skipped releases runs every step it missed; each commits on its own (ADR-0029).
    onUpgrade: (m, from, to) async {
      // Drift calls this on a downgrade too, then writes `to` over a schema it does not know. Refuse before any statement (ADR-0030).
      if (from > to) throw GPDatabaseTooNewException(fileVersion: from, appVersion: to);
      for (var version = from; version < to; version++) {
        await _commitAt(version + 1, () => _upgradeFrom(version, this));
      }
    },
    beforeOpen: (details) async {
      // SQLite turns foreign keys off by default, per connection, so this runs on every open.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Drift opens on the first query, so this is that query: a migration that fails surfaces here, in the bootstrap, not under a screen (ADR-0030).
  Future<void> open() async {
    await customSelect('SELECT 1').get();
  }

  /// Drift writes `user_version` only after the whole migration returns, outside any transaction: a kill in between re-runs a step that
  /// already committed, and its `CREATE INDEX` then fails on every launch (ADR-0029).
  Future<void> _commitAt(int version, Future<void> Function() step) => transaction(() async {
    await step();
    await customStatement('PRAGMA user_version = $version');
  });
}

/// Not drift's `stepByStep`, which runs the whole chain outside any transaction. Each step sees the schema of the version it reaches, never
/// the current one, so an entity redefined later cannot leak into an older step (ADR-0029).
final Future<int> Function(int from, GeneratedDatabase database) _upgradeFrom = migrationSteps(
  from1To2: (m, schema) async {
    // `createTable` skips `@TableIndex` indexes, so each is created here or upgraded devices would lack it.
    await m.createTable(schema.accounts);
    await m.createIndex(schema.accountsOwnerIdIsArchived);
  },
  from2To3: (m, schema) async {
    await m.createTable(schema.categories);
    await m.createIndex(schema.categoriesOwnerIdType);
    await m.createIndex(schema.categoriesOwnerIdNameKey);
  },
  from3To4: (m, schema) async {
    await m.createTable(schema.transactions);
    await m.createIndex(schema.transactionsOwnerIdOccurredAtId);
    await m.createIndex(schema.transactionsAccountIdOccurredAtId);
    await m.createIndex(schema.transactionsDestinationAccountIdOccurredAtId);
    await m.createIndex(schema.transactionsCategoryIdOccurredAtId);
  },
  from4To5: (m, schema) async {
    // Same names, wider columns (ADR-0027). SQLite cannot alter an index, so each is dropped and rebuilt from the rows already there.
    await m.drop(schema.transactionsAccountIdOccurredAtId);
    await m.drop(schema.transactionsDestinationAccountIdOccurredAtId);
    await m.createIndex(schema.transactionsAccountIdOccurredAtId);
    await m.createIndex(schema.transactionsDestinationAccountIdOccurredAtId);
  },
);

/// Off the UI isolate by `drift_flutter`'s default. `shareAcrossIsolates`: a second isolate (background sync) joins this instance instead of racing it
/// for the write lock (ADR-0001). The parameters exist for the test that pins this; the app passes none.
@visibleForTesting
QueryExecutor openAppConnection({String name = 'pockit', Future<Object> Function()? databaseDirectory, Future<String?> Function()? tempDirectoryPath}) => driftDatabase(
  name: name,
  native: DriftNativeOptions(shareAcrossIsolates: true, databaseDirectory: databaseDirectory, tempDirectoryPath: tempDirectoryPath),
);
