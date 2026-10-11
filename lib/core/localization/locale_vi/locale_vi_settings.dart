part of 'locale_vi.dart';

final class GPLocaleViSettings implements GPLocaleBaseSettings {
  const GPLocaleViSettings();

  @override
  String get title => 'Cài đặt';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get debugTitle => 'Gỡ lỗi';

  @override
  String get debugAddSample => 'Thêm giao dịch mẫu';

  @override
  String get debugSampleAdded => 'Đã thêm giao dịch mẫu.';

  @override
  String get debugSampleAccountName => 'Ví mẫu';

  @override
  String get debugSampleNote => 'Giao dịch mẫu';

  @override
  String get debugSeedDataset => 'Nạp bộ dữ liệu mẫu';

  @override
  String debugDatasetSeeded(int count) => 'Đã thêm $count giao dịch mẫu.';
}
