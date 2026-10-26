# Coding Style Guide — Flutter + Bloc

This is the all-in-one edition: every rule is stated directly in Flutter/Dart terms. For a stack-neutral version with a Flutter appendix, see `coding-style-general.en.md`.

The guide is drawn from two production Flutter apps (2025–2026) and the team rules the author worked under. Code from October 2026 is the reference style.

## How to use this file

- This file is binding for code you write. When the project has its own rules (`CLAUDE.md`, `.ai/rules/`, `analysis_options.yaml`), those rules win on conflict, and this file fills the gaps.
- `XX` stands for the project's short type prefix (e.g. `XP`, `GP`). `<TICKET>` is the tracker id.
- Section W lists warnings, not bans. You report them and the user decides.
- New code follows this guide. Do not mass-migrate untouched code. When you change a file, you may bring the lines you touch into line.
- When a rule blocks the task, stop and raise it. Never work around it.

---

## 1. Mindset

- Write for the next change: the code should stay easy to maintain, and the next modification should be seamless and hard to get wrong.
- Cover edge cases: data eligibility, error states, empty states, and the message the user sees.
- Own the solution. "It works" or "it passes `flutter analyze`" is not done. Find and fix the root cause, and discuss it when unsure.
- Constraints exist to protect quality. Never get around them with tricks, hacks, or `// ignore:`.
- A boundary you cannot respect is a blocker: stop and raise it.

## 2. Working as an agent

- Before writing code, read the project's rule file for the area: architecture, state, API, widgets, localization, logging or caching. Read it fresh every time.
- The API spec (`.ai/specs/`) is the source of truth for wire format. Check every JSON key, `required` list, enum value and nullability against it. Never infer them from an existing model, a Dart field name, or a previous session.
  - Query only the part you need with `jq`.
  - If the spec looks stale, say so and ask for a refresh.
- Run `flutter analyze` on the whole project and fix errors first. Run `dart format` on the files you changed. Do not run `build_runner` or a full build unless asked.
- Trace a file's history with `git log --follow <file>`.
- Before making an existing class `final`, `base` or `sealed`, search for every `extends`, `implements` and `with` of it.

## 3. Architecture and layout

**Layers and call chain**

- Feature-first. Layer-first layouts (`lib/screens/`, `lib/services/`, `lib/models/`) are forbidden.
- Dependencies point one way: presentation → domain → data → external systems.
- **Call chain:** view → bloc → use case → repository → datasource.
  - A bloc never calls a repository method. It resolves the abstract repository only to build its use cases.
  - A use case calls only repositories, never another use case. If the logic spans two, the orchestrating use case calls the repositories directly.
  - A repository calls only datasources, never another repository.
  - If a problem cannot be solved inside these boundaries, it is a blocker: stop and raise it.
- **Three models:** remote model ≠ domain entity ≠ storage row. The repository and its mapper do the mapping. Resources and datasources never import or return entities.
- Repositories return `Either<XXException, T>`. Nothing throws past a repository.
- Shared and base types carry the project prefix (`XXUseCase`, `XXException`, `XXButtonFilled`). Feature types do not.

**Folder layout**

```
lib/
├── base/            # XX contracts: domain/, extensions/, define/constant/, localization/, gateway/
├── di/              # di.dart (+ module/*.dart once it grows)
└── src/
    ├── features/<feature>/
    │   ├── data/
    │   │   ├── datasources/{remote,local}/   # *_datasrc.dart, models/*_model.dart, resource/*_resource.dart
    │   │   └── repositories/                 # *_repo_impl.dart, *_repo_mapper.dart
    │   ├── domain/{entities,repositories,usecases}/
    │   └── presentation/{blocs,views,widgets}/
    └── shared/      # widgets/, helpers/, loading/, modal/, snack_bar/, views/
```

- Do not create a folder for a single file. Keep the file in the parent folder.
- Barrel files: never import a barrel from a file that the same barrel exports. Exported files import their dependencies directly.

**File and class names**

| Component     | File                                  | Class                         |
| ------------- | ------------------------------------- | ----------------------------- |
| Bloc          | `<feature>_bloc.dart`                 | `OrderDetailsBloc`            |
| Event / State | `<feature>_event.dart` / `_state`     | `part of` the bloc file       |
| Page / View   | `<name>_page.dart` / `<name>_view`    | `OrderDetailsPage` / `…View`  |
| Widget        | `<name>_widget.dart`                  | `OrderCardWidget`             |
| Use case      | `<verb>_<noun>_uc.dart`               | `AcceptRideUseCase`           |
| Repo contract | `<name>_repo.dart`                    | `RideRepository`              |
| Repo impl     | `<name>_repo_impl.dart`               | `RideRepositoryImpl`          |
| Mapper        | `<name>_repo_mapper.dart`             | `extension …Mapper on …Model` |
| Datasource    | `<name>_remote_datasrc.dart`          | `RideRemoteDatasource`        |
| Model         | `<name>_model.dart` / `_models`       | `RideRemoteModel`             |
| Resource      | `<name>_resource.dart` / `_resources` | `GetRideResource`             |
| Shared enum   | `<feature>_<name>_enum.dart`          | `RideStatus`                  |
| Extension     | `<type>_extension.dart`               | `DateTimeExtension`           |

**DI**

- Datasources are registered by concrete type: `getIt.registerLazySingleton(RideRemoteDatasource.new)`.
- Repositories are registered by their abstract type: `getIt.registerLazySingleton<RideRepository>(RideRepositoryImpl.new)`.
- Resolve dependencies in field initializers. Always use the abstract type in `getIt.get<>()`, never the concrete one.
- DI modules import every type directly, never through a barrel. Concrete `_repo_impl.dart` files are never exported from barrels.
- Break a client ↔ token-provider cycle with a lazy factory.

**Bootstrapping a new project**, in this order:

1. `CLAUDE.md`, the `.ai/rules/` files, the agent skills, and a README in each empty folder.
2. The `XX` contracts:
   - a sealed `XXException` hierarchy;
   - `XXUseCase<Input, Output>` returning `Either`;
   - `XXLoggable.toLog()`;
   - `XXResource<T>` and `XXRestClient`, the only place a `DioException` becomes an `XXException`;
   - `XXTokenProvider`.
3. First tests that target concurrency: a single-flight token fetch, and a 401 that clears the cached token.
4. Features.

## 4. Naming

- **General**
  - Names describe the role, not the value: `labelColor`, `backgroundColor`.
  - No generic names: `value1`/`value2` become `primaryValue`/`secondaryValue`.
  - When a child entity is ambiguous across features, prefix the owning feature: `ProfileMerchantEntity`, `PaymentMerchantEntity`.
- **Booleans:** derived predicates are getters named `is/has/can/shows/requires…`: `bool get canViewRider => status.isOfferAccepted;`.
- **Use cases:** start with the verb: `AcceptRideUseCase` in `accept_ride_uc.dart`.
- **Mapping:**
  - model → entity: `toDomain()`;
  - entity → request model: `toModel()`;
  - enum from/to a wire string: `fromRemote(...)` / `toRemote()`.
- **Copies:** `withX(...)` changes one field; `copyWith(...)` changes several.
- **Named constructors** say the intent: `.initial`, `.empty`, `.fromProfile`, `factory X.fromException(...)`.
- **Callbacks and handlers:**
  - view callback methods are `_handleX` (`_handleAccept`);
  - bloc handlers are `_xHandler` (`_acceptHandler`), with the dispatcher named `_eventHandler`.
- **Events:** `{Noun}{Verb}Event`. Internal events are private: `_XResolveEvent`.
- **Enums:**
  - Values are camelCase.
  - Wire values (`snake_case`, `UPPER_SNAKE`) are mapped in the mapper and never leak into app code.
  - Generated files are exempt.

## 5. Classes and types

**Modifiers**

- **Concrete classes are `final class`, private ones included.** This covers views, pages, widgets, `State<T>` subclasses, blocs, entities, use cases, repository impls and resources.
- **Classes meant to be extended:**
  - the shared parent of several widgets → `abstract base class`, with `final class` children;
  - a concrete class that must also be extendable → `base class`. Its subclasses must be `base`, `final` or `sealed`;
  - event and state hierarchies → a `sealed` base with `final` subclasses, plus sealed intermediate groups;
  - two bloc scopes that share logic → `abstract base class OrdersBloc` with `final class ActiveOrdersBloc` and `final class HistoryOrdersBloc`;
  - repository and service contracts → `abstract class` or `abstract interface class`. Never `final`, because it blocks `implements` outside the library.
- Never mark `final` a class that tests fake through `implements` or `extends` from another library.

**Immutability**

- Entities and states are `@immutable`, with `Equatable`.
- Collections are private and exposed as `List.unmodifiable(_items)`. This does not apply to widgets.
- No public mutable fields. Externally wired callbacks come in through the constructor as private finals.

**Entities**

```dart
@immutable
final class OrderEntity with Equatable {
  const OrderEntity({required List<OrderItemEntity> items, required this.status, this.paidAt, required this.id, this.note, required this.totalMinor}) : _items = items;

  final List<OrderItemEntity> _items;
  final OrderStatus status;
  final DateTime? paidAt;
  final String id;
  final String? note;
  final int totalMinor;

  List<OrderItemEntity> get items => List.unmodifiable(_items);

  bool get isPaid => paidAt != null;

  bool get canRefund => status.isCompleted && isPaid;

  OrderEntity withNote(String? note) => OrderEntity(items: _items, status: status, paidAt: paidAt, id: id, note: note, totalMinor: totalMinor);

  @override
  List<Object?> get props => [_items, status, paidAt, id, note, totalMinor];
}
```

- **Rich entities, thin use cases.** Validation getters, `static const` limits and invariants live on the entity. Use `@nonVirtual` on rules that subclasses must not change.
- **Imports:** no package beyond `equatable` and `foundation`. Never import data models or generated types. Never construct entities inside widgets.
- **Clearing a nullable field** in `copyWith`: use `T? Function()?` or `ValueWrapper<T?>?`.
- **Narrowing nullability through a super parameter:** `const OrderLoadedState(OrderEntity super.order);`, where the base holds `OrderEntity?`.
- Model every field you read. Never dig into a `Map<String, dynamic>` with string keys.

**Enhanced enums**

```dart
enum PaymentStatus {
  approved(XXColorText.success, XXColorSurface.success, Remix.checkbox_circle_line),
  declined(XXColorText.danger, XXColorSurface.danger, Remix.close_circle_line),
  unknown(XXColorText.subtle, XXColorSurface.secondary, Remix.information_line);

  const PaymentStatus(this.labelColor, this.backgroundColor, this.icon);

  final Color backgroundColor;
  final Color labelColor;
  final IconData icon;

  static PaymentStatus fromRemote(String? value) => switch (value) {
    'APPROVED' => PaymentStatus.approved,
    'DECLINED' => PaymentStatus.declined,
    _ => PaymentStatus.unknown,
  };

  bool get isApproved => this == PaymentStatus.approved;

  String getTitle(XXLocaleBase locale) {
    final statusLocale = locale.payment.status;
    return switch (this) {
      PaymentStatus.approved => statusLocale.approved,
      PaymentStatus.declined => statusLocale.declined,
      PaymentStatus.unknown => statusLocale.unknown,
    };
  }

  String toRemote() => switch (this) {
    PaymentStatus.approved => 'APPROVED',
    PaymentStatus.declined => 'DECLINED',
    PaymentStatus.unknown => 'UNKNOWN',
  };
}
```

- **Constant properties** (colors, icons, wire keys) are constructor fields, never re-derived with a `switch` in a widget.
  - Name them by role.
  - Order them by the field-ordering rule, and keep the value argument lists in the same order.
  - A property is nullable only when a value really has no visual.
  - Parameters are positional by default, even when several share a type. Switch to named when there are more than three or any is optional.
- **User-facing text** is never a field. It comes from `String getX(XXLocaleBase locale)`:
  - `getTitle` for a label or chip, `getBody` for a paragraph, `getMessage` for an error or validation, `getLabel` for a form control. A suffix is added only when one enum needs several of a kind (`getShortTitle`).
  - Return `String?` only when a value really has no copy.
- **Exhaustive switches over closed sets**
  - Every `switch` over `this`, a sealed type or an enum is exhaustive, with no `_`, and its branches follow the declaration order.
  - The one exception is `fromRemote`, which ends with `_ => X.unknown`.
  - Every enum fed from an API declares `unknown` last.
- **Getters:** derived booleans are getters (`isApproved`). Prefer them to repeating `status == …` at call sites.
- **Member order:** values → const constructor → fields → `fromRemote` → boolean getters → `getTitle`/`getBody`/`getMessage`/`getLabel` → other methods (`toRemote`).
- **Placement:**
  - An enum used by one file goes at the end of that file.
  - An enum shared across a feature gets its own `domain/entities/<feature>_<name>_enum.dart`.
  - A domain enum imports only locale and constants. It is never placed in presentation just because a widget is its only consumer.

## 6. Functions

- Use guard clauses and early returns. Compute derived values first, then emit or return once.
- Use Dart 3 patterns rather than casts and `is` chains: switch expressions, `when` guards, object patterns (`case Right(:final value)`), `case final X x`, records.
- Return several values as a named record: `Future<({bool canProceed, String? otp})>`.
- Negation is `!x`, never `x == false`.
- Locals are `final` and untyped. If inference needs help, type the literal (`<OrderEntity>[]`), not the variable.
- **Single-use variables:** do not assign to a variable that is used once; inline the expression. Exceptions:
  - the variable shortens a line or clarifies a ternary or a `where`/`map` chain;
  - the `locale` / `viewLocale` bindings;
  - a use-case `input` that is also logged.
- **Null safety**
  - Write `x?.foo()`, not `if (x != null)`.
  - Never chain `!` and `?.`. Promote through a local: `final onEdit = this.onEdit; if (onEdit == null) return;`.
- **Parameters**
  - Exactly one parameter → positional. Named is forbidden.
  - More than three parameters, or two or more of the same type → named.
  - Widgets, views, pages and blocs → always named.
- No local or nested functions. Make them private methods.
- **Callbacks**
  - Invoke them with `.call()`: `onTap.call()`, `onChanged?.call(value)`.
  - Pass tear-offs directly: `InkWell(onTap: onCancel)`.
  - Exceptions to `.call()`: `emit(...)` and `useCase.execute(...)`.
- Use the project extensions (`mapNotNull`, `whereNotNull`, `nullIfEmpty`, `date`, `isAfterInDays`). Never write `where((e) => e != null)` or `whereType` tricks.
- Use expression bodies when short, including `Widget build(...) =>`.

## 7. Use cases

```dart
final class AcceptRideUseCase with XXUseCase<AcceptRideInput, RideEntity> {
  const AcceptRideUseCase(this._repository);

  final RideRepository _repository;

  @override
  Future<Either<XXException, RideEntity>> execute(AcceptRideInput input) => _repository.acceptRide(input.pickupEta, input.rideId);
}

@immutable
final class AcceptRideInput implements XXLoggable {
  const AcceptRideInput(this.pickupEta, this.rideId);

  final DateTime? pickupEta;
  final String rideId;

  @override
  Map<String, dynamic> toLog() => {if (pickupEta != null) 'pickup_eta': pickupEta?.toUtc().toIso8601String(), 'ride_id': rideId};
}
```

- **Dependencies:** the repository comes in through the constructor. Use cases are not registered in DI and never touch `getIt`.
- **The input class:**
  - is a named class, never a record;
  - sits at the end of the use-case file, unless repositories reuse it;
  - is immutable, without `Equatable`;
  - implements `XXLoggable`.

## 8. Bloc

**Files**

- `<feature>_bloc.dart` holds every import plus `part '<feature>_event.dart';` and `part '<feature>_state.dart';`.
- The event and state files are `part of` the bloc file. Consumers import only the bloc file.
- The bloc is declared `Bloc<FeatureEvent, FeatureState>`, never `Bloc<Object, …>`.

**Events**

- A `@immutable sealed class` base with `@immutable final class` subclasses, and no `Equatable`.

**States**

- `@immutable` with `Equatable`; `props` is `[...super.props, …]`.
- **Pick the pattern before writing a new bloc**, and ask when it is not obvious:
  - **Reconstruction** (the default): one `final` subclass per transition, and no `_copyWith`.
  - **Single-state:** only for field-heavy, multi-step forms. It uses one class, a private `_copyWith`, a `viewStatus`/`phase` (an enum, or a sealed type when a phase carries data), an `initial` constructor, bool convenience getters, and `ValueWrapper` for clearable fields.
- **Naming:**
  - `XInitState`;
  - `XLoadingState` when there is a single async source; otherwise action-prefixed: `XRefreshLoadingState`, `XSubmitLoadingState`;
  - `XLoadedState`, `XLoadErrorState`, `XChangedState`;
  - specific outcomes: `XAcceptedState`, `XAcceptConflictState`.
- Fields that every state shares live in the base class.
- When a listener matches three or more states of one category, add a sealed intermediate group.

**Registration**

- Register one `on<FeatureEvent>` that runs an exhaustive `switch (event)` and delegates to `_xHandler`s:

```dart
final class RideDetailsBloc extends Bloc<RideDetailsEvent, RideDetailsState> {
  RideDetailsBloc({required String rideId, RideEntity? ride}) : _rideId = rideId, super(RideDetailsInitState(ride)) {
    on<RideDetailsEvent>(_eventHandler, transformer: XXHelperBlocTransformer.getSequentialFunc());

    add(const RideDetailsRefreshEvent());
  }

  final _acceptRide = AcceptRideUseCase(getIt.get<RideRepository>());
  final _getRide = GetRideUseCase(getIt.get<RideRepository>());

  final String _rideId;

  Future<void> _eventHandler(RideDetailsEvent event, Emitter<RideDetailsState> emit) async {
    switch (event) {
      case RideDetailsRefreshEvent():
        await _refreshHandler(emit);
      case RideDetailsAcceptEvent(:final pickupEta):
        await _acceptHandler(pickupEta, emit);
    }
  }

  Future<void> _acceptHandler(DateTime? pickupEta, Emitter<RideDetailsState> emit) async {
    emit(RideDetailsAcceptLoadingState(state.ride));

    final input = AcceptRideInput(pickupEta, _rideId);
    final result = await _acceptRide.execute(input);
    if (isClosed) return;

    switch (result) {
      case Right(:final value):
        emit(RideDetailsAcceptedState(value));
      case Left(:final value) when value.isConflict:
        _logBusiness(input: input.toLog(), level: XXRemoteLogLevel.warn, exception: value, action: 'accept_ride');
        emit(RideDetailsAcceptConflictState(state.ride));
        maybeAdd(const RideDetailsRefreshEvent());
      case Left(:final value):
        _logBusiness(input: input.toLog(), exception: value, action: 'accept_ride');
        emit(RideDetailsAcceptErrorState(state.ride));
    }
  }

  // _refreshHandler …

  void _logBusiness({required Map<String, dynamic> input, XXRemoteLogLevel level = XXRemoteLogLevel.error, XXException? exception, required String action, String? reason}) {
    XXRemoteLogger().logBusiness(input: input, level: level, exception: exception, action: action, feature: 'ride_details', reason: reason);
  }
}
```

- **Transformers:**
  - `sequential` is the default for request events.
  - Events that need another transformer form their own sealed intermediate group, registered with its own `on<Group>`:
    - `debounce` (300 ms, distinct) for text input;
    - `restartable` for list loads;
    - `droppable` for toggles.
  - Never register both a base event and one of its subtypes: the handler would run twice.
- **Handler template:**
  1. emit a loading state that keeps the current data;
  2. build `input`;
  3. call `execute`;
  4. `if (isClosed) return;`;
  5. map the result: `fold` when both branches are simple, `switch` on `Right`/`Left` when a branch needs `when`.

**Rules**

- **Dependencies:**
  - Use cases are built in field initializers from `getIt.get<AbstractRepository>()`.
  - The constructor takes only UI or route inputs: ids, an initial entity, flags.
- **Adding events:**
  - Use `maybeAdd` after any `await`.
  - `add` is fine in synchronous code and in the constructor, which is where the bloc starts itself.
- **State access:**
  - Never type-check or cast `state` to reach subclass data. Pass that data through the event payload.
  - Never store a raw `XXException` in state. Map it to a typed failure entity, or extract the message.
- **Submits:**
  - Guard them with an in-flight flag (`_isSubmitting`).
  - To re-show an identical error, emit `XValidatingState` first. Never use counters.
- **Navigation:** the bloc emits a navigate state and the view's `BlocListener` routes. The bloc never calls the router.
- **Practices to apply whenever they fit,** without asking:

| Practice              | When                                                                                     |
| --------------------- | ---------------------------------------------------------------------------------------- |
| Persistent props      | 2+ states share non-null fields                                                          |
| Paginated list        | load-more or pull-to-refresh (append on load-more, keep the stale list on refresh error) |
| Debounce search       | text input drives a query                                                                |
| Navigation state      | the bloc decides when to route                                                           |
| Typed error hierarchy | 2+ kinds of error with different copy (`getMessage(locale)`)                             |
| Intermediate grouping | a `buildWhen`/`listenWhen` matches 3+ states                                             |
| Initialized static UI | the page needs non-null async-loaded data before it can render                           |
| Loading overlay       | a blocking operation must stop all interaction                                           |
| Button loading        | only the button shows a spinner (never combined with an overlay)                         |
| Snackbar from state   | non-blocking feedback, always shown from a listener                                      |
| Validating reset      | a repeated submit can emit an identical error                                            |

## 9. Views, widgets, localization

**Pages and views**

- A Page provides the `BlocProvider` and passes route params and callbacks. It has no UI.
- A View holds the layout, the `BlocBuilder`/`BlocListener`s and the navigation.

**Widgets**

- Use private widget classes in the same file, never `Widget _buildX()` methods.
- Callback types are `void Function()` and `void Function(T)`, never `VoidCallback` or `ValueChanged`.
- Constructors put `super.key` first, then follow the field-ordering rule. Call sites follow the declaration order.
- Use `const` wherever possible. Doubles carry `.0` (`16.0`).

**Design system**

- Search `shared/widgets/` for an `XX*` equivalent before using a raw Flutter widget (`Text`, `Divider`, `TextButton`, `GestureDetector`…).
- Use the color and text tokens. No hardcoded asset paths.

**Context**

- `context.read` is used only in one-shot callbacks (`onTap`, `onPressed`, `create`, lifecycle methods), never in `build` or in a `builder:`. The one exception is a `MaterialPageRoute` builder.
- In a builder, name the context `_` and dispatch through the outer `build` context.
- After an `await`, check `context.mounted` before calling `context.read`.
- When opening a modal with `BlocProvider.value`, extract the bloc first.

**Rebuilds and listeners**

- Rebuild granularly:
  - `BlocSelector` for a slice of the state;
  - `buildWhen`/`listenWhen` written as `(prev, next)` or `(_, next)`;
  - builders that `switch` exhaustively over the state.
- Keep the overlay listener separate from the navigation and snackbar listener (`MultiBlocListener`). Hide the overlay before navigating.

**Data shaping**

- Shape data before rendering: build one renderable list, keep one render path, base fallbacks on the normalized data, filter invalid values early, and call `.toList()` when you need indexing or `.length`.
- Every async screen has loading, error and empty states.
- **Stale-while-refresh:** when data exists, render it during a refresh. Pull-to-refresh awaits `bloc.stream.firstWhere((s) => s is XLoadedState || s is XLoadErrorState, orElse: () => bloc.state)`.

**Layout**

- Prefer `spacing:` on `Row` and `Column` to `SizedBox` gaps.
- Prefer `DecoratedBox`, `Padding`, `SizedBox` or `ColoredBox` to `Container`. Use `Container` only when you need several of its properties at once.
- Padding:
  - content padding is `EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0)`;
  - a bottom action block is `symmetric(horizontal: 24.0, vertical: 8.0)`, wrapped in `XXPlatformSafeAreaView`.
- A bottom action combined with keyboard input:
  - the scroll region and the action are siblings in a `Column`: `Expanded` for a page, `Flexible` for a sheet;
  - keep `resizeToAvoidBottomInset: true`;
  - never put the action in `Scaffold.bottomNavigationBar`.
- `XXPlatformSafeAreaView` wraps the whole page or the `Scaffold.body`.

**Localization**

- Strings are hand-written classes: a base contract plus `en` and `vi`.
  - All three are updated in the same change, with the same grouping and blank lines.
  - English is the source of truth, and Vietnamese is natural rather than literal.
  - Keys have semantic names, with paired `…Title` / `…Body`.
- In `build()`, bind `final locale = XXLocalization.instance.locale;` and then `final viewLocale = locale.<section>;`. Never chain both into one line.
- Never pass the `$`-prefixed generated locale classes around. Pass `XXLocaleBase`.
- A new nested section gets its own file. Its getter goes near the top of the parent class, mirrored in every language.

## 10. Data layer and caching

**Resources and datasources**

- **Resource:** one `XXResource<T>` per endpoint, holding the method, the relative path, the query/body and `parse`.
  - `parse` returns a model, never an entity and never a raw `Map`.
  - The log `description` carries ids only (see W4).
- **Datasource:**
  - one per source type, with one-line methods: `_client.request(GetRideResource(id), type: APIType.user)`;
  - lets errors propagate.

**Models**

- `@JsonSerializable(createToJson: false)`, with `@JsonKey(name: 'snake_case')` on every field.
- Files are named `*_model.dart` or `*_models.dart`, because `build.yaml` limits codegen to them.
- Never hand-edit a `.g.dart`; regenerate it.
- Request bodies keep a hand-written `toJson()` with collection-if (omit when null or empty).

**Mapper**

- Lives in `*_repo_mapper.dart`, beside the implementation.
- Normalization happens here and nowhere else: empty → `null`, lenient local dates, numbers through one helper.

```dart
extension RideRemoteModelMapper on RideRemoteModel {
  RideEntity toDomain([String? paymentAuthId]) => RideEntity(
    status: RideStatus.fromRemote(status),
    pickupAt: DateTime.tryParse(pickupAt ?? '')?.toLocal(),
    riderName: riderName?.nullIfEmpty(),
    paymentAuthId: paymentAuthId,
    fareMinor: XXHelperData.getInt(fare),
  );
}
```

**Repository**

```dart
@override
Future<Either<XXException, RideEntity>> getRide(String rideId) async {
  try {
    final model = await _remote.getRide(rideId);
    return Right(model.toDomain(await _local.getPaymentAuthId(rideId)));
  } on XXException catch (e) {
    return Left(e);
  } catch (e) {
    return Left(XXUnknownException(error: e));
  }
}
```

- `TimeoutException` maps to `XXNetworkException.timeout`. The repository decides whether a failure is retryable.
- Fan-out with `Future.wait` degrades per item. One failed lookup falls back for that item; it does not fail the whole list.
- Local state goes through a small local datasource (SharedPreferences or secure storage) with a key prefix.

**Request-level cache** (on a `lazySingleton` datasource)

- Allowed only when all four hold:
  1. the call is read-only;
  2. the value is effectively static within a session;
  3. it is called repeatedly with the same arguments;
  4. the arguments are small identifiers (no cursor, limit, search text or filter).

```dart
final Map<String, Future<StaffModel?>> _staffCache = {};

Future<StaffModel?> getStaff(String id, {String? locale}) {
  final key = '$id|$locale';
  return _staffCache.putIfAbsent(key, () async {
    try {
      return await _client.request(GetStaffResource(id: id, locale: locale), type: APIType.user);
    } catch (e) {
      _staffCache.remove(key);
      rethrow;
    }
  });
}
```

- No TTL. Expose `clearCache()` and call it on logout, account switch or the relevant mutation.
- Never cache status, balances, prices, user-mutable profiles, lists, searches or paginated results.
- No repository cache that duplicates a datasource cache. Extract a shared cache helper only at 5 or more cached methods.
- When unsure, do not cache.

## 11. Errors and logging

**Errors**

- **One sealed `XXException` hierarchy.** `XXRestClient` is the only place a `DioException` becomes an `XXException`, and it fills in the machine-readable fields.
- **Discriminate by code, not by exception subtype.**
  - `e.errorCode` goes to the logs, and may say `timeout`.
  - `e.serverErrorCode` drives the UI copy. It is `null` for client-side network codes, so the screen falls back to generic copy.
- Error codes are `snake_case` strings (`create_order_id_null`).
- **Exceptions stop at the bloc,** which maps them to a typed failure: `RideCompleteFailure.fromRemote(e.errorCode)` returns an enum with `getMessage(locale)`.
- **A conflict (409, `XXConflictException`, `e.isConflict`) is an outcome of its own:**
  - a dedicated state;
  - a `warn`-level log;
  - the idempotency key is released;
  - `maybeAdd(refresh)`.

**Logging**

- **Where:** `logBusiness` is called only from blocs, once per failure. Repositories and use cases never log.
- **What to log:**
  - a hardcoded failure code produced while validating a successful response;
  - a successful call whose null or empty result blocks the user;
  - silent blockers.
- **What not to log:**
  - generic catch-alls (the network interceptor already logs them);
  - relabeled network errors;
  - local input validation the user can see;
  - graceful degradation.
- **How:**
  - Pass `exception: e`, never `reason: e.errorCode`.
  - Log `input.toLog()`, where the local is always named `input`. When the input is a primitive, use a minimal map: `{'order_id': orderId}`.
  - Use a private `_logBusiness(...)` per bloc that fixes `feature`. `action`, `reason` and `exception` stay at the call site, in signature order.
- Logging money, PII, tokens or raw payloads is warning W4.

## 12. Concurrency and idempotency

- **Single-flight:** concurrent callers share one in-flight future (`_tokenFuture ??= () async { … }();`), and the future is cleared on 401.
- **In-flight guards** (`_isVerifying`, `_isSubmitting`) ignore duplicate taps.
- **Idempotency keys:**
  - The key is a SHA-256 of `jsonEncode([...payload parts])`.
  - The same payload on retry gives the same key; a changed payload gives a new key.
  - A conflict releases the key.

## 13. Formatting and ordering

**Lints and formatter**

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_relative_imports: true
    prefer_const_constructors: true
    prefer_const_constructors_in_immutables: true
    prefer_expression_function_bodies: false
    prefer_initializing_formals: false

formatter:
  trailing_commas: preserve
  page_width: 180
```

- Gates: `flutter analyze --fatal-infos` and `dart format`.
- Never silence `deprecated_member_use_from_same_package` at a call site. Fix the usage instead.
- Keep a call on one line until it passes 180 columns, then break it with a trailing comma.

**Imports and spacing**

- Imports come in two groups: `package:` first, then a blank line, then relative project imports through barrels (`widgets.dart`, `extensions.dart`, `domain.dart`, `constant.dart`, `helpers.dart`). Each group is sorted alphabetically.
- Leave a blank line after the loading `emit`, after a guard-return block, and between `part` directives.

**Field and parameter order:** group by type, and sort by name within a group:

1. Collections (`List`, `Map`, `Set`)
2. UI types (widgets, controllers, `FocusNode`, services)
3. User-defined classes (entities, blocs)
4. Enums
5. Complex built-in types (`DateTime`, `Duration`, `Stream`…)
6. Primitives, in the order `String` → `double` → `int` → `bool`
7. Callbacks, in the order `void Function()` → `void Function(T)` → `void Function(T1, T2)` → `T Function()` → `T Function(T)`

**Constructors**

- Parameters follow the declaration order, regardless of nullability.
- Call sites follow the constructor's order.
- Super fields come first.

**Class member order**

1. Constructors (default first)
2. Constants of the same type
3. Static methods returning the same type
4. Final fields from the constructor
5. Other static methods
6. Static properties and constants
7. Mutable properties: getter → private field → setter, with no blank lines between
8. Read-only properties (except `hashCode`)
9. Overrides
10. Operators (except `==`)
11. Methods (except `toString` and `build`)
12. `build`
13. `==`, `hashCode`, `toString`, diagnostics

## 14. Comments and docs

- Comments are in English.
- **Comment only what a normal read would not tell you:** the reason, a contract the signature cannot show, a magic value, or code that looks wrong on purpose.
  - Keep it to one line where possible.
  - No multi-paragraph `///` blocks, no history or ticket provenance, nothing a name already says.
- A TODO names the concrete missing piece: `// TODO: accept the offer via POST /rides/{id}/accept.`
- When code deliberately breaks a rule (e.g. a use case that cannot go through a repository), one comment at that spot says why.
- **Rule files** (`CLAUDE.md`, `.ai/rules/`): each rule states its reason and the consequence of breaking it, shows a short example, and points to a real `file:line`.

## 15. Tests and CI

**What to test**

- Test the risky paths first:
  - money limits and digit round-trips;
  - idempotency;
  - concurrency;
  - wire keys (`toJson()['sub_fee']`);
  - countdowns and deadlines;
  - a regression test for every bug you fix.

**Fakes**

- Use hand-written recording fakes that extend the abstract repository. No mocking library.

```dart
final class _RecordingOrderRepository extends OrderRepository {
  final List<String> _idempotencyKeys = [];

  XXException? nextFailure;

  List<String> get idempotencyKeys => List.unmodifiable(_idempotencyKeys);

  @override
  Future<Either<XXException, OrderEntity>> submit({required String idempotencyKey}) async {
    _idempotencyKeys.add(idempotencyKey);
    final failure = nextFailure;
    nextFailure = null;
    if (failure != null) return Left(failure);
    return const Right(OrderEntity.empty());
  }
}

final _repository = _RecordingOrderRepository();

void main() {
  setUpAll(() => getIt.registerLazySingleton<OrderRepository>(() => _repository));
  tearDownAll(getIt.reset);

  for (final method in const [PaymentMethod.card, PaymentMethod.qr]) {
    test('retrying the same $method payload keeps the idempotency key', () async { /* … */ });
  }
}
```

**Writing tests**

- Test names are behaviour sentences. A non-obvious `expect` carries a `reason:`.
- Data-driven cases loop over a `const` list.
- Drive blocs through `bloc.stream.firstWhere(...)` or `expectLater(bloc.stream, emitsInOrder([...]))`.
- When it is not obvious, a comment says why the test exists: `// Regression: …`, `// BLAST-RADIUS: pins current behaviour so changing it is a deliberate decision.`
- Tests import with `package:` URIs; `lib/` uses relative imports.

**CI**

- Flutter comes from `.fvmrc` (`flutter-version-file`). Run `flutter pub get --enforce-lockfile`.
- Analyze, format and test are independent steps (`if: ${{ !cancelled() && steps.deps.outcome == 'success' }}`), so one run reports every problem.
- Create `.env` from a committed `.env.example`.
- Use `concurrency` with `cancel-in-progress` per PR.
- Every non-obvious step carries a comment saying why.

## 16. Git

- **Branches and PRs**
  - One branch per ticket: `task/<TICKET>`.
  - One PR per ticket, squash-merged into the integration branch.
- **PR title:** `[<TICKET>] - <Capitalized imperative sentence>`, at most 72 characters. Non-ticket work uses `[Hotfix] - …`, `[CI] - …` or `[Base] - …`.
- **PR body** follows the repo template: Description, Type of change, Checklist.
- **Commits on the branch:** `type(scope): description`
  - No space before `(`. Lowercase, imperative, at most 72 characters. No body unless it is needed.
  - The scope is the feature in plain words: `(dispatch)`, `(hotel payment)`.
  - Common verbs: add, implement/impl, update, support, remove, handle, enhance.
  - A `fix` describes the symptom: `fix(hotel payment): cannot pay with personal booking`, `missing …`, `incorrect …`.
  - Types:
    - `feat`, `fix`, `test`, `ci`;
    - `refactor` (never `refact`);
    - `chore` for small polish, cleanup and dependencies;
    - `docs` for docs, rules and specs.
- Commit small and often.

---

## W. Warnings — report them; the user decides

These patterns are not banned. They are risky enough that the user wants to see every occurrence and decide.

**Protocol**

- **Scope:** the code you read or change for the current task. Do not sweep the whole repo unasked.
- **Do not act on them.** Do not fix them silently, and do not ignore them. Leave the code as it is unless the user asks, or the task is about that code.
- **New code:** do not introduce them. If the task seems to need one, say so before writing it.
- **Reporting:** end your response with a `⚠️ Warnings` section, one line per pattern per file:

```
⚠️ Warnings
- W2 Silenced catch — lib/.../token_hook.dart:42 — `catch (_) {}` hides refresh failures. Option: log the code and return a failure. Not changed.
- W1 Commented-out code ×3 — lib/.../order_bloc.dart:88-140 — old `on<>` registrations. Option: delete (git keeps the history). Not changed.
```

| ID  | Pattern                                                                                                 | Why it is risky                                                 | Usual option                                                      |
| --- | ------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | ----------------------------------------------------------------- |
| W1  | Commented-out code (dead `on<>` handlers, old DI registrations, disabled logging)                       | Rots and misleads readers and search; git already keeps history | Delete it, or restore it with a reason                            |
| W2  | Empty or silenced catch: `catch (_) {}`, or a catch whose logging is commented out                      | Failures vanish, and bugs surface far from the cause            | Log the code, and return or rethrow a typed failure               |
| W3  | `double` for money (amounts, fees, totals)                                                              | Rounding errors and lossy round-trips                           | `int` minor units or a decimal type; at minimum, guard with tests |
| W4  | Logging money amounts, PII (names, phones, emails, notes), tokens or raw payloads (`input: event.data`) | Leaks sensitive data into log storage                           | Log ids, lengths and codes only                                   |
| W5  | Copy-pasted parallel flows (e.g. `create_…` / `edit_…` / `redeclare_…` cloned with a renamed prefix)    | Every fix has to land N times, and the copies drift apart       | Extract the shared part; keep only real differences per flow      |
| W6  | Force-unwrapped lookups: `map[key]!`                                                                    | Crashes on a missing key                                        | Null-check into a local, or encode the guarantee in the type      |
| W7  | Files over 1,000 lines (blocs, repo impls)                                                              | Hard to review, a merge-conflict magnet, hides duplication      | Split by responsibility                                           |
