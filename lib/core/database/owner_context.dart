/// Whose rows the device holds: `localOwnerId` until a claim, then the uid until an explicit sign-out (ADR-0040).
abstract interface class GPOwnerContext {
  String get current;

  /// [current] at once, then each change; a query must follow it, or a claim empties it.
  Stream<String> watch();
}
