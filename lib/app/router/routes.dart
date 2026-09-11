/// Every route path and route name in the app, in one place.
///
/// Two reasons this is not a set of string literals spread across the widgets:
///
/// 1. A deep link (`pockit://transactions/<id>`, an Android App Link) is a public contract with the OS and with whoever sent the link. A typo in a
///    literal is a broken link that no test catches, because the test would contain the same typo.
/// 2. Paths change (`/home` may become `/`), names do not. Widgets navigate by [RouteNames], so a path change stays inside this file and the router.
///
/// Paths are top-level (`/accounts`), not nested under the shell, so each tab is reachable as a deep link on its own. Child routes added in P1
/// (`/transactions/new`, `/accounts/:accountId`) hang off these.
abstract final class Routes {
  /// Where the app lands with no deep link. `/home`, not `/`, so that `/` stays free as the future auth/splash decision point.
  static const String initial = home;

  static const String home = '/home';
  static const String accounts = '/accounts';
  static const String transactions = '/transactions';
  static const String budgets = '/budgets';
  static const String settings = '/settings';
}

/// Route names used for navigation, so no widget has to know a path.
abstract final class RouteNames {
  static const String home = 'home';
  static const String accounts = 'accounts';
  static const String transactions = 'transactions';
  static const String budgets = 'budgets';
  static const String settings = 'settings';
}
