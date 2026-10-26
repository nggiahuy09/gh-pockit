import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_type_extension.dart';

void main() {
  test('every type has its own non-empty title in every language we ship', () {
    for (final locale in const <GPLocaleBase>[GPLocaleEn(), GPLocaleVi()]) {
      final titles = TransactionType.values.map((type) => type.getTitle(locale)).toList();

      expect(titles, everyElement(isNotEmpty), reason: locale.locale.languageCode);
      expect(titles.toSet(), hasLength(titles.length), reason: locale.locale.languageCode);
    }
  });

  test('the two languages actually differ', () {
    expect(TransactionType.transfer.getTitle(const GPLocaleEn()), 'Transfer');
    expect(TransactionType.transfer.getTitle(const GPLocaleVi()), 'Chuyển khoản');
  });
}
