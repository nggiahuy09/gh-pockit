import 'package:flutter_bloc/flutter_bloc.dart';

extension GPBlocExtension<E, S> on Bloc<E, S> {
  void maybeAdd(E event) {
    if (!isClosed) add(event);
  }
}
