# DarsYar Liquid Glass Redesign — Application Audit

## Baseline

- Product: Persian-first Flutter application with RTL layout.
- Implementation entry point: `lib/main.dart`.
- Domain and persistence modules: `answer_scoring.dart`, `backup_codec.dart`,
  `darsyar_storage.dart`, `exam_result.dart`, `exam_sheet.dart` and
  `study_session.dart`.
- Baseline branch: `feat/darsyar-ux-refinement`.
- Baseline commit: `44f92a6ff768043ebfb7129caa1bd80428dfe1c2`.
- Baseline GitHub Actions run: successful; analysis, widget/unit tests, APK and
  App Bundle release builds completed.

## Screen and interaction inventory

### Application shell
- Root loading state.
- Persistent background treatment.
- Four-destination bottom navigation: dashboard, planner, answer sheet and settings.
- Selected navigation semantics and reduced-motion-aware page transitions.
- Snackbar feedback and safe-area handling.

### Dashboard
- Product identity and introductory hero.
- Task completion progress.
- Quick access to planner and answer sheets.
- Upcoming incomplete tasks.
- Empty task state and navigation to the full planner.

### Study planner
- Aggregate session and completion summaries.
- Current-weekday selection.
- Seven-day overview cards.
- Weekly planned/completed minutes and completion progress.
- Selected-day session list.
- Create, edit, complete and delete study sessions.
- Session overlap validation.
- Copy a day's sessions to another day with conflict checks.
- Task list with create, edit, complete and delete actions.
- Empty states for sessions and tasks.

### Answer sheets and exams
- Segmented navigation between exam setup and saved exams.
- Exam setup: name, question count, duration, optional answer key and negative marking.
- Saved exam list with start/continue, rename, answer-key edit and delete actions.
- Active exam screen with countdown, pause/resume, answer progress and question navigation.
- Answer selection and review markers.
- Confirmation and automatic completion flows.
- Result calculation, including optional negative marking.
- Result history, average score, recent-score trend and delayed answer-key entry.
- Empty result state.

### Settings and data recovery
- System/light/dark theme selection.
- Local-storage explanation.
- JSON backup creation and clipboard export.
- Backup import, validation, confirmation and rollback on failed persistence.

### Dialogs and transient states
- Exam duration editor.
- Task editor.
- Exam name/create/rename editor.
- Study-session editor.
- Backup import dialog and replacement confirmation.
- Question answer editor and answer-key editors.
- Delete confirmations.
- Finish-exam confirmation.
- Loading indicator, validation feedback, storage errors and success feedback.

## Functional preservation contracts

The redesign must not alter:
- Existing model fields, JSON formats or storage keys.
- Local persistence and write-serialization behavior.
- Legacy single-answer-sheet migration behavior.
- Backup schema validation and restore rollback behavior.
- Scoring rules, including unanswered and negative-marking behavior.
- Exam timer deadline, pause/resume and automatic completion behavior.
- Session overlap rules and day-copy conflict handling.
- Navigation destinations, selected tab behavior and saved theme preference.

## Design implementation boundaries

- Keep Flutter and the existing Material 3 application architecture.
- Add reusable design-system components rather than replacing the application.
- Keep visual-only changes separate from scoring, persistence and scheduling logic.
- Keep advanced glass rendering local to bounded surfaces and provide adaptive quality fallbacks.
- A focused widget package is allowed only when it supplies the shader-backed iOS 27 material that Flutter does not provide natively; do not replace Flutter or introduce a second UI framework.
- Preserve Persian strings, RTL, semantics and reduced-motion behavior.

## Current redesign work

- Centralized light/dark theme and visual tokens.
- Integrated `liquid_glass_widgets` 1.16.1 using `GlassThemeData.ios27()` and shader prewarming; explicit quality tiers avoid experimental auto-switching and keep premium shaders out of scrolling lists. Flutter remains the application framework.
- Replaced the custom bottom dock with `GlassScaffold` and the shader-backed floating `GlassTabBar`.
- Applied shader-backed `GlassContainer` materials to the dashboard hero and page-header icon wells; dense study content uses high-contrast `DarsYarContentSurface` rather than blur-heavy cards.
- Converted planner weekday selection to `GlassChip` and exam-mode selection to `GlassSegmentedControl`.
- Converted every remaining form input to `GlassTextField`/`GlassFormField`; duration, backup-import, study-session, and all answer-key editors now use `GlassModalSheet` presentations.
- Replaced all Material `AlertDialog`/`showDialog` flows with `GlassDialog` or `GlassModalSheet`; task/exam-name editors use glass dialogs, and question editing uses glass chips plus `GlassSwitch`.
- Replaced planner/exam overflow menus with `GlassPullDownButton`/`GlassMenuItem`; theme selection and exam modes use `GlassSegmentedControl`; negative marking uses `GlassSwitch`.
- Converted primary and secondary actions to `GlassButton`/`GlassIconButton`, answer choices to `GlassChip`, progress bars on solid surfaces to `GlassProgressIndicator`, overflow actions to `GlassPullDownButton`, and transient feedback to floating glass-backed banners; the dashboard hero uses a simple progress track to avoid nesting refractive surfaces. Study-session time selection uses a Cupertino wheel picker inside a glass sheet.
- Reused the shared surface in dashboard quick actions, weekly report, exam toolbar,
  exam setup, planner cards, task/session cards, settings and result panels.
- Added a shared primary-destination page header.
- Refined the navigation dock so the glass layer does not cover the bottom safe inset.
- Added a subtle page transition with a reduced-motion fallback.
- Added design-system documentation and a widget test for primary page headers.
- Replaced the remaining Material dialog, form and menu controls with package-native glass dialogs, sheets, inputs, switches, chips, buttons and pull-down menus.
- Made the exam-setup answer-key editor wrap option controls on narrow screens and
  added a compact-viewport widget test for that interaction.
- Refined planner weekday chips with a clearer selected treatment; replaced the
  week-card checkmark with a restrained, screen-reader-labelled selection dot.
- Made the task editor's title and fields scroll together on compact viewports and
  added a 320 × 640 dp widget regression test.
- Eagerly build the seven weekday controls and seven weekly cards inside bounded
  horizontal scrollers so the selected day is always addressable by its reveal logic,
  including on narrow phones.
- Added reusable full-height answer-key sheets shared by exam setup, active exams and result history.

## Remaining validation

- Verify the current GitHub Actions run against the latest redesign commit. The CI workflow runs analysis/tests/builds without requiring private release-signing secrets; generated APK/AAB files use the debug signing fallback and are validation artifacts only.
- Inspect the updated app on a physical Android device in both themes.
- Verify compact viewport and text scaling, long Persian labels and RTL overflow.
- Profile scroll performance on lists with many sessions/tasks/results.
- Continue the screen-by-screen visual audit for spacing, typography, card hierarchy, results history and settings details.
- Verify all sheet keyboard-inset behavior, accessibility labels and compact layouts.
- Verify all modal layouts with compact screens, keyboard visibility and large text scaling;
  the exam-setup answer-key editor has a dedicated 320 dp regression test.
- Do not merge to `main` until the full screen inventory and QA criteria are satisfied.
