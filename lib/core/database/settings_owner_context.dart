import 'dart:async';

import '../logging/app_logger.dart';
import 'database.dart';
import 'owner_context.dart';
import 'owner_id.dart';

/// The owner is a `settings` row, written in the same transaction as the rows it moves (ADR-0040); this class only caches and announces it.
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

  /// Once in the bootstrap, after the database opens.
  Future<void> load() async {
    final String owner;
    try {
      final row = await (_database.select(_database.settingsTable)..where((t) => t.key.equals(storageKey))).getSingleOrNull();
      owner = row?.value ?? localOwnerId;
    } on Exception catch (error) {
      // Keeps what it had: at launch that is 'local', which hides a claimed user's rows until the next launch rather than mixing owners.
      _logger.error('owner read failed', fields: {'error': error.runtimeType.toString()});
      return;
    }
    if (owner == _current) return;

    _current = owner;
    _changes.add(owner);
  }

  /// After a transaction that wrote the row commits: synchronous, so every open query switches before drift re-runs it for the old owner and
  /// emits an empty list in between.
  void adopt(String ownerId) {
    if (ownerId == _current) return;

    _current = ownerId;
    _changes.add(ownerId);
  }

  Future<void> dispose() => _changes.close();
}
