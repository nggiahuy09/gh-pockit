import 'dart:async';

import 'package:ghpockit/core/database/owner_context.dart';
import 'package:ghpockit/core/database/owner_id.dart';

/// [switchTo] stands in for a claim: every query built on [watch] moves to the new owner.
final class FixedOwnerContext implements GPOwnerContext {
  FixedOwnerContext([this._current = localOwnerId]);

  String _current;
  final StreamController<String> _changes = StreamController<String>.broadcast(sync: true);

  @override
  String get current => _current;

  @override
  Stream<String> watch() async* {
    yield _current;
    yield* _changes.stream;
  }

  void switchTo(String ownerId) {
    _current = ownerId;
    _changes.add(ownerId);
  }
}
