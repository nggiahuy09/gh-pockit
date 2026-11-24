import 'dart:async';

import '../logging/app_logger.dart';
import 'database.dart';
import 'owner_context.dart';
import 'owner_id.dart';

/// Caches the `owner.id` settings row, which the claim writes (ADR-0040).
final class GPSettingsOwnerContext implements GPOwnerContext {
  GPSettingsOwnerContext({required GPAppDatabase database, required GPAppLogger logger}) : _database = database, _logger = logger;

  static const storageKey = 'owner.id';

  final GPAppDatabase _database;
  final GPAppLogger _logger;
  final StreamController<String> _changes = StreamController<String>.broadcast(sync: true);

  String _current = localOwnerId;

  @override
  String get current => _current;

  @override
  Stream<String> watch() {
    StreamSubscription<String>? subscription;
    late final StreamController<String> controller;
    controller = StreamController<String>(
      onListen: () {
        controller.add(_current);
        subscription = _changes.stream.listen(controller.add);
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  Future<void> load() async {
    final String owner;
    try {
      final row = await (_database.select(_database.settingsTable)..where((t) => t.key.equals(storageKey))).getSingleOrNull();
      owner = row?.value ?? localOwnerId;
    } on Exception catch (error) {
      // Keeps the last owner rather than guess.
      _logger.error('owner read failed', fields: {'error': error.runtimeType.toString()});
      return;
    }
    if (owner == _current) return;

    _current = owner;
    _changes.add(owner);
  }

  /// Synchronous right after the claim commits, so no open query re-runs for the old owner.
  void adopt(String ownerId) {
    if (ownerId == _current) return;

    _current = ownerId;
    _changes.add(ownerId);
  }

  Future<void> dispose() => _changes.close();
}
