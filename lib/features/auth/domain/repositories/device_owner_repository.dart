import '../../../../core/error/result.dart';

/// Whose data this device holds (ADR-0040).
abstract class DeviceOwnerRepository {
  const DeviceOwnerRepository();

  /// `localOwnerId` until a claim, then the uid until a sign-out.
  String get ownerId;

  /// Moves every `'local'` row to [userId] in one transaction; returns how many moved.
  Future<GPResult<int>> claimLocalData(String userId);

  /// Rows that are not on the server yet; a sign-out would lose them.
  Future<GPResult<int>> countUnsyncedChanges();

  /// Deletes the owner's rows, gives the device back to `localOwnerId` and reseeds the default categories. Keeps `settings` (ADR-0042).
  Future<GPResult<void>> releaseDevice();
}
