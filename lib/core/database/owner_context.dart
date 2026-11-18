/// Whose rows this device reads and writes (ADR-0040): `localOwnerId` until a sign-in claims them, then that user's uid, until an explicit
/// sign-out wipes the device. A session that ends by itself leaves it as it is.
abstract interface class GPOwnerContext {
  String get current;

  /// [current] at once, then each change. A query built on it must follow, or a claim would leave it filtering on the old owner.
  Stream<String> watch();
}
