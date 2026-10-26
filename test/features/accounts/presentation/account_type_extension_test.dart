import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/presentation/account_type_extension.dart';

const _locales = <GPLocaleBase>[GPLocaleEn(), GPLocaleVi()];

void main() {
  test('every account type has a title in every language we ship', () {
    // The compiler already demands every case in both locales; this catches a getter that returns ''.
    for (final locale in _locales) {
      for (final type in AccountType.values) {
        expect(type.getTitle(locale), isNotEmpty, reason: '${type.storageValue} has no title in ${locale.locale.languageCode}');
      }
    }
  });

  test('no two types share a title within a language', () {
    for (final locale in _locales) {
      final titles = AccountType.values.map((type) => type.getTitle(locale)).toList();
      expect(titles.toSet(), hasLength(titles.length), reason: 'duplicate title in ${locale.locale.languageCode}');
    }
  });

  test('the two languages actually differ', () {
    expect(AccountType.eWallet.getTitle(const GPLocaleEn()), 'E-wallet');
    expect(AccountType.eWallet.getTitle(const GPLocaleVi()), 'Ví điện tử');
  });

  test('no two types share an icon', () {
    expect(AccountType.values.map((type) => type.icon).toSet(), hasLength(AccountType.values.length));
  });
}
