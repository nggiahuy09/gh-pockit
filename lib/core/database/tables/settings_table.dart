import 'package:drift/drift.dart';

/// Device-local key/value settings — the language choice of ADR-0004 first, whatever joins it later.
///
/// **Local-only, never synced.** No `owner_id`, no `version`, no `deleted_at`: CLAUDE.md §6 demands those of every *synced* entity, and this table is
/// deliberately not one. A language belongs to a device, not to an account (ADR-0004) — a phone kept in Vietnamese and a work tablet kept in English must
/// not fight over it — so a row here never enters the outbox and a sync round trip never sits between a tap and the UI repainting.
///
/// **Key/value instead of one typed column per setting** (ADR-0001, open question 3). Typed columns are the better shape once the columns are known; today
/// they are not, and finding out later costs a `schemaVersion` bump, a migration and a fixture test *per setting*. What key/value buys in exchange is a
/// `String` parsed by hand, and that risk is bounded: nothing in this table is money, an id, or anything sync reads. The moment a setting needs a real type,
/// it earns its own table rather than a `switch` on this one.
///
/// **On the name.** Unprefixed on purpose, next to a `GPAppDatabase` that is prefixed. A `Table` subclass exists only to declare a row, and CLAUDE.md §3
/// puts rows in the unprefixed column alongside DTOs and mappers — prefixing the declaration while the `SettingRow` it declares stays bare would make the
/// prefix stop carrying information (§12.12). It also keeps this table readable next to the feature tables that arrive in W2 T3 and W4, which live under
/// `features/*/data/` and are unprefixed for the same reason. The generated accessor settles it: `GPSettingsTable` would be reached as `db.gPSettingsTable`.
@DataClassName('SettingRow')
class SettingsTable extends Table {
  /// Namespaced by dotted prefix (`locale.selected`) so a later feature cannot collide with an older one by picking the same short word.
  TextColumn get key => text()();

  /// Always a string, whatever the caller means by it. Parsing belongs to the store that owns the key — `GPDriftLocaleStore` for `locale.*` — not here.
  TextColumn get value => text()();

  /// Epoch millis, UTC (§6 — never an ISO string). Written from `GPClock`, never `DateTime.now()`, so a test can state the time instead of racing it.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};

  /// Stated rather than derived. The SQL name is what migrations and schema fixtures key on, and deriving it from a Dart class name means a rename in
  /// Dart silently becomes a schema change.
  @override
  String get tableName => 'settings';
}
