part of 'locale_vi.dart';

final class GPLocaleViTransactions implements GPLocaleBaseTransactions {
  const GPLocaleViTransactions();

  @override
  String get title => 'Giao dịch';

  @override
  String get typeExpense => 'Chi tiêu';

  @override
  String get typeIncome => 'Thu nhập';

  @override
  String get typeTransfer => 'Chuyển khoản';

  @override
  String get today => 'Hôm nay';

  @override
  String get yesterday => 'Hôm qua';
}
