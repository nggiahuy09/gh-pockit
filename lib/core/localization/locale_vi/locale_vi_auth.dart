part of 'locale_vi.dart';

final class GPLocaleViAuth implements GPLocaleBaseAuth {
  const GPLocaleViAuth();

  @override
  String get signInTitle => 'Đăng nhập để đồng bộ';

  @override
  String get signInLead => 'Dữ liệu trên máy vẫn giữ nguyên. Sau khi đăng nhập, Pockit sẽ sao lưu và đồng bộ sang các thiết bị khác.';

  @override
  String get signUpTitle => 'Tạo tài khoản';

  @override
  String get signUpLead => 'Dữ liệu đang có trên máy sẽ chuyển vào tài khoản mới, không mất gì.';

  @override
  String get email => 'Email';

  @override
  String get emailHint => 'ban@example.com';

  @override
  String get password => 'Mật khẩu';

  @override
  String passwordHelper(int minLength) => 'Ít nhất $minLength ký tự.';

  @override
  String get showPassword => 'Hiện mật khẩu';

  @override
  String get hidePassword => 'Ẩn mật khẩu';

  @override
  String get signIn => 'Đăng nhập';

  @override
  String get signUp => 'Tạo tài khoản';

  @override
  String get noAccount => 'Chưa có tài khoản?';

  @override
  String get haveAccount => 'Đã có tài khoản?';

  @override
  String get signInWithThisEmail => 'Đăng nhập với email này';

  @override
  String get close => 'Đóng';

  @override
  String get signedIn => 'Đã đăng nhập.';

  @override
  String get signedUp => 'Đã tạo tài khoản.';

  @override
  String get syncTitle => 'Đồng bộ nhiều thiết bị';

  @override
  String get syncSignedOutBody => 'Không bắt buộc. Đăng nhập để sao lưu và dùng trên nhiều máy.';

  @override
  String syncSignedInBody(String email) => 'Đã đăng nhập: $email';

  @override
  String get signOut => 'Đăng xuất';

  @override
  String get signOutBlockedTitle => 'Chưa thể đăng xuất';

  @override
  String signOutBlockedBody(int count) => 'Còn $count thay đổi chưa được sao lưu lên tài khoản. Đăng xuất bây giờ sẽ xóa chúng khỏi máy này. Hãy đăng xuất sau khi đồng bộ xong.';

  @override
  String get gotIt => 'Đã hiểu';

  @override
  String get signOutConfirmTitle => 'Đăng xuất khỏi Pockit?';

  @override
  String get signOutConfirmBody => 'Dữ liệu sẽ bị xóa khỏi máy này. Mọi thứ đã đồng bộ vẫn còn trong tài khoản; đăng nhập lại để tải về. Ngôn ngữ được giữ.';

  @override
  String get signedOut => 'Đã đăng xuất.';
}
