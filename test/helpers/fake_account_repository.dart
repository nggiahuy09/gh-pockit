import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';

/// An [AccountRepository] whose account list is whatever stream the test hands it.
///
/// For the states the real `AccountRepositoryImpl` cannot produce on request — a list that has not arrived yet, or an error that is not a `GPFailure` —
/// and for the router tests, which only need the Accounts tab to build. Everything else runs on the real repository over in-memory Drift, for the reason
/// `account_repository_impl_test.dart` gives.
///
/// Writes throw: no test that uses this double should reach one, and a fake that pretended to write would be asserting against itself.
class FakeAccountRepository implements AccountRepository {
  /// With no [accounts], every subscription gets one empty list — all a navigation test needs, and a fresh stream per call because `Stream.value` can be
  /// listened to only once.
  FakeAccountRepository({Stream<List<AccountEntity>>? accounts}) : _accounts = accounts;

  final Stream<List<AccountEntity>>? _accounts;

  @override
  Stream<List<AccountEntity>> watchAccounts({bool includeArchived = false}) => _accounts ?? Stream<List<AccountEntity>>.value(const <AccountEntity>[]);

  @override
  Stream<AccountEntity?> watchAccount(String id) => throw UnimplementedError();

  @override
  Future<GPResult<AccountEntity>> createAccount({required String name, required AccountType type, required Money initialBalance}) => throw UnimplementedError();

  @override
  Future<GPResult<AccountEntity>> updateAccount(AccountEntity account) => throw UnimplementedError();

  @override
  Future<GPResult<void>> archiveAccount(String id) => throw UnimplementedError();

  @override
  Future<GPResult<void>> unarchiveAccount(String id) => throw UnimplementedError();

  @override
  Future<GPResult<void>> deleteAccount(String id) => throw UnimplementedError();
}
