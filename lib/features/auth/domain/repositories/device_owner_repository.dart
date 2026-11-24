import '../../../../core/error/result.dart';

/// Whose data this device holds (ADR-0040).
abstract class DeviceOwnerRepository {
  const DeviceOwnerRepository();

  /// `localOwnerId` until a claim, then the uid until a sign-out.
  String get ownerId;

  /// Moves every `'local'` row to [userId] in one transaction; returns how many moved.
  Future<GPResult<int>> claimLocalData(String userId);
}
