import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension PopOrGo on BuildContext {
  /// Back to the page underneath, or to [routeName] when there is none: a form opened cold from a deep link. go_router throws on a pop with nothing
  /// under it.
  void popOrGoNamed(String routeName) => canPop() ? pop() : goNamed(routeName);
}
