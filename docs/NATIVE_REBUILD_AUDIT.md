# Native Android Rebuild — Phase 1 Repository Audit

## Audit metadata

- Repository: `Mzarmehi1390/DarsYar`
- Audited branch: `main`
- Audited commit: `cb0e9affcf2486c42dd146a66044c0f5fd34ca40`
- Audit date: 2026-11-23
- Default branch: `main`
- Replacement branch: `feat/native-android-rebuild`
- Repository tree: 230 tracked entries; recursive tree was not truncated.
- Production Dart inventory: 65 files under `lib/`.
- Dart test inventory: 32 files under `test/`.

## Executive summary

The source of truth is a mature, feature-rich Flutter application, not a blank starter. It has a defined feature split, centralized design system, local persistence boundary, typed domain models, backup codec, exam lifecycle controllers and meaningful automated tests. The native replacement must preserve these contracts.

The current Android directory is only Flutter's Android host project. Its Kotlin `MainActivity.kt` is a Flutter embedding entry point, not a native Compose application. The app Gradle module applies `dev.flutter.flutter-gradle-plugin`, and settings include the Flutter SDK build. There is no native Compose feature architecture, Room schema, DataStore configuration, Hilt graph, Kotlin domain layer, or AGSL glass engine yet.

The repository is public and writable by the connected GitHub identity. The default branch currently has only `main`; the isolated replacement branch was created from the audited main head. No source files on `main` were changed during this audit.

## 1. Repository and CI baseline

- Latest main head at audit: `cb0e9aff`, commit message `chore(android): disable iOS launcher icon generation`.
- The commit's parent is `0c5c0388`; the recent history includes removal of iOS CI validation and cleanup of a one-time branch cleanup workflow.
- GitHub Actions run `45066399284` for `cb0e9aff` completed successfully.
- Its single job passed dependency installation, icon generation, Flutter analyze, Flutter tests, debug-signing validation, Android APK release build, Android App Bundle release build and artifact upload.
- This validates the existing Flutter pipeline only. It does not validate Kotlin, Compose, Room, DataStore, Hilt, AGSL or the proposed migration.
- Existing workflow: `.github/workflows/flutter-ci.yml`; it must be replaced by Android-native CI once the native project foundation is ready. Avoid breaking the current workflow before a native build can run.

## 2. Existing architecture assessment

### Current layering

- App shell and orchestration: `lib/app/`.
- Feature presentation/application/domain: `lib/features/`.
- Shared visual system: `lib/design_system/`.
- Persistence: `lib/darsyar_storage.dart` and `lib/app/data/darsyar_repository.dart`.
- Backup codec and scoring functions: root-level Dart files.
- State is largely orchestrated in a large stateful `DarsYarHome` widget, with smaller focused feature controllers and presentation widgets around it.

### Strengths to preserve

- Business logic has been extracted from widgets for scoring, planner calendar, task mutations, exam sheet operations, exam timer lifecycle and week-copy planning.
- The app repository creates a typed snapshot from persisted data.
- Backup decoding validates the payload before app state mutation.
- Legacy single-sheet data migration is guarded by key presence to avoid resurrecting stale legacy answers.
- Storage writes are serialized and attempt rollback on failure.
- Planner date logic explicitly documents the Saturday-Friday week convention.
- The design system distinguishes bounded refractive chrome from solid content surfaces to protect readability and scrolling performance.
- Automated tests cover many core rules and UI regressions.

### Architectural debt / native redesign opportunities

1. `DarsYarHome` is a large stateful orchestration unit (about 44 KB of source) coordinating feature state, persistence, navigation, dialogs and transient UI. Split responsibilities into feature ViewModels and narrowly scoped coordinators.
2. The existing mutable Dart models (`ExamSheet`, `StudyTask`) must become immutable Kotlin data models; mutations should be represented as repository operations.
3. The current SharedPreferences JSON storage has no database-level transaction across collections. Room should own relational entities and transactional operations.
4. The Flutter design-system package cannot be reused in Kotlin. Native rendering must be designed and tested independently.
5. Current Android SDK levels are inherited from the Flutter Gradle plugin rather than explicitly documented in app configuration.
6. The current manifest and Gradle setup are Flutter-specific and must be replaced rather than incrementally wrapped.
7. Current app state loading and save orchestration should become lifecycle-aware Flow/StateFlow pipelines with explicit loading, content and error states.

These are redesign targets, not claims that the existing app is unusable.

## 3. Functional and data findings

The detailed feature inventory is in [FEATURE_INVENTORY.md](FEATURE_INVENTORY.md). Critical contracts:

- Four primary destinations: dashboard, planner, exams/answer sheets, settings.
- Tasks and study sessions are local and shared across dashboard/planner.
- Calendar weeks begin Saturday; dates are local date-only occurrences, while weekday keys preserve legacy compatibility.
- Session overlap validation is date-aware, with weekday fallback for legacy records.
- Week copying generates new IDs and resets copied completion state.
- Exams support multiple answer sheets, 1..200 questions, optional key, optional negative marking, answer review marks, active exam selection, timer lifecycle and history.
- Wrong answers deduct one third of a correct answer when negative marking is enabled.
- Unkeyed questions are excluded from the score denominator; no key means no percentage.
- Changing a key later recalculates linked results, including the legacy name-based association fallback.
- JSON backup is schema version 1 and includes tasks, sessions, exams, results and active exam ID.
- Existing settings include theme mode and animation preference.

## 4. Persistence and migration risks

### Existing storage keys

Feature collections:
- `darsyar.tasks`
- `darsyar.studySessions`
- `darsyar.results`
- `darsyar.exams`
- `darsyar.activeExamId`

Legacy single-sheet fields:
- `darsyar.answers`
- `darsyar.answerKey`
- `darsyar.marked`
- `darsyar.count`

Preferences:
- `darsyar.themeMode`
- `darsyar.animationsEnabled`

Current collection values are JSON strings in Flutter SharedPreferences. The Android plugin commonly stores these in the app's `FlutterSharedPreferences` file with a `flutter.` key prefix; this must be verified against the exact locked `shared_preferences_android` version and a real install before implementing the one-time reader. Do not assume the Dart logical key equals the raw Android SharedPreferences key.

### Required migration approach

- Keep the same application ID and preserve the app's signing identity for in-place upgrade scenarios.
- Before replacing Flutter dependencies, capture a known-good backup fixture from the current v1 JSON format and create fixtures for every legacy key layout.
- Read legacy preferences without mutating them.
- Decode and validate all sections before writing any native records.
- Perform inserts and migration marker update in a Room transaction (or a transactionally safe migration coordinator). Do not mark migration complete before Room commit succeeds.
- Preserve the original Flutter preferences until a later version has passed migration verification and the user has a recovery path.
- Migration must be idempotent. If the process is interrupted before commit, rerun safely.
- Do not silently replace non-empty native tables with legacy data.
- Preserve backup schema v1 import; native export should either remain v1-compatible or introduce an explicit versioned format with a documented v1 importer.
- Verify local date parsing, time-zone behavior, IDs, answer maps, marked question sets, active exam and optional fields.

### Main risk

The current app is local-only, so there is no server-side recovery. A migration defect could permanently lose the user's only copy of their tasks, plans, answers and history. Migration must be treated as a release-blocking feature.

## 5. Native rendering feasibility and risk

The target architecture calls for Compose + AGSL + graphics layers + RenderEffect. These APIs do not provide a universal, automatic "sample any arbitrary composable behind this node" primitive.

- `RuntimeShader` / AGSL is available from Android 13 (API 33); older supported devices need a real fallback.
- `RenderEffect` is available from Android 12 (API 31); its availability does not itself imply backdrop capture.
- A shader can sample explicitly supplied shader/image inputs. It must not be described as backdrop refraction if it only samples a static tint or applies blur.
- Compose offscreen/layer APIs can isolate and render content, but a capture-and-feed design needs explicit ownership, invalidation, bounds, memory limits and lifecycle handling.
- The native engine should distinguish true sampled-background material from a non-refraction fallback. Use a shared backdrop provider/capture boundary only where the scene can safely supply the background image.
- Start with a small showcase scene that demonstrates the actual supported rendering path and fallback behavior before applying glass to production screens.
- Dense study content should remain on solid, high-contrast surfaces. Reserve refractive material for navigation, bounded controls and selected focal surfaces.

A technical spike must prove the proposed backdrop pipeline on target Android versions and physical hardware before the design system is considered validated.

## 6. Android platform baseline

Confirmed:
- Application ID / namespace: `com.mzarmehi1390.darsyar`.
- Existing display label: `درس‌یار`.
- Existing version: `1.0.0+1`.
- Existing launcher branding assets under `assets/branding/`.
- Android-only replacement is the target.

Not yet confirmed:
- Explicit native minSdk, compileSdk and targetSdk.
- Required device/API support matrix.
- Native signing configuration continuity and availability of the original release keystore in the build environment.
- Exact Android SharedPreferences raw key names on an installed release build.

Do not invent these values. Resolve and document them in Phase 2/3.

## 7. Proposed native architecture direction (to be finalized in Phase 2)

A feature-first modular architecture is appropriate, but the initial module graph should remain lean:

- `:app`: application composition, activity, DI entry point and root navigation.
- `:core:common`: result/error primitives, dispatchers, clock/ID abstractions only where needed.
- `:core:designsystem`: tokens, typography, theme and reusable Compose components.
- `:core:graphics`: glass material, backdrop contract, AGSL shaders and fallback rendering.
- `:core:database`: Room database, entities, DAOs and migrations.
- `:core:datastore`: DataStore preferences and legacy preferences reader.
- `:core:domain`: shared domain contracts only if cross-feature reuse justifies it.
- Feature modules: dashboard, planner, exams (including answer sheets/history/timer), settings/backup.
- `:core:testing`: reusable fixtures and test utilities when duplication justifies it.

Avoid creating empty `:network` or `:onboarding` modules without actual product requirements. There is no network feature or onboarding flow in the audited baseline. A dedicated backup module is optional; backup can initially remain under settings until a real module boundary emerges.

Dependency direction: feature UI -> feature domain contracts; feature data -> domain contracts + database; app assembles implementations. Core must not depend on feature modules. The final graph and Room schema will be recorded in Phase 2 architecture decisions.

## 8. Audit exit criteria

- [x] Repository metadata, default branch and latest commit verified.
- [x] Full recursive repository tree retrieved without truncation.
- [x] Production Dart and test file counts and paths inventoried.
- [x] Product feature contracts cross-checked against README, existing redesign audit, domain models, controllers and screen implementations.
- [x] Persistence keys, legacy single-sheet migration and backup schema inspected.
- [x] Android host configuration and CI workflow inspected.
- [x] Latest Flutter CI run checked at the audited commit.
- [x] Isolated native rebuild branch created.
- [ ] Exact raw Flutter SharedPreferences encoding verified on an installed build.
- [ ] Physical-device visual and behavior baseline captured.
- [ ] Phase 2 architecture and decision records approved.

The remaining unchecked items require a device/build environment and belong in the next validation/design work; they are not silently assumed complete.
