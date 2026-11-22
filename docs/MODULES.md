# DarsYar Native Module Boundaries

> Proposed Phase 2 module plan. No module in this document is claimed to have been implemented yet.

## Initial Gradle modules

| Gradle path | Package namespace suggestion | Purpose |
|---|---|---|
| `:app` | `com.mzarmehi1390.darsyar` | Android app entry, DI composition, root navigation |
| `:core:common` | `com.mzarmehi1390.darsyar.core.common` | Minimal shared Kotlin primitives |
| `:core:designsystem` | `com.mzarmehi1390.darsyar.core.designsystem` | Compose theme and reusable controls |
| `:core:graphics` | `com.mzarmehi1390.darsyar.core.graphics` | AGSL, glass material and fallback renderer |
| `:core:database` | `com.mzarmehi1390.darsyar.core.database` | Room entities, DAOs, database and SQL migrations |
| `:core:datastore` | `com.mzarmehi1390.darsyar.core.datastore` | DataStore preferences and legacy preference access |
| `:core:testing` | `com.mzarmehi1390.darsyar.core.testing` | Shared fixtures/fakes for tests |
| `:feature:dashboard` | `com.mzarmehi1390.darsyar.feature.dashboard` | Dashboard state and presentation |
| `:feature:planner` | `com.mzarmehi1390.darsyar.feature.planner` | Tasks, sessions, calendar and weekly planning |
| `:feature:exams` | `com.mzarmehi1390.darsyar.feature.exams` | Answer sheets, exam timer, scoring, history |
| `:feature:settings` | `com.mzarmehi1390.darsyar.feature.settings` | Preferences UI and backup/restore |

## Package structure inside a feature

Example for planner:

```
feature/planner/
  domain/
    model/
    repository/
    usecase/       # only meaningful multi-step operations
  data/
    local/
    mapper/
    repository/
  presentation/
    navigation/
    screen/
    component/
    state/
    viewmodel/
```

Do not create a separate Gradle module for each package. Use package boundaries first.

## Public API rules

- Export only feature entry composables and navigation route definitions that app must know.
- Keep internal DAO/entity and implementation classes internal to their owning modules where Kotlin visibility permits.
- Do not leak Room entities through public repository APIs.
- Do not leak Compose types into domain contracts.
- Avoid cross-feature imports. Shared dashboard aggregates should use a small read-only contract or app-level aggregator, not import planner implementation classes.
- Do not add a shared "god domain" module containing every model.

## Build and dependency conventions

- Root plugin and dependency versions are centralized in `gradle/libs.versions.toml`.
- Prefer convention plugins in `:build-logic` only after the initial module conventions are clear; do not introduce custom Gradle build logic for one or two trivial aliases.
- Use Kotlin DSL.
- Use Java/Kotlin toolchain alignment and a single documented JDK baseline.
- Use Android Lint and Detekt at the appropriate module scope.
- Keep Android-only dependencies out of pure domain source sets where possible.

## Dependency ownership

- Compose UI, Material 3 and Navigation Compose belong to app/feature presentation.
- Hilt runtime/compiler are applied to app and modules that declare injection points.
- Room runtime/compiler belong to database module.
- DataStore belongs to datastore module.
- AGSL resources and shader compilation belong to graphics module.
- Coroutines/Flow are used in repository and ViewModel contracts.
- Kotlin Serialization is used for typed navigation and backup DTOs only where useful; Room entities must not become backup schema by accident.
- Coil belongs only where remote/local image loading is actually required; do not add it preemptively if the app has no dynamic image content.

## Deliberately deferred modules

- `:core:network`: no network or cloud feature exists in the source-of-truth app.
- `:feature:onboarding`: no onboarding flow exists in the audited baseline.
- `:feature:statistics`: current statistics are tightly coupled to exam history and can remain inside exams until they grow independently.
- `:feature:backup`: backup currently belongs to settings and does not yet justify a separate module.
- `:core:performance`: profiling utilities and Baseline Profile source set can be added when the app module is ready; a permanent empty module is not justified.
