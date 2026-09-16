import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_store.dart';
import 'package:ghpockit/core/utils/clock.dart';

/// The persistent [GPLocaleStore] — the W1 debt ADR-0004 left open, paid at W2 once a `settings` table existed to pay it with.
///
/// Until this class was wired, `GPInMemoryLocaleStore` was bound in DI, which meant the language a user picked survived exactly as long as the process:
/// a tap changed the UI, a restart threw it away. That is the entire bug.
///
/// **In its own file rather than beside the interface.** `locale_store.dart` is imported by `localization.dart`, which is imported by the whole widget
/// tree; putting a `GPAppDatabase` import there would drag the database into everything that renders a string. The interface stays dependency-free and the
/// implementation carries its own weight.
///
/// Local-only, and that is a decision rather than an omission (ADR-0004): the row lives in `settings`, which has no `owner_id`, no `version` and no
/// `deleted_at`, never enters the outbox and never syncs. A language belongs to a device — a phone kept in Vietnamese and a work tablet kept in English
/// must not fight over it — and no sync round trip may sit between a tap and the UI repainting.
class GPDriftLocaleStore extends GPLocaleStore {
  GPDriftLocaleStore({required GPAppDatabase database, required GPClock clock}) : _db = database, _clock = clock;

  /// The `settings` key this store owns. Dotted namespace as that table's doc requires, so a later feature cannot collide by picking the same short word.
  static const String storageKey = 'locale.selected';

  final GPAppDatabase _db;
  final GPClock _clock;

  /// Reads the stored choice, or null when there is none — and null means *follow the device*, not English.
  @override
  Future<GPLocale?> read() async {
    final row = await (_db.select(_db.settingsTable)..where((t) => t.key.equals(storageKey))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    // Matched exactly rather than through `GPLocale.fromLanguageCode`, which falls back to `GPLocale.en` for anything it does not ship. That fallback is
    // right at the device-locale boundary and wrong here: it would turn a row left behind by a language we dropped — or a value corrupted by anything —
    // into an explicit English choice the user never made, and `GPLocalization.isExplicit` would then stop the device language from ever applying again.
    // Unrecognised means "no usable choice", which is what null already means.
    for (final candidate in GPLocale.values) {
      if (candidate.languageCode == row.value) {
        return candidate;
      }
    }
    return null;
  }

  @override
  Future<void> write(GPLocale locale) async {
    await _db
        .into(_db.settingsTable)
        .insertOnConflictUpdate(
          // Upsert, not insert: `key` is the primary key, so the second language change of a session would throw on a plain insert. `insertOnConflictUpdate`
          // is the one write mode that makes "remember this choice" idempotent, which also matters because `GPLocalization.changeLocale` does not await it.
          SettingsTableCompanion.insert(
            key: storageKey,
            value: locale.languageCode,
            // Epoch millis from `GPClock`, never `DateTime.now()` (§6, §8) — the column exists so a later settings screen can say when something was changed.
            updatedAt: _clock.nowEpochMillis(),
          ),
        );
  }
}
