# Adding a feature

The steps to add a feature to the foundation, using an illustrative
read-only "visits" list. **None of this code exists in the app**: it shows
the shape, the file locations and which infrastructure to call. Rules
behind each step are in [ARCHITECTURE.md](../ARCHITECTURE.md); the import
rules are enforced by `test/architecture/dependency_rules_test.dart`.

```text
lib/features/visits/
├── domain/
│   ├── entities/visit.dart
│   ├── repositories/visit_repository.dart
│   └── usecases/get_upcoming_visits.dart
├── data/
│   ├── dto/visit_dto.dart (+ .g.dart)
│   ├── mappers/visit_mapper.dart
│   ├── datasources/visit_remote_data_source.dart
│   └── repositories/visit_repository_impl.dart
├── presentation/
│   ├── controllers/upcoming_visits_controller.dart
│   └── screens/upcoming_visits_screen.dart
├── visits_providers.dart
└── visits_routes.dart
test/features/visits/ …   (mirrors the above)
```

## 1. Create the feature module

Create `lib/features/<feature>/` with `domain/`, `data/` and
`presentation/`. Name it after the business capability (`visits`,
`payments`), lowerCamelCase in code (`RouteModule.name`), snake_case in
file names. A feature may use another feature's **domain** only. If the
feature introduces a new kind of folder, add its import rules to
`test/architecture/dependency_rules_test.dart`.

## 2. Define domain entities

Pure Dart, shaped by the business, immutable, no JSON. Money is integer
paise, instants are UTC `DateTime`s, civil dates are dates
(`core/formatting/date_time_rules.dart`).

```dart
// domain/entities/visit.dart
final class Visit {
  const Visit({required this.id, required this.pickupAt, required this.totalPaise});
  final String id;
  final DateTime pickupAt; // UTC instant
  final int totalPaise;
}
```

Use Freezed (`freezed_annotation` only) when you need value equality and
`copyWith` on larger entities. Business-rule failures extend
`DomainFailure`.

## 3. Define repository contracts

An interface in the domain returning `Result`:

```dart
// domain/repositories/visit_repository.dart
abstract interface class VisitRepository {
  Future<Result<List<Visit>>> upcoming();
}
```

## 4. Create DTOs

Match the API exactly with `json_serializable` (or Freezed with JSON), then
run `make gen` and commit the generated files.

```dart
// data/dto/visit_dto.dart
@JsonSerializable()
final class VisitDto {
  const VisitDto({required this.id, required this.pickupAt, required this.totalPaise});
  factory VisitDto.fromJson(Map<String, dynamic> json) => _$VisitDtoFromJson(json);
  final String id;
  final String pickupAt; // ISO-8601 with offset
  final int totalPaise;
}
```

## 5. Implement mappers

Explicit functions; parse API formats with `ApiDateTime`. DTOs never leave
the data layer.

```dart
// data/mappers/visit_mapper.dart
Visit visitFromDto(VisitDto dto) => Visit(
  id: dto.id,
  pickupAt: ApiDateTime.parseInstant(dto.pickupAt),
  totalPaise: dto.totalPaise,
);
```

## 6. Implement data sources

Call `ApiClient` (never Dio), decode with a typed decoder, let errors
propagate as `AppException`s.

```dart
// data/datasources/visit_remote_data_source.dart
final class VisitRemoteDataSource {
  const VisitRemoteDataSource(this._api);
  final ApiClient _api;

  Future<List<VisitDto>> upcoming() async {
    final response = await _api.get(
      '/visits', // resolved under <API_BASE_URL>/api/v1
      query: {'status': 'upcoming'},
      decode: (json) => [
        for (final item in json! as List<Object?>)
          VisitDto.fromJson(item! as Map<String, dynamic>),
      ],
    );
    return response.data;
  }
}
```

Use `upload`/`download` for files, `ApiRequestOptions` for idempotency
keys, timeouts, retries and cancellation, and the pagination helpers for
lists.

## 7. Implement the repository

Wrap every operation in `guardResult`: it turns `AppException`s into typed
`AppFailure`s and reports unexpected errors.

```dart
// data/repositories/visit_repository_impl.dart
final class VisitRepositoryImpl implements VisitRepository {
  const VisitRepositoryImpl(this._remote, {required this.mapper, this.reporter});
  final VisitRemoteDataSource _remote;
  final ErrorMapper mapper;
  final ErrorReporter? reporter;

  @override
  Future<Result<List<Visit>>> upcoming() => guardResult(
    () async => [for (final dto in await _remote.upcoming()) visitFromDto(dto)],
    mapper: mapper,
    reporter: reporter,
  );
}
```

## 8. Create use cases where appropriate

Only when there is a business rule or several repositories to combine; a
pass-through use case adds nothing.

```dart
// domain/usecases/get_upcoming_visits.dart
final class GetUpcomingVisits {
  const GetUpcomingVisits(this._visits);
  final VisitRepository _visits;
  Future<Result<List<Visit>>> call() => _visits.upcoming();
}
```

Wire everything in `visits_providers.dart`, typed as interfaces:

```dart
final visitRepositoryProvider = Provider<VisitRepository>(
  (ref) => VisitRepositoryImpl(
    VisitRemoteDataSource(ref.watch(apiClientProvider)),
    mapper: ref.watch(errorMapperProvider),
    reporter: ref.watch(errorReporterProvider),
  ),
);
```

## 9. Create Riverpod controllers

One `Notifier`/`AsyncNotifier` per screen; it calls use cases or
repositories and exposes state. No business rules and no formatting in
widgets.

```dart
// presentation/controllers/upcoming_visits_controller.dart
final upcomingVisitsProvider =
    AsyncNotifierProvider<UpcomingVisitsController, List<Visit>>(
      UpcomingVisitsController.new,
    );

final class UpcomingVisitsController extends AsyncNotifier<List<Visit>> {
  @override
  Future<List<Visit>> build() async =>
      (await ref.watch(visitRepositoryProvider).upcoming()).getOrThrow();
}
```

The widget switches on the `AsyncValue` and renders every state explicitly
— loading, error (with `AppLocalizations.of(context).failureMessage(failure)`
and a retry that invalidates the provider), empty and data; never a silent
spinner. It formats values with `appFormattersProvider` (`instantDateTime`,
`rupees`).

Async safety in controllers and widgets:

- After every `await`, check `context.mounted` (widget) or `ref.mounted`
  (notifier) before touching context or state.
- Never drop a Future in a callback: `onTap: () => controller.save()` loses
  `save`'s errors. Make the handler `async`, `await` it and handle the failure.

## 10. Register routes

```dart
// visits_routes.dart
abstract final class VisitRoutes {
  static const upcoming = RouteDefinition(
    name: 'visits.upcoming',
    path: '/visits',
    access: AuthenticatedAccess(),
  );
  static const detail = RouteDefinition(
    name: 'visits.detail',
    path: ':visitId',
    parent: upcoming,
  );
}

final class VisitsRoutes extends RouteModule {
  const VisitsRoutes();
  @override
  String get name => 'visits';
  @override
  List<RouteBase> buildRoutes(RouteBuildContext context) => [
    VisitRoutes.upcoming.route(
      builder: (_, _) => const UpcomingVisitsScreen(),
      routes: [
        VisitRoutes.detail.route(
          builder: (_, state) => VisitDetailScreen(
            visitId: state.requirePathParameter('visitId'),
          ),
        ),
      ],
    ),
  ];
}
```

Add `VisitsRoutes()` to one list in `lib/app_routes.dart`:
`_sharedRouteModules` (both apps), `_userRouteModules` or
`_caretakerRouteModules` (one app only). Link
with `VisitRoutes.detail.location(pathParameters: {'visitId': id})`;
identity in the path, extras optional. Notification types the feature
handles go in `notificationRoutes` (`'visits.updated'`). Conventions:
[navigation.md](navigation.md).

## 11. Consume design-system components

Build screens only from `lib/shared/widgets/` (`PcButton`, `PcCard`,
`PcListGroup`, `PcEmptyState`, `PcTopAppBar`, …) and the theme
(`context.pc`, `PcSpacing`, `PcTypeScale`); no raw colors, sizes or new
components that the design system does not define
([design-system-mapping.md](design-system-mapping.md)). Every user-facing
string is an ARB message (`lib/core/l10n/README.md`); every interactive
element has a semantic label and the 48 px minimum target
(design-system-mapping.md, A14). Layouts adapt to the available space
(`LayoutBuilder`, `MediaQuery.sizeOf`), never to platform checks.

## 12. Add tests

Mirror the folders under `test/features/<feature>/` ([TESTING.md](../TESTING.md)):

- mappers and use cases: plain unit tests;
- data source: `FakeHttpAdapter` responses, including problem details
  (`respondProblem`);
- repository: success and every failure path (`isFailureOf<…>()`);
- controller: `createTestContainer` with a fake repository
  (`test/features/<feature>/fakes.dart`);
- screen: widget tests for loading, empty, error and data states, and
  semantics;
- routes: registration and guards with `RouterHarness`.

Then run `make gen format analyze test`.
