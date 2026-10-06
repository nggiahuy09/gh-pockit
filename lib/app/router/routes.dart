/// Paths are a deep-link contract with the OS. Widgets navigate by [RouteNames], so a path change stays in this file and the router.
abstract final class Routes {
  /// `/home`, not `/`: `/` stays free for the future auth/splash decision.
  static const String initial = home;

  static const String home = '/home';
  static const String accounts = '/accounts';
  static const String transactions = '/transactions';
  static const String budgets = '/budgets';
  static const String settings = '/settings';
}

abstract final class RouteNames {
  static const String home = 'home';
  static const String accounts = 'accounts';
  static const String transactions = 'transactions';
  static const String budgets = 'budgets';
  static const String settings = 'settings';
}
