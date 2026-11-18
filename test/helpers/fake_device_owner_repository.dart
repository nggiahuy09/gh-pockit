import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/auth/domain/repositories/device_owner_repository.dart';

/// A successful claim makes the user the owner, as the real one does.
final class FakeDeviceOwnerRepository extends DeviceOwnerRepository {
  FakeDeviceOwnerRepository({this.ownerId = localOwnerId});

  @override
  String ownerId;

  /// Null claims: the owner becomes the user and the answer is `GPOk(3)`.
  GPResult<int>? claimResult;

  final List<String> claims = [];

  @override
  Future<GPResult<int>> claimLocalData(String userId) async {
    claims.add(userId);
    final result = claimResult ?? const GPOk(3);
    if (result is GPOk<int>) ownerId = userId;
    return result;
  }
}
