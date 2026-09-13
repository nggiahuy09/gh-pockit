import 'package:flutter/widgets.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/localization.dart';

/// Puts the active language in the widget tree — both the strings to read and the controller to change them.
///
/// Why an inherited widget rather than reading a singleton inside `build()`: a widget that calls `context.l10n` registers a dependency, so it is
/// rebuilt when the language changes. Reading a global would compile and then quietly keep the old language on screen.
///
/// Why `InheritedNotifier` specifically, and not a plain `InheritedWidget` holding the strings: [GPLocalization] is mutable and long-lived, so a
/// plain inherited widget would be comparing one object against itself in `updateShouldNotify` — always equal, never a rebuild. `InheritedNotifier`
/// subscribes to the notifier instead of diffing widget fields, so dependents repaint whether or not this widget was rebuilt.
///
/// Carrying the controller here too is what keeps `getIt` out of the pages: a language picker calls `context.localization.changeLocale(...)`, so it
/// can be pumped in a widget test with no locator configured at all.
class GPLocalizationScope extends InheritedNotifier<GPLocalization> {
  const GPLocalizationScope({required GPLocalization localization, required super.child, super.key}) : super(notifier: localization);

  /// The active strings, with a dependency registered so the caller rebuilds on a language change.
  static GPLocaleBase of(BuildContext context) => _localizationOf(context).current;

  /// The controller, for the one screen that changes the language.
  static GPLocalization controllerOf(BuildContext context) => _localizationOf(context);

  static GPLocalization _localizationOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GPLocalizationScope>();
    assert(scope != null, 'No GPLocalizationScope found. Wrap the tree in one — GPApp does this for the running app.');
    return scope!.notifier!;
  }
}

extension GPLocalizationContext on BuildContext {
  /// The active strings, and a dependency on the language so this widget rebuilds when it changes.
  GPLocaleBase get l10n => GPLocalizationScope.of(this);

  /// The language controller. Only a language picker needs this; everything else reads [l10n].
  GPLocalization get localization => GPLocalizationScope.controllerOf(this);
}
