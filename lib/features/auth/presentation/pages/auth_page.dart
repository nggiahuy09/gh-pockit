import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth_form_mode_enum.dart';
import '../bloc/auth_form_bloc.dart';
import 'auth_view.dart';

final class AuthPage extends StatelessWidget {
  const AuthPage({super.key, this.mode = AuthFormMode.signIn});

  /// Where the form opens; the user can switch in place.
  final AuthFormMode mode;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AuthFormBloc(mode: mode),
    child: const AuthView(),
  );
}
