import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_store.dart';

final class GPFlutterSecureStore implements GPSecureStore {
  GPFlutterSecureStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Readable once the phone was unlocked after boot, so a background sync can use it; never in an iCloud backup or on another device.
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
