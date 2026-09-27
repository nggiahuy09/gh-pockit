import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/presentation/account_type_label.dart';

void main() {
  const locales = <GPLocaleBase>[GPLocaleEn(), GPLocaleVi()];

  test('every account type has a label in every language we ship', () {
    // The switch will not compile without a case and the getter will not compile until both locales implement it, so this mostly states the invariant — and
    // catches a getter that compiles while returning an empty string.
    for (final locale in locales) {
      for (final type in AccountType.values) {
        expect(type.labelIn(locale), isNotEmpty, reason: '${type.storageValue} has no label in ${locale.locale.languageCode}');
      }
    }
  });

  test('no two types share a label within a language', () {
    // W6's picker groups by type; two groups with the same heading would be two groups the user cannot tell apart.
    for (final locale in locales) {
      final labels = AccountType.values.map((type) => type.labelIn(locale)).toList();
      expect(labels.toSet(), hasLength(labels.length), reason: 'duplicate label in ${locale.locale.languageCode}');
    }
  });

  test('the two languages actually differ', () {
    // Guards against a copy-paste that leaves the Vietnamese file holding English — which compiles and passes both tests above.
    expect(AccountType.eWallet.labelIn(const GPLocaleEn()), 'E-wallet');
    expect(AccountType.eWallet.labelIn(const GPLocaleVi()), 'Ví điện tử');
  });
}
