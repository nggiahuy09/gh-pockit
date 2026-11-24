part of 'locale_base.dart';

abstract class GPLocaleBaseAuth {
  const GPLocaleBaseAuth();

  String get signInTitle;
  String get signInLead;
  String get signUpTitle;

  String get signUpLead;

  String get email;
  String get emailHint;
  String get password;
  String passwordHelper(int minLength);
  String get showPassword;
  String get hidePassword;
  String get signIn;
  String get signUp;
  String get noAccount;
  String get haveAccount;
  String get signInWithThisEmail;
  String get close;
  String get signedIn;
  String get signedUp;
  String get syncTitle;
  String get syncSignedOutBody;
  String syncSignedInBody(String email);
}
