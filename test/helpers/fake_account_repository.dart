import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';

/// Serves whatever account stream the test hands it, for states the real repository cannot produce on request. Writes throw.
final class FakeAccountRepository extends AccountRepository {
  /// Without [_accounts], each call gets a fresh one-empty-list stream: `Stream.value` can be listened to only once.
  const FakeAccountRepository([this._accounts]);

  final Stream<List<AccountEntity>>? _accounts;

  @override
  Stream<List<AccountEntity>> watchAccounts([bool includeArchived = false]) => _accounts ?? Stream.value(const []);

  @override
  Stream<AccountEntity?> watchAccount(String id) => throw UnimplementedError();

  @override
  Future<GPResult<AccountEntity>> createAccount({required Money initialBalance, required AccountType type, required String name}) => throw UnimplementedError();

  @override
  Future<GPResult<AccountEntity>> updateAccount(AccountEntity account) => throw UnimplementedError();

  @override
  Future<GPResult<void>> archiveAccount(String id) => throw UnimplementedError();

  @override
  Future<GPResult<void>> unarchiveAccount(String id) => throw UnimplementedError();

  @override
  Future<GPResult<void>> deleteAccount(String id) => throw UnimplementedError();
}
