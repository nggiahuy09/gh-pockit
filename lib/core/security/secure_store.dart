/// Secrets in the Keychain / Keystore (blueprint §34). Any call may throw a `PlatformException`.
abstract interface class GPSecureStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}
