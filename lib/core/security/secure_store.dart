/// Secrets kept by the OS (Keychain, Keystore), never SharedPreferences or the database (blueprint §34). Every call may throw a
/// `PlatformException`: a locked keychain, a Keystore key lost to a backup restore. Callers decide what that means for them.
abstract interface class GPSecureStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}
