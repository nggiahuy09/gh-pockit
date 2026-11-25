/// A soft delete is [delete] and a restore is [update] (ADR-0017): both carry the whole row, `deleted_at` included.
enum GPSyncOperation {
  create('create'),
  update('update'),
  delete('delete');

  const GPSyncOperation(this.storageValue);

  final String storageValue;

  static GPSyncOperation? fromStorage(String value) => values.where((operation) => operation.storageValue == value).firstOrNull;

  /// The operation of one mutation that replaces `this` and a [next] the server has seen neither of (W13 plan, decision D). A [create]
  /// stays a [create], even when [next] deletes: the server never had the row, so it receives it once, as a tombstone.
  GPSyncOperation followedBy(GPSyncOperation next) => this == create ? create : next;
}
