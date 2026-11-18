import 'package:flutter_bloc/flutter_bloc.dart';

import '../extensions/stream_extension.dart';

EventTransformer<E> sequential<E>() =>
    (events, mapper) => events.asyncExpand(mapper);

/// A new event cancels the handler still running for the previous one (ADR-0012).
EventTransformer<E> restartable<E>() =>
    (events, mapper) => events.switchMap(mapper);
