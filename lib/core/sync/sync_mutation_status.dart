/// A mutation the server accepted is deleted, so there is no `completed` (golden rule 6; system-design §6.3).
enum GPSyncMutationStatus {
  pending('pending'),

  /// Sent and not yet answered. One found at launch was orphaned by a kill and goes back to [pending], its attempt still counted.
  processing('processing'),

  conflict('conflict'),

  /// Non-retryable, or out of attempts: kept for Diagnostics, never pushed again.
  failed('failed');

  const GPSyncMutationStatus(this.storageValue);

  final String storageValue;

  static GPSyncMutationStatus? fromStorage(String value) => values.where((status) => status.storageValue == value).firstOrNull;
}
