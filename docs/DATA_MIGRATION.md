# DarsYar Data Migration Plan

> Implemented baseline: Room schema, one-time transactional Flutter SharedPreferences import for tasks/sessions/exams/results/active exam, and DataStore preference migration code exist. The importer is covered by Robolectric tests and preserves the legacy source file. Device verification against an installed legacy APK and exact dependency storage format remains a release gate.

## 1. Data sources

The existing Flutter app stores JSON strings and preferences through the `shared_preferences` plugin.

Logical keys used by Dart:

| Logical key | Contents | Native destination |
|---|---|---|
| `darsyar.tasks` | JSON list of task records | Room `study_tasks` |
| `darsyar.studySessions` | JSON list of study session records | Room `study_sessions` |
| `darsyar.exams` | JSON list of exam sheets | Room `exam_sheets` + answer/mark child tables |
| `darsyar.results` | JSON list of exam results | Room `exam_results` |
| `darsyar.activeExamId` | active exam ID | Room `app_state` |
| `darsyar.answers` | legacy single-sheet answer map | default exam sheet answer rows |
| `darsyar.answerKey` | legacy single-sheet key map | default exam sheet answer-key rows |
| `darsyar.marked` | legacy marked-question list | default exam sheet marked rows |
| `darsyar.count` | legacy question count | default exam sheet questionCount |
| `darsyar.themeMode` | system/light/dark | DataStore |
| `darsyar.animationsEnabled` | boolean | DataStore |

### Android key representation — verification still required

The current DataStore preferences adapter targets the conventional Android SharedPreferences file `FlutterSharedPreferences` and raw keys `flutter.darsyar.themeMode` and `flutter.darsyar.animationsEnabled`. This mapping has not yet been verified against the exact locked `shared_preferences_android` package source or a real installed build. Do not rely on it for a release until verified.

The DataStore migration handles theme mode and animation preference. A separate Room importer handles task, session, exam and result collections transactionally. It keeps the legacy SharedPreferences file untouched.

## 2. Room schema

Implemented baseline currently uses `study_tasks`, `study_sessions`, `exam_sheets`, `exam_results` and singleton `app_state` tables. Task/session dates are retained as ISO local-date strings. Exam answer maps, answer-key maps and marked-question sets are stored as bounded JSON columns in `exam_sheets`; historical result answer/key snapshots are also JSON columns. This is a pragmatic initial storage shape, not a final performance claim. Exported schema JSON and a tested migration importer are still required.

The detailed normalized child-table proposal below remains a future design option, not a description of the current schema.

### `study_tasks`
- `id TEXT PRIMARY KEY`
- `title TEXT NOT NULL`
- `subject TEXT NOT NULL`
- `done INTEGER NOT NULL`
- `dueDateEpochDay INTEGER NULL`
- Index on due date if query patterns justify it.

### `study_sessions`
- `id TEXT PRIMARY KEY`
- `title TEXT NOT NULL`
- `subject TEXT NOT NULL`
- `weekday INTEGER NOT NULL` (0 Sunday ... 6 Saturday; compatibility field)
- `startMinutes INTEGER NOT NULL`
- `durationMinutes INTEGER NOT NULL`
- `completed INTEGER NOT NULL`
- `scheduledDateEpochDay INTEGER NULL`
- Indexes for scheduled date and weekday.

### `exam_sheets`
- `id TEXT PRIMARY KEY`
- `name TEXT NOT NULL`
- `questionCount INTEGER NOT NULL`
- `durationSeconds INTEGER NOT NULL`
- `negativeMarking INTEGER NOT NULL`
- `isCompleted INTEGER NOT NULL`

### `exam_sheet_answers`
- `examId TEXT NOT NULL`
- `questionNumber INTEGER NOT NULL`
- `kind TEXT NOT NULL` (`ANSWER` or `ANSWER_KEY`)
- `optionIndex INTEGER NOT NULL`
- Composite primary key (`examId`, `kind`, `questionNumber`).
- Foreign key to `exam_sheets` with cascade delete.

### `exam_marked_questions`
- `examId TEXT NOT NULL`
- `questionNumber INTEGER NOT NULL`
- Composite primary key (`examId`, `questionNumber`).
- Foreign key to `exam_sheets` with cascade delete.

### `exam_results`
- `id TEXT PRIMARY KEY`
- `examId TEXT NULL` (nullable to preserve legacy results)
- `examName TEXT NOT NULL`
- `completedAtEpochMillis INTEGER NOT NULL`
- `questionCount INTEGER NOT NULL`
- `correct INTEGER NOT NULL`
- `wrong INTEGER NOT NULL`
- `unanswered INTEGER NOT NULL`
- `keyedQuestions INTEGER NOT NULL`
- `percentage REAL NULL`
- `negativeMarking INTEGER NOT NULL`
- `answersJson TEXT NOT NULL`
- `answerKeyJson TEXT NOT NULL`
- Indexes on exam ID and exam name.
- Keep result answer/key snapshots immutable as they are historical evidence.

### `app_state`
- Singleton row with active exam ID and migration metadata.
- Migration completion marker is committed in the same Room transaction as imported data.
- Validate active ID against imported sheets; fallback to first sheet if missing/stale.

### Date and time representation

- Tasks and session dates represent local calendar dates, not instants. Convert to/from epoch-day using the device local date semantics; do not shift dates through UTC midnight.
- Session time is minutes after local midnight.
- Exam completion timestamp is an instant and should be stored as epoch milliseconds.
- Preserve original ISO date and timestamp parsing semantics with fixture tests.

## 3. One-time migration algorithm

Implementation status: implemented for the current native baseline; keep the following as the acceptance contract and close remaining device-verification gaps.

- JSON numeric fields and answer-map/list values follow Dart `num` casts: numeric strings are not coerced, while fractional numbers are truncated with `toInt()`. Task/session nullable boolean casts reject non-boolean values; exam/result boolean flags are true only for the JSON boolean `true`. Exam-sheet missing/null IDs and names use Flutter defaults while explicit empty strings are preserved. Robolectric regression tests cover these distinctions.

1. Open native database and inspect migration metadata.
2. If migration marker is complete, do not read or re-import Flutter data.
3. Read legacy preferences through a dedicated read-only adapter.
4. Read all relevant keys and distinguish absent values from malformed values.
5. Decode current-format collections and reject malformed records rather than silently dropping them.
6. If the current exam collection key is absent, reconstruct the legacy single sheet from legacy answers/key/marked/count fields.
7. Parse all task/session/exam/result records before writing. Normalize colliding or missing historical result IDs without discarding results; duplicate IDs in other collections remain an import error.
8. Preserve the current date/weekday compatibility behavior for legacy sessions and validate it against representative installed-app fixtures.
9. Insert tasks, sessions, sheets, results and active exam state in one Room transaction.
10. Set the Room migration marker only after all inserts succeed, in the same transaction.
11. Keep the legacy SharedPreferences file untouched.
12. Migrate theme/animation preferences separately into DataStore. Their absence must not block user-data import.
13. After migration, verify counts, IDs, active exam and representative values. Do not delete source data.

## 4. Idempotence and failure recovery

- Room transaction guarantees that partial collection inserts are rolled back.
- Migration marker is part of that transaction; a crash before commit causes safe retry.
- If legacy data is malformed, never set the marker as though import succeeded.
- If native tables already contain user-created records and the marker is absent, do not blindly replace them. Detect the mixed state and stop for a safe reconciliation path.
- A successful migration is repeatable as a no-op.
- Keep a user-facing recovery path: export or preserve original v1 backup text before any destructive replacement.
- Database schema upgrades after the initial native release use Room migration tests and exported schema JSON.

## 5. Backup v1 compatibility

The v1 JSON envelope is:
- `app`: `DarsYar`
- `schemaVersion`: `1`
- `exportedAt`: ISO timestamp
- `activeExamId`: string
- `tasks`, `studySessions`, `exams`, `results`: arrays of objects

The Flutter codec performs strict validation. The native codec must reproduce the accepted field constraints and normalization behavior. At minimum validate:
- Collection shapes and required fields.
- Unique task/session/exam IDs where required by the old codec.
- Question count 1..200 and valid option indices 0..3.
- Answer and key question numbers within question count.
- Duration bounds.
- Valid local date fields.
- Result count/percentage ranges.
- At least one exam and unique non-empty exam IDs.
- Active exam ID normalization to the first sheet.

Do not deserialize untrusted backup input directly into Room entities without validation.

## 6. Required migration test fixtures

Create fixtures from synthetic data, never real user data:
- Empty first-run state.
- Current multi-exam state with answers, answer keys, review marks and linked results.
- Legacy single-sheet state only.
- Both current and legacy keys present.
- Current exam key present but corrupt (must not resurrect stale legacy answers).
- Missing/stale active exam ID.
- Null exam IDs with name-based result association.
- Legacy weekday-only sessions.
- Date-based sessions across Saturday/Friday boundaries.
- Persian strings, Arabic/Persian numerals and Unicode text.
- Invalid JSON, duplicate IDs, out-of-range answer index and impossible durations.
- Simulated crash/failure before transaction commit and retry.
- Repeated migration after successful marker.

## 7. Release gates

- [ ] Raw SharedPreferences file/key format verified from locked dependency and installed legacy APK.
- [ ] Original signing key continuity verified for in-place upgrade.
- [ ] V1 backup fixtures pass native importer tests.
- [x] Room transaction and rollback tests pass in automated tests.
- [x] Migration marker idempotence tests pass in automated tests.
- [x] Existing user data remains in legacy preferences after migration in automated tests.
- [ ] Upgrade test from the previous signed release succeeds.
- [ ] User can recover from malformed or partially unavailable legacy data.
