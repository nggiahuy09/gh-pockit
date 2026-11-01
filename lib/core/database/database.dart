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
  GPAppDatabase() : super(openAppConnection());

  GPAppDatabase.forTesting(super.e);

  /// A bump needs an `onUpgrade` step, a migration test and a dump in `drift_schemas/` (§6).
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),

    // `if (from < N)`, not a `switch`: a device that skipped releases must still run every step it missed, in order.
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // `createTable` skips `@TableIndex` indexes, so each is created here or upgraded devices would lack it.
        await m.createTable(accountsTable);
        await m.createIndex(accountsOwnerIdIsArchived);
      }
      if (from < 3) {
        await m.createTable(categoriesTable);
        await m.createIndex(categoriesOwnerIdType);
        await m.createIndex(categoriesOwnerIdNameKey);
      }
      if (from < 4) {
        await m.createTable(transactionsTable);
        await m.createIndex(transactionsOwnerIdOccurredAtId);
        await m.createIndex(transactionsAccountIdOccurredAtId);
        await m.createIndex(transactionsDestinationAccountIdOccurredAtId);
        await m.createIndex(transactionsCategoryIdOccurredAtId);
      }
    },
    beforeOpen: (details) async {
      // SQLite turns foreign keys off by default, per connection, so this runs on every open.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Off the UI isolate by `drift_flutter`'s default. `shareAcrossIsolates`: a second isolate (background sync) joins this instance instead of racing it
/// for the write lock (ADR-0001). The parameters exist for the test that pins this; the app passes none.
@visibleForTesting
QueryExecutor openAppConnection({String name = 'pockit', Future<Object> Function()? databaseDirectory, Future<String?> Function()? tempDirectoryPath}) => driftDatabase(
  name: name,
  native: DriftNativeOptions(shareAcrossIsolates: true, databaseDirectory: databaseDirectory, tempDirectoryPath: tempDirectoryPath),
);
