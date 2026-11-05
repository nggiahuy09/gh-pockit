/// The file's `user_version` is above this build's `schemaVersion`. Thrown before any statement, so the file is left as found (ADR-0030).
final class GPDatabaseTooNewException implements Exception {
  const GPDatabaseTooNewException({required this.fileVersion, required this.appVersion});

  final int fileVersion;
  final int appVersion;

  @override
  String toString() => 'GPDatabaseTooNewException: the file is at v$fileVersion, this build knows up to v$appVersion';
}
