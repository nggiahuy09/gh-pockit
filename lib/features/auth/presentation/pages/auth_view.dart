import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/pop_or_go.dart';
import '../../../../app/router/routes.dart';
import '../../../../core/error/failure_extension.dart';
import '../../../../core/localization/localization_scope.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/form_failure_banner.dart';
import '../../../../core/widgets/text_field.dart';
import '../../domain/entities/auth_credentials.dart';
import '../auth_form_field_enum.dart';
import '../auth_form_mode_enum.dart';
import '../bloc/auth_form_bloc.dart';

final class AuthView extends StatelessWidget {
  const AuthView({super.key});

  void _handleSucceeded(BuildContext context, AuthFormState state) {
    final viewLocale = context.l10n.auth;
    // Lets a password manager offer to save what was just accepted.
    TextInput.finishAutofillContext();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.isSignUp ? viewLocale.signedUp : viewLocale.signedIn)));
    context.popOrGoNamed(RouteNames.settings);
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<AuthFormBloc, AuthFormState>(
    listenWhen: (prev, next) => !prev.isSucceeded && next.isSucceeded,
    listener: _handleSucceeded,
    builder: (_, state) => Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), tooltip: context.l10n.auth.close, onPressed: () => context.popOrGoNamed(RouteNames.settings)),
      ),
      body: _AuthForm(state: state),
    ),
  );
}

final class _AuthForm extends StatefulWidget {
  const _AuthForm({required this.state});

  final AuthFormState state;

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

final class _AuthFormState extends State<_AuthForm> {
  final _emailFocus = FocusNode(debugLabel: 'email');
  final _passwordFocus = FocusNode(debugLabel: 'password');

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _handleFailure(AuthFormState state) {
    // Focus the refused field, so a screen reader reads its error (ADR-0016).
    switch (state.failedField) {
      case AuthFormField.email:
        _emailFocus.requestFocus();
      case AuthFormField.password:
        _passwordFocus.requestFocus();
      case null:
        break;
    }
  }

  void _handleEmailChange(String email) => context.read<AuthFormBloc>().add(AuthFormEmailChangeEvent(email));

  void _handlePasswordChange(String password) => context.read<AuthFormBloc>().add(AuthFormPasswordChangeEvent(password));

  void _handlePasswordVisibilityToggle() => context.read<AuthFormBloc>().add(const AuthFormPasswordVisibilityToggleEvent());

  void _handleModeChange(AuthFormMode mode) => context.read<AuthFormBloc>().add(AuthFormModeChangeEvent(mode));

  void _handleSubmit() => context.read<AuthFormBloc>().add(const AuthFormSubmitEvent());

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final viewLocale = locale.auth;
    final colors = context.colors;
    final spacing = context.spacing;
    final text = context.text;
    final state = widget.state;
    final failure = state.failure;
    final failedField = state.failedField;
    final isSignUp = state.isSignUp;
    final isEnabled = !state.isSubmitting;

    return BlocListener<AuthFormBloc, AuthFormState>(
      listenWhen: (prev, next) => next.failure != null && next.failure != prev.failure,
      listener: (_, state) => _handleFailure(state),
      child: AutofillGroup(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(spacing.lg, spacing.sm, spacing.lg, spacing.lg),
          children: [
            Text(isSignUp ? viewLocale.signUpTitle : viewLocale.signInTitle, style: text.headlineMedium.copyWith(color: colors.onBackground)),
            SizedBox(height: spacing.sm),
            Text(isSignUp ? viewLocale.signUpLead : viewLocale.signInLead, style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant)),
            SizedBox(height: spacing.lg),
            GPTextField(
              autofillHints: const [AutofillHints.email],
              focusNode: _emailFocus,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              errorText: failedField == AuthFormField.email ? failure?.getMessage(locale) : null,
              hintText: viewLocale.emailHint,
              initialValue: state.email,
              label: viewLocale.email,
              autocorrect: false,
              enabled: isEnabled,
              onChanged: _handleEmailChange,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            if (state.isEmailTaken)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: GPButton(variant: GPButtonVariant.text, label: viewLocale.signInWithThisEmail, onPressed: () => _handleModeChange(AuthFormMode.signIn)),
              ),
            SizedBox(height: spacing.md),
            GPTextField(
              autofillHints: [if (isSignUp) AutofillHints.newPassword else AutofillHints.password],
              focusNode: _passwordFocus,
              trailing: IconButton(
                onPressed: isEnabled ? _handlePasswordVisibilityToggle : null,
                tooltip: state.isPasswordVisible ? viewLocale.hidePassword : viewLocale.showPassword,
                iconSize: 20.0,
                color: colors.onSurfaceVariant,
                icon: Icon(state.isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              ),
              textInputAction: TextInputAction.done,
              errorText: failedField == AuthFormField.password ? failure?.getMessage(locale) : null,
              helperText: isSignUp ? viewLocale.passwordHelper(AuthCredentials.passwordMinLength) : null,
              initialValue: state.password,
              label: viewLocale.password,
              autocorrect: false,
              enabled: isEnabled,
              obscureText: !state.isPasswordVisible,
              onChanged: _handlePasswordChange,
              onSubmitted: (_) => _handleSubmit(),
            ),
            // Only a failure no field owns.
            if (failure != null && failedField == null) ...[
              SizedBox(height: spacing.md),
              GPFormFailureBanner(message: failure.getMessage(locale)),
            ],
            SizedBox(height: spacing.lg),
            GPButton(label: isSignUp ? viewLocale.signUp : viewLocale.signIn, expanded: true, isLoading: state.isSubmitting, onPressed: _handleSubmit),
            SizedBox(height: spacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(isSignUp ? viewLocale.haveAccount : viewLocale.noAccount, style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant)),
                GPButton(
                  variant: GPButtonVariant.text,
                  label: isSignUp ? viewLocale.signIn : viewLocale.signUp,
                  onPressed: isEnabled ? () => _handleModeChange(isSignUp ? AuthFormMode.signIn : AuthFormMode.signUp) : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
