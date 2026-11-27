/// Whether the server has this version of the transaction (ADR-0045). Read from the row, never stored here.
enum TransactionSyncStatus {
  /// Written on a device no account owns yet: nothing pushes it until a sign-in claims it, so it is not "waiting".
  localOnly,

  /// A local write the server has not acknowledged.
  pending,

  synced,
}
