part of 'locale_en.dart';

final class GPLocaleEnAuth implements GPLocaleBaseAuth {
  const GPLocaleEnAuth();

  @override
  String get signInTitle => 'Sign in to sync';

  @override
  String get signInLead => 'Everything on this device stays as it is. Once you sign in, Pockit backs it up and keeps your other devices in sync.';

  @override
  String get signUpTitle => 'Create an account';

  @override
  String get signUpLead => 'What is already on this device moves into your new account. Nothing is lost.';

  @override
  String get email => 'Email';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get password => 'Password';

  @override
  String passwordHelper(int minLength) => 'At least $minLength characters.';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Create account';

  @override
  String get noAccount => 'No account yet?';

  @override
  String get haveAccount => 'Already have an account?';

  @override
  String get signInWithThisEmail => 'Sign in with this email';

  @override
  String get close => 'Close';

  @override
  String get signedIn => 'Signed in.';

  @override
  String get signedUp => 'Account created.';

  @override
  String get syncTitle => 'Sync across devices';

  @override
  String get syncSignedOutBody => 'Optional. Sign in to back up your data and use it on more than one device.';

  @override
  String syncSignedInBody(String email) => 'Signed in as $email';
}
