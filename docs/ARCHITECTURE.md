# DarsYar Native Architecture

> Status: Phase 2 design proposal. This document describes the intended architecture; it does not claim the native implementation exists yet.

## 1. Goals and constraints

- Native Android only: Kotlin, Jetpack Compose and Android platform APIs.
- Preserve the behavior contracts in `FEATURE_INVENTORY.md`.
- Keep the existing application ID: `com.mzarmehi1390.darsyar`.
- Keep the Flutter implementation on `main` until native parity and migration are verified.
- Keep domain rules independent from Compose, Android framework classes and Room.
- Use a modest number of modules with explicit dependency direction.
- Treat migration safety and Persian/RTL correctness as release-blocking requirements.
- Treat Liquid Glass as a measured graphics subsystem, not a per-screen decoration.

## 2. Proposed module graph

Initial modules:

```
:app
:core:common
:core:designsystem
:core:graphics
:core:database
:core:datastore
:core:testing
:feature:dashboard
:feature:planner
:feature:exams
:feature:settings
```

Rationale:
- Four feature modules correspond to the four existing product areas.
- Exams groups answer sheets, active exam taking, timer, scoring, result history and percentage calculator because these flows share domain entities and persistence.
- Backup/restore stays in settings initially; promote it to a separate module only if it gains an independent lifecycle/API.
- No network, onboarding or iOS module is justified by the audited product.
- Avoid a separate `:core:domain` module until genuinely shared domain contracts emerge. Each feature owns its domain contracts and models.

### Responsibilities

| Module | Owns | Must not own |
|---|---|---|
| `:app` | Application class, MainActivity, Hilt root, root navigation, app-level dependency assembly | Feature business rules, database SQL |
| `:core:common` | Small cross-feature primitives, clock/ID abstractions where tests need control, dispatchers | Android UI, feature models |
| `:core:designsystem` | Theme, typography, shapes, color/spacing/material tokens, reusable Compose controls | Feature navigation, persistence |
| `:core:graphics` | AGSL shaders, backdrop contract/provider, glass surfaces, rendering fallbacks and diagnostics | Product-specific state or database |
| `:core:database` | Room database, entities, DAOs, Room migrations, transaction boundaries | Compose, navigation |
| `:core:datastore` | Theme/animation preferences, typed preference repository, legacy preference reader | Feature collections and SQL |
| `:core:testing` | Shared fixtures/fakes only where multiple modules benefit | Production code |
| `:feature:dashboard` | Dashboard UI/state and read models for progress/shortcuts | Direct SharedPreferences access |
| `:feature:planner` | Task/session domain, scheduling rules, repository contracts/implementation and UI | Exam-specific models |
| `:feature:exams` | Exam sheets, answers, scoring, timer lifecycle, result history and UI | Planner scheduling |
| `:feature:settings` | Theme/animation settings UI and backup/restore workflows | Raw database access from composables |

Feature modules may initially contain `domain/`, `data/` and `presentation/` packages internally. Split those into additional Gradle modules only when compile-time isolation or build performance justifies the added complexity.

## 3. Dependency direction

```
:app
 ├── :feature:dashboard
 ├── :feature:planner
 ├── :feature:exams
 ├── :feature:settings
 ├── :core:designsystem
 ├── :core:graphics
 ├── :core:datastore
 └── :core:database

:feature:* -> :core:common / :core:designsystem (presentation only)
:feature:* -> own domain contracts
:feature:* data -> :core:database
:app -> feature entry points and DI assembly
:core:* -X-> :feature:*
```

Rules:
1. Core modules never depend on feature modules.
2. Feature UI never depends on Room entities or DAO types.
3. Composables receive immutable state and event callbacks.
4. ViewModels coordinate user actions and collect repositories; domain rules remain pure Kotlin where practical.
5. Repository interfaces live with the owning feature's domain contract. Implementations live in that feature's data package and depend on database APIs.
6. Navigation route types are owned by the app navigation layer or exposed through small feature navigation APIs; feature domain code never imports Navigation Compose.
7. Hilt modules bind interfaces to implementations at the app composition boundary.
8. Avoid generic use-case classes for trivial pass-through CRUD. Introduce a use case when it represents a meaningful business operation or coordinates multiple repositories.

## 4. State and data flow

- UI state: immutable Kotlin data classes.
- UI events: explicit callbacks or sealed event types for complex flows.
- ViewModels: expose `StateFlow<UiState>`; use lifecycle-aware collection in Compose.
- One-time effects: a carefully scoped `Channel`/Flow or effect stream for navigation, snackbar and external file-picker actions. Do not encode one-time events as durable state flags.
- Repositories: expose Flow for observable collections and suspend functions for commands.
- Database writes: suspend functions; multi-entity operations use Room transactions.
- Time and ID generation: inject a clock/ID provider at business boundaries where deterministic tests matter.
- Dispatchers: inject or centralize only where needed; never block the main thread.

Typical path:

```
Compose event
  -> ViewModel command
    -> feature repository / domain operation
      -> Room DAO transaction
        -> Room Flow emission
          -> ViewModel StateFlow
            -> Compose recomposition
```

## 5. Navigation

Use type-safe Navigation Compose routes with Kotlin Serialization. The app shell owns the four primary destinations. Nested exam routes represent setup, saved exams, active exam and history as appropriate.

- Preserve root-tab selection behavior.
- Do not put mutable domain objects in navigation arguments; pass stable IDs.
- Resolve entities through repositories/ViewModels after navigation.
- Keep active exam state and timer restoration independent from transient composable lifetime.
- Handle process recreation and configuration changes explicitly.
- Use saved state only for small transient navigation/UI values; Room remains the source of truth for durable user data.

## 6. Persistence architecture

### Room owns structured user data

Proposed initial tables:
- `study_tasks`
- `study_sessions`
- `exam_sheets`
- `exam_sheet_answers` (answer and answer-key kind)
- `exam_marked_questions`
- `exam_results`
- `app_state` (singleton row: active exam ID and migration metadata)

Use stable string IDs to preserve imported IDs. Use local calendar dates as ISO date keys or epoch-day integers, not midnight UTC timestamps. Store exam completion instants as epoch milliseconds/Instant semantics.

### DataStore owns preferences

- Theme mode: system/light/dark.
- Animations enabled.
- Future small app preferences only.

The active exam ID is proposed for the Room `app_state` row, not DataStore, so migration and active-sheet recovery can be committed atomically with exam data.

### Repository rules

- No DAO access from Composables.
- Feature repositories map Room entities to domain models.
- Multi-table answer sheet mutations and deletion/result cleanup use explicit Room transactions.
- Deleting an exam sheet removes linked results by exam ID and preserves legacy name-based cleanup for records with null exam IDs.
- Keep backup serialization at a boundary independent of Room entity schema.

## 7. Backup and restore

- Import the existing v1 JSON schema.
- Parse and validate into an immutable typed snapshot before any write.
- Ask for explicit replacement confirmation.
- Replace all included feature collections in one Room transaction.
- Validate active exam ID and ensure at least one exam sheet exists.
- On any exception, the Room transaction rolls back.
- Never log backup contents.
- Export v1-compatible JSON until a new version is explicitly designed; if the schema changes, add an explicit version and retain a v1 importer.

## 8. Lifecycle and background work

The audited app has no background sync, server or scheduled remote work. Do not add WorkManager by default.

- Exam countdown uses a deadline/remaining-time model, not a coroutine loop tied to a composable.
- Persist enough timer state to recover correctly after process recreation if the existing behavior requires it; verify the original lifecycle contract before choosing whether active exams resume automatically.
- Use lifecycle-aware Flow collection.
- Use WorkManager only if a real deferrable background operation is introduced (for example, a user-requested export). Do not use it for a visible foreground countdown.

## 9. Error model

- Domain validation errors are explicit and user-presentable.
- Persistence failures are surfaced; no empty catch blocks.
- Import errors identify invalid sections without exposing private data.
- Corrupt legacy data must not be silently interpreted as an empty successful migration.
- Use structured logging for technical diagnostics without task titles, answers, backup payloads or other user content.

## 10. Quality gates

Every feature must provide:
- Unit tests for domain rules.
- Repository/database tests for persistence behavior.
- Compose UI tests for critical workflows and accessibility semantics.
- RTL and font-scale checks.
- A successful Android build and static analysis.

Graphics changes additionally require screenshot/visual checks and physical-device profiling. Performance claims require device, OS, build variant and measurement details.
