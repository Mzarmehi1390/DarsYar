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
- Phase 3 — Native project foundation: 10 modules, Compose entry point, Hilt application, CI, Room entities/DAOs, DataStore preference migration, typed domain models, entity mappers, transactional repository and initial scoring/planner/task/session rules are present. Exam domain now also has immutable answer-sheet operations, deterministic exam-taking/timer transitions, and immutable result creation/recalculation/key/name synchronization, with unit tests added for these rules. The app module was missing Core Library Desugaring even though the planner feature required it; this has been enabled in the app as well. CI has exposed and helped correct several issues: AGP 9 built-in Kotlin plugin conflict, unavailable Lifecycle 2.12.0 stable version, DataStore migration API usage, a missing Room DAO import, a scoring-test expectation mismatch, and a compileSdk mismatch caused by Lifecycle 2.11.1 requiring API 37. All Android modules now compile against API 37; app targetSdk remains 36. The workflow installs Android SDK Platform 37.0 and Build Tools 37.0.0. Latest run must be checked before claiming a green build.
- Phase 4 — Liquid Glass: not started; rendering approach remains documented only.
- Phase 5 — Core data/business logic: initial Room and DataStore foundations plus exam scoring, answer-sheet mutation, exam-taking lifecycle, result synchronization and planner/task rules are present. Room-backed lifecycle wiring, legacy user-data import and backup codec remain outstanding.
- Phase 6 — Feature screens: planner and dashboard UI foundations are present; full feature parity and screen-level tests remain outstanding.
- Phases 7–10: full test suite, device profiling and release artifacts remain outstanding.

## Important unresolved decisions

- AndroidX Lifecycle 2.11.1 requires compileSdk 37. The project and CI are now pinned to API 37.0 / Build Tools 37.0.0; targetSdk intentionally remains 36 until Android 17 behavior changes are separately reviewed and tested.
- Verify the assumed `FlutterSharedPreferences` file and `flutter.` key prefix against the exact locked plugin and a real installed Flutter build before enabling user-data import. The DataStore preference migration currently targets the conventional theme/animation keys but is not yet device-verified.
- Implement transactional one-time import of tasks, sessions, exam sheets, results and active sheet into Room; keep the legacy file untouched until parity is verified.
- Confirm release keystore continuity for in-place updates.
- Prove AGSL backdrop sampling architecture on supported Android versions.
- Validate final module graph and Room schema against implementation constraints. Current exam answer/key/marked collections are JSON columns for bounded records; revisit normalization after validating read/write patterns.
- Decide v1 backup export compatibility after reviewing migration and support requirements.
- Add and verify Gradle wrapper scripts/JAR; current CI uses a provisioned Gradle 9.6.0 installation.
- Latest verified CI at `7803eb569b4e4cfcb1ccbba950241aca33f04f37` completed successfully: native Build/Test/Lint and debug APK upload all passed. The shared Persian digit utility is now also wired into dashboard, planner task dates, exam entry/results and study statistics; this follow-up is awaiting CI.

Do not guess these. Investigate and document decisions before implementation.
