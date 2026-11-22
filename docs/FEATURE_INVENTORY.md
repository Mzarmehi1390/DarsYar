# DarsYar — Native Rebuild Feature Inventory

> Audit baseline: `main` at `cb0e9affcf2486c42dd146a66044c0f5fd34ca40` (2026-11-22).
> This document is the functional preservation contract for the Kotlin rebuild.
> The current repository is still a Flutter application; this is an inventory, not a claim that native features exist.

## Product scope

- Persian-first, RTL study planner and exam answer-sheet application.
- Android is the sole target for the replacement.
- Existing application ID: `com.mzarmehi1390.darsyar` (must remain unchanged).
- Existing version: `1.0.0+1`; native versioning policy must be defined during foundation work.
- No account system, cloud synchronization, remote API, or multi-device sync was found in the inspected implementation. Current user data is local.

## Feature inventory and acceptance contracts

### 1. Application shell and preferences

- Four primary destinations: dashboard, planner, answer sheets/exams, settings.
- Persistent selected destination during the app session; initial destination defaults to dashboard.
- Root loading state while persisted data and preferences are restored.
- Persistent ambient background and floating bottom navigation.
- Page transitions with reduced-motion handling.
- Snackbar/banner feedback and safe-area behavior.
- Theme modes: system, light, dark.
- Persistent animation preference.
- Preserve Persian labels, RTL layout, navigation semantics, and readable contrast.

Relevant implementation:
- `lib/main.dart`, `lib/app/darsyar_app.dart`, `lib/app/darsyar_home.dart`
- `lib/app/presentation/home_shell.dart`, `lib/app/app_preferences.dart`

### 2. Dashboard

- Product identity and introductory hero.
- Completed-task count and completion progress.
- Up to three pending tasks surfaced as upcoming items.
- Empty state when there are no tasks.
- Quick navigation to planner and exam/answer-sheet destinations.
- Shared task-row and empty-state composition.

Relevant implementation: `lib/features/dashboard/presentation/dashboard_page.dart`, orchestrated by `lib/app/darsyar_home.dart`.

### 3. Planner and tasks

#### Tasks
- Create, edit, complete/uncomplete, and delete a task.
- Task fields: stable ID, title, subject, completion state, optional local due date.
- Empty subject is normalized to the Persian general-subject label.
- Dashboard and planner share the same task collection.
- Task editing preserves completion state.

#### Study sessions
- Create, edit, complete/uncomplete, and delete a study session.
- Session fields: ID, title, subject, weekday, start minute, duration, completion, optional scheduled local date.
- Time-of-day and duration constraints; a session cannot extend beyond the day.
- Prevent overlapping sessions on the same occurrence date (or same legacy weekday when no date exists).
- Sort sessions by start time.
- Support weekday-only legacy records and date-based current records.

#### Calendar and weekly planning
- Week convention is Saturday through Friday (Iranian week).
- Date keys are local calendar dates; weekday compatibility keys retain Dart convention (Sunday=0 ... Saturday=6).
- Navigate between weeks and select a day.
- Seven-day overview with session count, planned minutes and progress.
- Daily session totals and completion summaries.
- Weekly planned minutes, completed minutes and completion percentage.
- Copy selected-day sessions to another day with conflict validation and completion reset.
- Copy eligible sessions and due-dated tasks to the following week; copied entries receive new IDs and reset completion state. Destination replacement/confirmation is UI orchestration and must not be silently assumed.

Relevant implementation:
- `lib/features/planner/application/planner_controller.dart`
- `lib/features/planner/application/task_controller.dart`
- `lib/features/planner/application/planner_week_copy_service.dart`
- `lib/features/planner/domain/planner_calendar.dart`
- `lib/features/planner/domain/models/{study_session,study_task,planner_summary}.dart`
- `lib/features/planner/presentation/{planner_page,planner_item_tiles,planner_week_overview_card,planner_weekly_report_card,study_session_editor,task_details_dialog}.dart`

### 4. Exams and answer sheets

#### Exam management
- Multiple independent saved answer sheets.
- Create and rename exam sheets.
- Delete a sheet only when at least one sheet will remain.
- Deleting a sheet also deletes its linked result history.
- Select the active sheet and start/continue its exam.
- Question count is configurable from 1 through 200.
- Configurable duration (seconds; UI presets include 15, 30, 45 and 60 minutes; editor supports a broader bounded duration).
- Optional answer key.
- Optional negative marking.
- Resize removes answers, answer-key entries and review marks outside the new question range.

#### Answering and navigation
- Four answer choices encoded as 0..3 (displayed as Persian/Arabic option labels).
- Select or clear an answer.
- Mark unanswered questions for review; selecting an answer clears the mark.
- Question navigator and previous/next navigation.
- Current question is bounded to the valid range.
- Display answer progress and remaining time.
- Pause/resume timer; preserve exam-specific timer association.
- Finish confirmation and automatic completion when the timer expires.
- Guard against duplicate finish/save lifecycle calls.

#### Scoring and results
- Correct, wrong, unanswered, and keyed-question counts.
- Unkeyed questions are excluded from the scoring denominator.
- Negative marking subtracts one-third of a correct answer per wrong answer.
- Final percentage is clamped to 0..100; percentage is absent if no answer key exists.
- Store the answers and answer key snapshot in each result.
- Result history, average of scored results, and trend of up to seven most recent scored results.
- Add or edit an answer key later and recalculate linked results.
- Preserve legacy association behavior for results without an exam ID (name-based matching).

#### Independent percentage calculator
- Inputs: correct, wrong, unanswered.
- Reject negative values, totals outside 1..200, and empty totals.
- Show percentage with and without one-third negative marking.

Relevant implementation:
- `lib/answer_scoring.dart`, `lib/exam_percentage_calculator.dart`
- `lib/features/exams/application/{exam_controller,exam_sheet_controller,exam_taking_lifecycle_controller,exam_taking_session_controller,exam_timer_controller}.dart`
- `lib/features/exams/domain/models/{exam_result,exam_sheet}.dart`
- `lib/features/exams/presentation/{exam_page,exam_setup_panel,saved_exams_view,saved_exam_card,exam_taking_view,exam_taking_header,exam_question_navigator,exam_question_workspace,exam_result_card,exam_history_page,answer_key_editor_sheet,exam_answer_editor_dialog,exam_duration_dialog}.dart`

### 5. Backup, restore, and local persistence

#### Existing persisted sections
- `darsyar.tasks`
- `darsyar.studySessions`
- `darsyar.results`
- `darsyar.exams`
- `darsyar.answers`
- `darsyar.answerKey`
- `darsyar.marked`
- `darsyar.count`
- `darsyar.activeExamId`
- Preferences: `darsyar.themeMode`, `darsyar.animationsEnabled`

Current implementation serializes feature collections as JSON strings through Flutter `shared_preferences`. Writes are serialized and use best-effort rollback because SharedPreferences does not offer a multi-key transaction.

#### Legacy compatibility
- When the current `darsyar.exams` key is absent, the repository attempts migration from the legacy single-answer-sheet keys (`answers`, `answerKey`, `marked`, `count`).
- If the current exam key exists but is corrupt/empty, stale legacy answers must not be resurrected.
- At least one answer sheet is always established in app state.
- An invalid stored active exam ID falls back to the first sheet.
- Legacy planner sessions without scheduled dates are assigned dates in the Saturday-based week of the migration/import reference date.

#### Portable backup
- JSON format, `app = DarsYar`, `schemaVersion = 1`.
- Payload includes export timestamp, active exam ID, tasks, study sessions, exams, and results.
- Strict validation covers collection shapes, IDs, answer ranges, counts, durations, date fields, score ranges and percentages.
- At least one exam is required; exam IDs must be unique; invalid active ID normalizes to the first exam.
- Import is decoded into typed snapshot data before mutating live state.
- UI requires confirmation before replacing existing data.
- Existing restore flow attempts rollback if persistence fails.
- Backups contain private study data and answers; do not log their content.

Relevant implementation:
- `lib/darsyar_storage.dart`, `lib/app/data/darsyar_repository.dart`
- `lib/backup_codec.dart`, `lib/features/settings/application/backup_service.dart`
- `lib/features/settings/presentation/{settings_page,backup_import_dialog}.dart`

### 6. Liquid Glass design system (visual behavior to preserve, implementation to replace)

- Centralized theme and design tokens.
- Ambient layered background with light/dark variants.
- Shader-backed focal dashboard hero and floating navigation capsule.
- Reusable glass surfaces, buttons, icon buttons, dialogs, menus, modal sheets, selectors, snackbars, and page header.
- Solid high-contrast content surfaces for dense study data and long Persian text.
- Shared typography, spacing, corner geometry and component roles.
- Reduced-motion support and explicit rendering quality tiers.
- Glass rendering is bounded to selected surfaces; not every list row is refractive.

Existing Flutter package: `liquid_glass_widgets 1.16.1`. This package is not part of the Kotlin implementation and must not be carried into the native app.

Relevant implementation: all files under `lib/design_system/` plus `docs/LIQUID_GLASS_DESIGN_SYSTEM.md`.

### 7. Branding, assets, localization, and platform behavior

- Existing launcher assets: `assets/branding/darsyar_launcher.jpg`, `assets/branding/darsyar_launcher.png`.
- Existing Android launcher resources and launch backgrounds are present.
- Persian-first copy and RTL layout are pervasive.
- App label: `درس‌یار`.
- Existing app ID: `com.mzarmehi1390.darsyar`.
- Current manifest declares the Flutter activity and Flutter embedding metadata; this must be replaced by a native Activity/Compose entry point.
- Current Android Gradle file delegates SDK levels and version values to Flutter Gradle plugin; native min/target/compile SDK values are not explicit yet.
- No iOS target is in scope for the replacement. Existing non-Android Flutter platform folders are legacy material and are not to be included in the native delivery.

## Source and test inventory

At the audited baseline:
- 65 Dart source files under `lib/`.
- 32 Dart test files under `test/`.
- 230 total tracked files in the recursive Git tree.

The 65 production Dart files are grouped in the feature sections above. Root-level compatibility exports (`exam_result.dart`, `exam_sheet.dart`, `study_session.dart`, `models/study_task.dart`, `planner_summary.dart`) should be treated as aliases, not independent domain entities.

Test suite coverage includes:
- Answer scoring and percentage calculation.
- App repository, home shell, preferences and storage.
- Backup codec validation, backup service and round-trip restore.
- Glass buttons, dialogs, selectors, input focus and modal content.
- Exam controller, sheet, navigation, result, timer and taking lifecycle/session.
- Planner calendar, summary, controllers, multi-week behavior, week copy and study-session rules.
- Task controller and broad widget-level integration coverage.

Test files are under `test/`; the detailed path list is retained in the source tree and should be mapped to Kotlin unit, integration and Compose UI tests rather than discarded.

## Native rebuild acceptance checklist

- [ ] Every behavior above is represented in the native feature specification.
- [ ] Every legacy persisted key and JSON field has an explicit migration mapping.
- [ ] Backup schema v1 remains importable and export compatibility is documented.
- [ ] Saturday-based calendar and date/time semantics are covered by tests.
- [ ] Scoring edge cases and delayed answer-key recalculation are covered by tests.
- [ ] Timer pause/resume/deadline/automatic-finish behavior is covered by tests.
- [ ] RTL, Persian text, font scaling and accessibility are verified.
- [ ] No Flutter runtime or hybrid UI remains in the delivered Android application.
