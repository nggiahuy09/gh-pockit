import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/money/money.dart';
import '../entities/account_entity.dart';
import '../entities/account_type.dart';

/// A write by id returns [GPNotFoundFailure] when no live row has it.
abstract class AccountRepository {
  const AccountRepository();

  /// Oldest first.
  Stream<List<AccountEntity>> watchAccounts([bool includeArchived = false]);

  /// Emits null while no live, unarchived account has [id].
  Stream<AccountEntity?> watchAccount(String id);

  Future<GPResult<AccountEntity>> createAccount({required Money initialBalance, required AccountType type, required String name});

  /// [GPConflictFailure] when the row changed since it was read.
  Future<GPResult<AccountEntity>> updateAccount(AccountEntity account);

  Future<GPResult<void>> archiveAccount(String id);

  Future<GPResult<void>> unarchiveAccount(String id);

  /// No check for live transactions: delete through `DeleteAccountUseCase` (ADR-0010).
  Future<GPResult<void>> deleteAccount(String id);
}
