import 'package:flutter/widgets.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/localization.dart';

/// An `InheritedNotifier`, not a plain `InheritedWidget`: [GPLocalization] mutates in place, so `updateShouldNotify` would compare it with itself and
/// never rebuild dependents.
class GPLocalizationScope extends InheritedNotifier<GPLocalization> {
  const GPLocalizationScope({required GPLocalization localization, required super.child, super.key}) : super(notifier: localization);

  static GPLocaleBase of(BuildContext context) => _localizationOf(context).current;

  static GPLocalization controllerOf(BuildContext context) => _localizationOf(context);

  static GPLocalization _localizationOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GPLocalizationScope>();
    assert(scope != null, 'No GPLocalizationScope found. Wrap the tree in one — GPApp does this for the running app.');
    return scope!.notifier!;
  }
}

extension GPLocalizationContext on BuildContext {
  GPLocaleBase get l10n => GPLocalizationScope.of(this);

  /// Only a language picker needs the controller; everything else reads [l10n].
  GPLocalization get localization => GPLocalizationScope.controllerOf(this);
}
