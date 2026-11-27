enum GPSyncEntityType {
  account('account'),
  category('category'),
  transaction('transaction');

  const GPSyncEntityType(this.storageValue);

  /// Written out, never derived from `name`: renaming a value must not orphan queued mutations.
  final String storageValue;

  static GPSyncEntityType? fromStorage(String value) => values.where((type) => type.storageValue == value).firstOrNull;
}
