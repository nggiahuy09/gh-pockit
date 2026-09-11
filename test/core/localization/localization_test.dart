import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_store.dart';
import 'package:ghpockit/core/localization/localization.dart';

void main() {
  group('GPLocale', () {
    test('resolves a supported device language', () {
      expect(GPLocale.fromPlatform(const Locale('vi')), GPLocale.vi);
      expect(GPLocale.fromPlatform(const Locale('en')), GPLocale.en);
    });

    test('ignores country — one translation serves every region of a language', () {
      expect(GPLocale.fromPlatform(const Locale('en', 'GB')), GPLocale.en);
      expect(GPLocale.fromPlatform(const Locale('vi', 'VN')), GPLocale.vi);
    });

    test('falls back for a language we do not ship', () {
      expect(GPLocale.fromPlatform(const Locale('ja')), GPLocale.fallback);
      expect(GPLocale.fromLanguageCode('vn'), GPLocale.en, reason: 'a plausible typo must not silently become Vietnamese');
      expect(GPLocale.fromLanguageCode(null), GPLocale.fallback);
    });

    test('names each language in its own language', () {
      // Translating these would be the bug: a Vietnamese speaker on an English UI has to recognise their own option.
      expect(GPLocale.vi.displayName, 'Tiếng Việt');
      expect(GPLocale.en.displayName, 'English');
    });
  });

  group('GPLocalization.init', () {
    test('prefers a stored choice over the device language', () async {
      final localization = GPLocalization(store: GPInMemoryLocaleStore(initial: GPLocale.vi));

      await localization.init(deviceLocale: const Locale('en'));

      expect(localization.locale, GPLocale.vi);
      expect(localization.isExplicit, isTrue);
    });

    test('follows the device when nothing is stored', () async {
      final localization = GPLocalization(store: GPInMemoryLocaleStore());

      await localization.init(deviceLocale: const Locale('vi'));

      expect(localization.locale, GPLocale.vi);
      expect(localization.isExplicit, isFalse, reason: 'following the device is not the same as the user choosing Vietnamese');
    });

    test('falls back when the device language is not shipped', () async {
      final localization = GPLocalization(store: GPInMemoryLocaleStore());

      await localization.init(deviceLocale: const Locale('ja'));

      expect(localization.locale, GPLocale.fallback);
    });

    test('has usable strings before init runs', () {
      // A widget built during bootstrap must not meet a null locale.
      expect(GPLocalization(store: GPInMemoryLocaleStore()).current.root.bottomNav.home, isNotEmpty);
    });
  });

  group('GPLocalization.changeLocale', () {
    test('swaps the strings, notifies, and persists', () async {
      final store = GPInMemoryLocaleStore();
      final localization = GPLocalization(store: store);
      await localization.init(deviceLocale: const Locale('en'));

      var notifications = 0;
      localization.addListener(() => notifications++);

      await localization.changeLocale(GPLocale.vi);

      expect(localization.current.root.bottomNav.home, 'Trang chủ');
      expect(notifications, 1);
      expect(await store.read(), GPLocale.vi, reason: 'the choice must survive a restart once a real store is wired in');
    });

    test('re-picking the language already chosen does not notify', () async {
      final localization = GPLocalization(store: GPInMemoryLocaleStore(initial: GPLocale.vi));
      await localization.init();

      var notifications = 0;
      localization.addListener(() => notifications++);

      await localization.changeLocale(GPLocale.vi);

      expect(notifications, 0, reason: 'a no-op change must not repaint five live tab branches');
    });

    test('choosing the device language explicitly still notifies', () async {
      // The device is Vietnamese, the user taps Vietnamese: same strings, but the choice is now theirs and must be persisted.
      final store = GPInMemoryLocaleStore();
      final localization = GPLocalization(store: store);
      await localization.init(deviceLocale: const Locale('vi'));

      var notifications = 0;
      localization.addListener(() => notifications++);

      await localization.changeLocale(GPLocale.vi);

      expect(notifications, 1);
      expect(await store.read(), GPLocale.vi);
    });
  });
}
