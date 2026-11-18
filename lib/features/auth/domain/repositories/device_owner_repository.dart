import '../../../../core/error/result.dart';

/// Whose data this device holds (ADR-0040).
abstract class DeviceOwnerRepository {
  const DeviceOwnerRepository();

  /// `localOwnerId` until a claim, then the claiming user's id, until an explicit sign-out wipes the device.
  String get ownerId;

  /// Gives every `'local'` row to [userId] and makes [userId] the device owner, in one transaction: all of it or none. Returns how many rows
  /// moved. A no-op when nothing is `'local'`.
  Future<GPResult<int>> claimLocalData(String userId);
}
