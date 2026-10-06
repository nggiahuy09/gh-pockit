import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';

/// Watch streams carry failures as [GPFailure] errors; any other error on them is a bug. A write by id returns [GPNotFoundFailure] when no live row has it.
abstract class AccountRepository {
  const AccountRepository();

  /// Oldest first; archived accounts only with [includeArchived].
  Stream<List<AccountEntity>> watchAccounts({bool includeArchived = false});

  /// Emits null while no live, unarchived account has [id].
  Stream<AccountEntity?> watchAccount(String id);

  /// Returns [GPValidationFailure] when the name is blank or too long.
  Future<GPResult<AccountEntity>> createAccount({required String name, required AccountType type, required Money initialBalance});

  /// Guarded on [AccountEntity.version]: [GPConflictFailure] when the row changed since it was read. Returns the account with a fresh `updatedAt`.
  Future<GPResult<AccountEntity>> updateAccount(AccountEntity account);

  /// Hides the account from [watchAccounts]; unlike a delete, it keeps its transactions and keeps syncing.
  Future<GPResult<void>> archiveAccount(String id);

  Future<GPResult<void>> unarchiveAccount(String id);

  /// Soft delete with no check for live transactions: delete through `DeleteAccountUseCase` (ADR-0010).
  Future<GPResult<void>> deleteAccount(String id);
}
