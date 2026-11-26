# AI Handoff — DarsYar Native Android Rebuild

## Current objective

Rebuild DarsYar as a fully native Android application in Kotlin + Jetpack Compose. This is a functional and architectural reconstruction, not a Flutter port or a visual prototype.

## Repository state

- Repository: https://github.com/Mzarmehi1390/DarsYar
- Default branch: `main`
- Audited base: `cb0e9affcf2486c42dd146a66044c0f5fd34ca40`
- Active work branch: `feat/native-android-rebuild`
- Original application ID: `com.mzarmehi1390.darsyar`
- Current production implementation on main is Flutter.
- Do not commit native work to `main` until a reviewed, tested PR is ready.

## Read these first

1. `docs/NATIVE_REBUILD_AUDIT.md`
2. `docs/FEATURE_INVENTORY.md`
3. `docs/REDESIGN_AUDIT.md`
4. `docs/LIQUID_GLASS_DESIGN_SYSTEM.md`
5. `docs/ARCHITECTURE.md`
6. `docs/MODULES.md`
7. `docs/DATA_MIGRATION.md`
8. `docs/LIQUID_GLASS_ENGINE.md`
9. `docs/DEPENDENCY_BASELINE.md`
10. `docs/BUILD_AND_RELEASE.md`
11. `docs/TESTING.md`
12. `docs/PERFORMANCE.md`
13. `README.md`

The first two documents describe the native migration baseline. The existing redesign docs describe current Flutter visuals and behaviors; they are references, not native architecture constraints.

## Non-negotiable product contracts

- Preserve every item in `docs/FEATURE_INVENTORY.md`.
- Android only; do not add iOS builds or Apple frameworks.
- Kotlin + Jetpack Compose only; no Flutter runtime, Dart, WebView or hybrid UI.
- Preserve application ID exactly.
- Do not delete the Flutter implementation until native feature parity and migration have been validated. Keep `main` as a recoverable source of truth.
- No destructive persistence migration. Preserve the v1 JSON backup importer.
- Persian/RTL, light/dark/system themes and reduced-motion preference must work.
- Liquid Glass must not be mislabeled: blur and opacity alone are not refraction. Prove backdrop sampling and fallbacks in a showcase first.
- Dense study content prioritizes legibility over material effects.
- Do not claim a build, test, performance number or device validation without actual evidence.

## Workflow

1. Inspect current branch and synchronize with latest main before starting a new stage.
2. Read the current phase docs and inspect relevant source files before changing them.
3. Implement a coherent, reviewable stage; avoid tiny cosmetic batches and avoid huge unvalidated rewrites.
4. Run relevant unit/integration/UI tests and static checks.
5. Inspect the diff and update docs to reflect what is actually implemented.
6. Commit focused changes to `feat/native-android-rebuild`; keep main stable.
7. Report exact commit, changed files, tests executed, outcomes, and remaining risks.
8. Do not claim continuous background work or work outside the active execution session.

## Phase status

- Phase 1 — Repository audit: initial audit and inventory documented in `docs/NATIVE_REBUILD_AUDIT.md` and `docs/FEATURE_INVENTORY.md`.
- Phase 2 — Architecture and technical design: proposal documented in `docs/ARCHITECTURE.md`, `docs/MODULES.md`, `docs/DATA_MIGRATION.md` and `docs/LIQUID_GLASS_ENGINE.md`.
- Phase 3 — Native project foundation: 10 modules, Compose entry point, Hilt application, CI, Room entities/DAOs, DataStore preference migration, typed domain models, entity mappers, transactional repository and initial scoring/planner/task/session rules are present. Exam domain also has immutable answer-sheet operations, deterministic exam-taking/timer transitions, and immutable result creation/recalculation/key/name synchronization, with unit tests. The app module has Core Library Desugaring enabled. CI has exposed and helped correct AGP 9 Kotlin plugin conflicts, dependency/API mismatches, DataStore migration API usage, Room imports, scoring-test expectations and compileSdk requirements. Android modules compile against API 37; app targetSdk remains 36. CI installs Android SDK Platform 37.0 and Build Tools 37.0.0.
- Phase 4 — Liquid Glass: not started; rendering approach remains documented only.
- Phase 5 — Core data/business logic: Room/DataStore foundations, exam scoring, answer-sheet mutation, exam-taking lifecycle, result synchronization, planner/task rules, transactional one-time Flutter SharedPreferences importer, v1 JSON backup codec, SAF backup UI and transactional restore are implemented with automated tests. Remaining work includes device verification of the exact legacy Flutter preference file/key format, end-to-end restore/export validation and complete feature wiring.
- Phase 6 — Feature screens: planner and dashboard UI foundations are present; full feature parity and screen-level tests remain outstanding.
- Phases 7–10: full test suite, device profiling and release artifacts remain outstanding.

## Important unresolved decisions

- AndroidX Lifecycle 2.11.1 requires compileSdk 37. The project and CI are now pinned to API 37.0 / Build Tools 37.0.0; targetSdk intentionally remains 36 until Android 17 behavior changes are separately reviewed and tested.
- Verify the assumed `FlutterSharedPreferences` file and `flutter.` key prefix against the exact locked plugin and a real installed Flutter build on-device. The importer is implemented and covered by Robolectric tests, but its source-file assumptions and DataStore theme/animation migration are not yet device-verified.
- Validate the existing transactional one-time import of tasks, sessions, exam sheets, results and active sheet against a real legacy installation; it keeps the legacy file untouched.
- Confirm release keystore continuity for in-place updates.
- Prove AGSL backdrop sampling architecture on supported Android versions.
- Validate final module graph and Room schema against implementation constraints. Current exam answer/key/marked collections are JSON columns for bounded records; revisit normalization after validating read/write patterns.
- Validate v1 backup export/import compatibility against real Flutter-generated fixtures and complete end-to-end restore testing.
- Add and verify Gradle wrapper scripts/JAR; current CI uses a provisioned Gradle 9.6.0 installation.
- Latest verified CI at `ac7de4a1575c2f75e1e7d61b6b0acd008c4d06cc` completed successfully (run `45872037155`): native Build/Test/Lint and debug APK upload all passed. Importer coverage now includes collision-safe historical result IDs, Dart-compatible percentage clamping, wrong-typed string fields, and non-string fallback behavior. The importer now also matches Flutter's exam-sheet defaults for missing/null IDs and names without rewriting explicit empty strings; device verification of the actual Flutter SharedPreferences format remains a release gate.

Do not guess these. Investigate and document decisions before implementation.


- Legacy planner date parity: task dueDate and session scheduledDate import accept ISO date-only and timestamp strings, normalize offset timestamps to UTC before extracting date, and ignore invalid optional values. Coverage includes lowercase `z`, compact `yyyyMMdd` dates, and offsets without a colon; this is targeted parity coverage rather than a claim to match every Dart parser edge case. Regression test: parsesLegacyTaskAndSessionIsoDatesLikeFlutterDateTimeTryParse.
- Legacy preference string reads now use the untyped SharedPreferences map to match Flutter's `stringValue` fallback: wrong-typed collection/active-exam values become null instead of throwing. Regression test: wrongTypedLegacyCollectionAndActiveExamKeysUseFlutterStringFallbacks. That regression also verifies a present wrong-typed current exams key does not resurrect stale legacy single-sheet answers. Result snapshot answer/key parsing also matches Flutter's independent 1..200 bound rather than clipping to the historical result's questionCount; covered by numericAndBooleanLegacyFieldsKeepDartTypeSemantics.

- Legacy result ID parity: Flutter preserves whitespace-only IDs because it checks `isNotEmpty`, not trimmed emptiness. The native importer now preserves those non-empty IDs while retaining collision-safe normalization; regression coverage includes whitespace-only, empty and missing IDs.


- Legacy task/session required-string parity: Flutter's `StudyTask.fromJson` and `StudySession.fromJson` preserve empty and whitespace-only `id`/`title` strings. The native importer now preserves these exact values instead of rejecting blank strings; missing and wrong-typed required fields still fail the transactional import. Regression test: taskAndSessionRequiredStringsPreserveFlutterEmptyAndWhitespaceValues.


- Dashboard refinement: one-pass bounded task aggregates, Flutter-equivalent primary quick actions and planner view-all affordance are implemented and tested. A parity audit then found the Room task query sorted by due date, unlike Flutter and the native task operations contract (append new tasks; preserve position when editing). The task DAO now reads insertion order, and repository updates existing task rows in place instead of REPLACE/reinsert; regression test `taskOrder_matchesFlutterAppendAndEditPreservesPosition` covers no-date/mixed-date insertion, editing, and appending.

- CI follow-up (`4d93f7f`, run `45885178699`): Gradle configuration stopped before compilation because the Kotlin Compose plugin marker `2.2.20` could not be resolved from the configured plugin repositories. The Compose Compiler plugin is version-coupled to Kotlin, so the version catalog was advanced together to the published patch release `2.2.21`; the next CI run is the verification gate. This does not establish a source-code failure in the task-ordering change; compilation and tests had not started.

- Exam timer UI efficiency: the one-second deadline refresh now runs only while the exam screen's lifecycle is `RESUMED`; it refreshes immediately on resume, then once per second while visible. The persisted wall-clock deadline remains authoritative while backgrounded, so this removes unnecessary background wakeups without pausing or extending an exam. The exams feature now declares `lifecycle-runtime-ktx` directly for `repeatOnLifecycle`.


- Small-screen and large-font resilience: Settings and study-statistics screens now use vertically scrollable content containers. Their previous fixed-height `Column` layouts could clip lower controls/content on short displays or with enlarged system font scales. This is a presentation-only change; persistence, calculations and navigation contracts are unchanged.
