/// A soft delete is [delete] and a restore is [update] (ADR-0017): both carry the whole row, `deleted_at` included.
enum GPSyncOperation {
  create('create'),
  update('update'),
  delete('delete');

  const GPSyncOperation(this.storageValue);

  final String storageValue;

  static GPSyncOperation? fromStorage(String value) => values.where((operation) => operation.storageValue == value).firstOrNull;

  /// The operation of one mutation that replaces `this` and a [next] the server has seen neither of (ADR-0044). A [create] stays a
  /// [create], even when [next] deletes: the server never had the row, so it receives it once, as a tombstone.
  GPSyncOperation followedBy(GPSyncOperation next) {
    if (this == create) return create;
    // A row queued for an update or a delete was created already; an insert pushed for it would be refused on its primary key.
    if (next == create) throw ArgumentError.value(next, 'next', 'a create cannot follow $storageValue');
    return next;
  }
}
