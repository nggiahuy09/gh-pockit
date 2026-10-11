# ADR 0012 — A BLoC that watches a changing query: one restartable handler

## Status

Accepted — 2026-10-06 (W5 T3). First user: `TransactionListBloc`.

## Context

`TransactionListBloc` shows what `WatchTransactionsUseCase(query)` streams
(ADR-0013), and the query changes: a new filter replaces it, "load more" grows
its limit (ADR-0011). Whenever it changes, three things have to hold:

- **Exactly one watch is live.** A watch re-runs on every write to its table, so
  two live watches double the work, and the older one keeps writing into the
  state.
- **No row of the old query reaches the screen after the change.** A list that
  shows expenses for one frame after the user picked "income" is a bug nobody can
  reproduce.
- **An event that changes nothing leaves the watch alone.** A scroll listener sends
  "load more" on every frame near the end of the list; restarting the watch each
  time would cancel every query before it answers.

bloc runs each `on<E>` handler concurrently by default, so subscribing in the three
public handlers would stack watches. The usual answer is `restartable()` from
`bloc_concurrency`: one more package for one function, built on
`stream_transform`'s `switchMap`, which maps the event first — for a bloc, that
starts the next handler — and cancels the previous handler after.

## Decision

**The public handlers only decide; one private event subscribes.**

1. `Started`, `FilterChanged` and `LoadMoreRequested` stay synchronous. Each works
   out the next query, drops the event if it changes nothing, emits the new state
   at once — so the next event already sees it — and adds a private
   `_TransactionListWatchRequested(query)`.
2. Only that event's handler subscribes: `emit.forEach` over the use case's
   stream for `query`, registered with `restartable()` from
   `core/bloc/restartable.dart`. The transformer is our own: a `switchMap` that
   cancels the running handler **before** it starts the next one. It does not
   forward pause; bloc never pauses its event stream.
3. **Stale emissions are dropped.** The new state is emitted a microtask before the
   private event reaches the transformer, and in between the old watch can still
   deliver. The handler compares its event's query with `state.query` and ignores
   whatever no longer matches.
4. **Errors.** A `GPFailure` on the watch's error channel is kept beside the rows
   (`state.failure`), and the same watch clears it with its next emission:
   `emit.forEach` with an `onError` keeps listening after an error, and drift keeps
   a query stream registered after a failed run, so the next write to the table
   re-runs it. Any other error is a bug and is rethrown (ADR-0006).
5. `close()` needs nothing extra: bloc cancels the running handler, and with it the
   watch.

Any BLoC whose watch depends on parameters takes the same shape.

## Alternatives

**`bloc_concurrency`.** A dependency for one function, and the ordering above.

**A `StreamSubscription` per query, feeding data back as events.** Two more private
events, the same stale window, and cancellation written by hand where bloc already
owns it.

**One long-lived handler over a `StreamController` of queries, switch-mapped.** No
stale window, since swapping the query and cancelling the watch happen in one
synchronous step. Rejected: queries would travel on a channel beside the events,
invisible to `BlocObserver`, with a controller to close by hand.

**Restart on every event.** A scroll listener would cancel each query before it
answers.

## Consequences

Positive:

- One live watch per BLoC, cancelled before the next one starts; tests pin the
  order with a fake repository.
- No new dependency.

Negative:

- About thirty lines of stream code to own, with tests of their own.
- The private event shows up in `BlocObserver` logs.
- The stale check relies on `TransactionQuery` value equality, which ADR-0011
  already requires.
