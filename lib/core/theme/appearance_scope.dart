import 'package:flutter/widgets.dart';

import 'appearance.dart';

/// An `InheritedNotifier`: [GPAppearance] mutates in place.
final class GPAppearanceScope extends InheritedNotifier<GPAppearance> {
  const GPAppearanceScope({super.key, required GPAppearance appearance, required super.child}) : super(notifier: appearance);

  static GPAppearance of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GPAppearanceScope>();
    assert(scope != null, 'No GPAppearanceScope found. Wrap the tree in one — GPApp does this for the running app.');
    return scope!.notifier!;
  }
}

extension GPAppearanceContext on BuildContext {
  GPAppearance get appearance => GPAppearanceScope.of(this);
}
