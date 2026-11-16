import 'package:flutter/services.dart';
import 'package:ghpockit/core/security/secure_store.dart';

/// [failing] makes every call throw, like a locked keychain.
final class InMemorySecureStore implements GPSecureStore {
  final Map<String, String> values = {};
  bool failing = false;

  @override
  Future<String?> read(String key) async {
    _maybeFail();
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _maybeFail();
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _maybeFail();
    values.remove(key);
  }

  void _maybeFail() {
    if (failing) throw PlatformException(code: 'KeychainLocked');
  }
}
