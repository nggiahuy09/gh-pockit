import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/domain/usecases/watch_accounts_use_case.dart';
import 'package:meta/meta.dart';

@immutable
final class HomeAccountsState {
  const HomeAccountsState({this.accounts, this.failure});

  /// Null until the first list arrives.
  final List<AccountEntity>? accounts;

  /// Cleared by the next list: the stream stays live, so the section recovers by itself.
  final GPFailure? failure;

  bool get isLoading => accounts == null && failure == null;
}

/// The accounts section of Home, live from the local database (ADR-0013: through the use case, never the repository).
class HomeAccountsCubit extends Cubit<HomeAccountsState> {
  HomeAccountsCubit() : super(const HomeAccountsState());

  final WatchAccountsUseCase _watchAccounts = WatchAccountsUseCase(accountRepository: getIt<AccountRepository>());
  StreamSubscription<List<AccountEntity>>? _subscription;

  void start() {
    _subscription ??= _watchAccounts().listen(
      (List<AccountEntity> accounts) => emit(HomeAccountsState(accounts: List<AccountEntity>.unmodifiable(accounts))),
      onError: (Object error, StackTrace stackTrace) {
        // Anything but a `GPFailure` is a bug: rethrown, not shown as a sentence (ADR-0006).
        if (error is! GPFailure) Error.throwWithStackTrace(error, stackTrace);
        emit(HomeAccountsState(accounts: state.accounts, failure: error));
      },
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
