# DarsYar Data Migration Plan

> Design document only. The native importer is not implemented yet. Treat every migration step as release-blocking.

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

### Android key representation must be verified

The Android SharedPreferences plugin commonly uses a preferences file named `FlutterSharedPreferences` and prefixes logical keys with `flutter.`. The migration implementation must inspect the exact locked `shared_preferences_android` package source/version and confirm the actual file and raw key names from a real installed build before relying on them.

Do not delete or rewrite the legacy preferences during the initial migration.

## 2. Room schema proposal

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

1. Open native database and inspect migration metadata.
2. If migration marker is complete, do not read or re-import Flutter data.
3. Read legacy preferences through a dedicated read-only adapter.
4. Read all relevant raw keys and record key presence separately from parse success.
5. Decode current-format collections. Distinguish absent keys from present-but-corrupt keys.
6. If current exam collection key is absent, reconstruct the legacy single sheet from legacy answers/key/marked/count fields. If the current key is present but invalid/empty, do not resurrect stale legacy fields; surface a recoverable migration error or safe empty state according to a reviewed recovery policy.
7. Validate every entity and relationship before starting writes.
8. Migrate date-less sessions to the Saturday-based week anchored to a deterministic migration reference date; document the reference date and make retry behavior deterministic.
9. Insert tasks, sessions, sheets, answers, answer keys, marked questions, results and active exam state in one Room transaction.
10. Set the Room migration marker only after all inserts and invariants succeed, in the same transaction.
11. Keep the legacy SharedPreferences file untouched.
12. Migrate theme/animation preferences separately into DataStore using an idempotent migration. Their absence must not block user-data import.
13. After successful migration, verify counts, stable IDs, active exam and representative record hashes/counts. Do not delete source data.

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
- [ ] Room transaction and rollback tests pass.
- [ ] Migration marker idempotence tests pass.
- [ ] Existing user data remains in legacy preferences after migration.
- [ ] Upgrade test from the previous signed release succeeds.
- [ ] User can recover from malformed or partially unavailable legacy data.
