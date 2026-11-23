# Native Android Testing Strategy

> Strategy and initial CI contract. A first pure Kotlin exam-scoring test suite has been added; broad native feature coverage is not yet available.

## Test layers

### Pure Kotlin unit tests
- Exam scoring (initial suite added in `feature/exams/src/test/.../AnswerScoringTest.kt`): unkeyed denominator, one-third negative marking, no-key result, invalid answer filtering and lower-bound clamping.
- Remaining domain tests: keyed/unkeyed questions, unanswered questions, negative marking, clamping, no-key result.
- Exam sheet operations: create, rename, resize, answer/mark transitions, delete guards.
- Timer: start, pause, resume, deadline expiry, zero-duration and process recreation contract.
- Planner calendar: Saturday-Friday boundaries, weekday compatibility, date-only normalization and leap dates.
- Session overlap: adjacent sessions, same-day overlap, different dates, legacy weekday fallback.
- Week/day copy: new IDs, due-date offsets, completion reset and conflict policy.
- Backup codec: v1 valid payloads, malformed JSON, duplicate IDs, invalid ranges and stale active ID.

### Room and repository tests
- Entity/mapper round trips.
- DAO ordering and filtering.
- Transaction rollback for multi-table exam updates and backup restore.
- Deletion of a sheet and its ID-linked plus legacy name-linked results.
- Schema migration tests using exported Room schema JSON.
- Legacy Flutter import idempotence and mixed/corrupt-key behavior.

### DataStore tests
- Theme mode defaults and persistence.
- Animation preference defaults and persistence.
- Legacy preference migration does not overwrite an explicit native preference.

### Compose UI tests
- Four root destinations and selected navigation state.
- RTL semantics and focus behavior.
- Task/session creation, edit, completion and deletion.
- Week/day selection and copy confirmations.
- Exam creation, answer entry, review marks, timer pause/resume and finish.
- Answer-key editing and history recalculation.
- Backup validation, replacement confirmation and error state.
- Light/dark mode and reduced-motion behavior.
- Compact viewport and enlarged font scale.

### Performance tests
- Macrobenchmark cold/warm startup.
- Planner/exam list scrolling.
- Navigation transitions.
- Glass showcase rendering.
- Frame timing and memory during shader/backdrop updates.
- Baseline Profile generation only after stable critical user journeys exist.

## CI gates

The native workflow initially runs:
- `:app:assembleDebug`
- `test`
- `lint`

Add instrumented Compose tests, Macrobenchmark and Detekt as their test targets/configuration are introduced. A green debug build alone is not feature-complete validation.

## Test data policy

Use synthetic Persian and Latin fixtures. Never commit real user backup files, task content, exam answers, personal data, keystores or secrets.
