import '../../features/auth/presentation/bloc/auth_bloc.dart';
import 'routes.dart';

/// The sign-in routes only; an unknown status lets them open (ADR-0041).
String? authRouteRedirect(AuthBlocState state) => switch (state) {
  AuthSignedInState() || AuthLocalOnlyState() => Routes.settings,
  AuthUnknownState() || AuthSignedOutState() => null,
};
