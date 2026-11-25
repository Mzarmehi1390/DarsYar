package com.mzarmehi1390.darsyar.data

import androidx.room.withTransaction
import com.mzarmehi1390.darsyar.core.database.DarsYarDatabase
import com.mzarmehi1390.darsyar.core.database.entity.AppStateEntity
import com.mzarmehi1390.darsyar.features.exams.domain.ExamRepository
import com.mzarmehi1390.darsyar.features.exams.domain.ExamResultOperations
import com.mzarmehi1390.darsyar.features.exams.domain.ExamSessionSnapshot
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerRepository
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerWeekCopyPlan
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerDayCopyPlan
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerDayCopyResult
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerWeekCopyResult
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerCalendar
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerOperations
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton

data class DarsYarSnapshot(
    val tasks: List<StudyTask>,
    val studySessions: List<StudySession>,
    val exams: List<ExamSheet>,
    val results: List<ExamResult>,
    val activeExamId: String?,
)

@Singleton
class DarsYarRepository @Inject constructor(
    private val database: DarsYarDatabase,
) : PlannerRepository, ExamRepository {
    override fun observeTasks(): Flow<List<StudyTask>> =
        database.studyTaskDao().observeAll().map { rows -> rows.map { it.toDomain() } }

    override fun observeStudySessions(): Flow<List<StudySession>> =
        database.studySessionDao().observeAll().map { rows -> rows.map { it.toDomain() } }

    override fun observeExamSheets(): Flow<List<ExamSheet>> =
        database.examSheetDao().observeAll().map { rows -> rows.map { it.toDomain() } }

    override fun observeExamResults(): Flow<List<ExamResult>> =
        database.examResultDao().observeAll().map { rows -> rows.map { it.toDomain() } }

    override fun observeActiveExamId(): Flow<String?> =
        database.appStateDao().observe().map { it?.activeExamId }

    /**
     * Read every portable record under one Room transaction so an exported
     * backup cannot mix rows from different points in concurrent edits.
     */
    suspend fun createBackupSnapshot(): DarsYarSnapshot = database.withTransaction {
        DarsYarSnapshot(
            tasks = database.studyTaskDao().observeAll().first().map { it.toDomain() },
            studySessions = database.studySessionDao().observeAll().first().map { it.toDomain() },
            exams = database.examSheetDao().observeAll().first().map { it.toDomain() },
            results = database.examResultDao().getAll().map { it.toDomain() },
            activeExamId = database.appStateDao().get()?.activeExamId,
        )
    }

    override fun observeExamSession(): Flow<ExamSessionSnapshot?> =
        database.appStateDao().observe().map { state ->
            val id = state?.activeExamId ?: return@map null
            ExamSessionSnapshot(
                examId = id,
                currentQuestionNumber = state.activeExamQuestionNumber,
                deadlineEpochMillis = state.activeExamDeadlineEpochMillis,
                remainingSeconds = state.activeExamRemainingSeconds,
                isPaused = state.activeExamIsPaused,
            )
        }

    override suspend fun upsertTask(task: StudyTask) {
        database.studyTaskDao().upsertAll(listOf(task.toEntity()))
    }

    override suspend fun deleteTask(id: String) {
        database.studyTaskDao().deleteById(id)
    }

    override suspend fun upsertStudySession(session: StudySession) {
        database.studySessionDao().upsertAll(listOf(session.toEntity()))
    }

    override suspend fun deleteStudySession(id: String) {
        database.studySessionDao().deleteById(id)
    }

    /** Atomically inserts a prepared week without overwriting target records. */
    override suspend fun copyWeekPlan(plan: PlannerWeekCopyPlan): PlannerWeekCopyResult =
        database.withTransaction {
            val targetStart = PlannerCalendar.startOfWeek(plan.targetWeekStart)
            val targetEnd = targetStart.plusDays(7)
            val existingSessions = database.studySessionDao().observeAll().first().map { it.toDomain() }
            val existingTasks = database.studyTaskDao().observeAll().first().map { it.toDomain() }
            val targetOccupied = existingSessions.any { item ->
                PlannerCalendar.parseDateKey(item.scheduledDate)?.let {
                    !it.isBefore(targetStart) && it.isBefore(targetEnd)
                } == true
            } || existingTasks.any { item ->
                PlannerCalendar.parseDateKey(item.dueDate)?.let {
                    !it.isBefore(targetStart) && it.isBefore(targetEnd)
                } == true
            }
            if (targetOccupied) return@withTransaction PlannerWeekCopyResult.TargetWeekNotEmpty

            val sessionIds = plan.copiedSessions.map { it.id }
            val taskIds = plan.copiedTasks.map { it.id }
            if (sessionIds.any(String::isBlank) || taskIds.any(String::isBlank) ||
                sessionIds.size != sessionIds.toSet().size || taskIds.size != taskIds.toSet().size ||
                sessionIds.any { database.studySessionDao().findById(it) != null } ||
                taskIds.any { database.studyTaskDao().findById(it) != null }
            ) return@withTransaction PlannerWeekCopyResult.IdCollision

            val accepted = mutableListOf<StudySession>()
            for (candidate in plan.copiedSessions) {
                val date = PlannerCalendar.parseDateKey(candidate.scheduledDate)
                    ?: return@withTransaction PlannerWeekCopyResult.SessionConflict
                if (date.isBefore(targetStart) || !date.isBefore(targetEnd) ||
                    PlannerOperations.hasOverlap(existingSessions + accepted, candidate)
                ) return@withTransaction PlannerWeekCopyResult.SessionConflict
                accepted += candidate
            }
            if (plan.copiedTasks.any { item ->
                    val date = PlannerCalendar.parseDateKey(item.dueDate)
                    date == null || date.isBefore(targetStart) || !date.isBefore(targetEnd)
                }
            ) return@withTransaction PlannerWeekCopyResult.IdCollision

            database.studySessionDao().upsertAll(plan.copiedSessions.map { it.toEntity() })
            database.studyTaskDao().upsertAll(plan.copiedTasks.map { it.toEntity() })
            PlannerWeekCopyResult.Copied(plan.copiedSessions.size, plan.copiedTasks.size)
        }

    /** Atomically copies one dated day's sessions without replacing target records. */
    override suspend fun copyDayPlan(plan: PlannerDayCopyPlan): PlannerDayCopyResult =
        database.withTransaction {
            val currentSessions = database.studySessionDao().observeAll().first().map { it.toDomain() }
            val currentSource = currentSessions.filter { current ->
                plan.sourceSessions.any { it.id == current.id }
            }
            if (currentSource != plan.sourceSessions) {
                return@withTransaction PlannerDayCopyResult.SourceChanged
            }
            if (currentSessions.any { current ->
                    PlannerCalendar.parseDateKey(current.scheduledDate) == plan.targetDate
                }
            ) return@withTransaction PlannerDayCopyResult.TargetDateNotEmpty

            val ids = plan.copiedSessions.map { it.id }
            if (ids.any(String::isBlank) || ids.size != ids.toSet().size ||
                ids.any { database.studySessionDao().findById(it) != null } ||
                plan.copiedSessions.any { copied ->
                    PlannerCalendar.parseDateKey(copied.scheduledDate) != plan.targetDate ||
                        copied.weekday != PlannerCalendar.weekdayForDate(plan.targetDate) ||
                        copied.completed
                }
            ) return@withTransaction PlannerDayCopyResult.IdCollision

            val accepted = mutableListOf<StudySession>()
            for (candidate in plan.copiedSessions) {
                if (PlannerOperations.hasOverlap(currentSessions + accepted, candidate)) {
                    return@withTransaction PlannerDayCopyResult.SessionConflict
                }
                accepted += candidate
            }
            database.studySessionDao().upsertAll(plan.copiedSessions.map { it.toEntity() })
            PlannerDayCopyResult.Copied(plan.copiedSessions.size)
        }

    /** Persist sheet edits and synchronize linked history atomically. */
    override suspend fun upsertExamSheet(sheet: ExamSheet) {
        database.withTransaction {
            val previous = database.examSheetDao().findById(sheet.id)?.toDomain()
            val existingResults = database.examResultDao().getAll().map { it.toDomain() }
            var synchronized = existingResults
            val legacyNameIsUnique = previous?.let {
                database.examSheetDao().countByName(it.name) == 1
            } ?: false

            if (previous != null && previous.name != sheet.name) {
                synchronized = ExamResultOperations.synchronizeName(
                    results = synchronized,
                    sheetId = sheet.id,
                    previousName = previous.name,
                    newName = sheet.name,
                    includeLegacyNameLinks = legacyNameIsUnique,
                )
            }
            if (previous != null && previous.answerKey != sheet.answerKey) {
                synchronized = ExamResultOperations.synchronizeAnswerKey(
                    results = synchronized,
                    sheet = sheet,
                    includeLegacyNameLinks = legacyNameIsUnique,
                )
            }
            database.examSheetDao().upsertAll(listOf(sheet.toEntity()))
            if (synchronized != existingResults) {
                database.examResultDao().upsertAll(synchronized.map { it.toEntity() })
            }
        }
    }

    override suspend fun completeExam(
        sheetId: String,
        resultId: String,
        completedAt: String,
    ): ExamResult? = database.withTransaction {
        val sheetEntity = database.examSheetDao().findById(sheetId)
            ?: return@withTransaction null
        require(database.examResultDao().findById(resultId) == null) {
            "Result ID already exists."
        }
        val sheet = sheetEntity.toDomain()
        val result = ExamResultOperations.create(sheet, resultId, completedAt)
        database.examSheetDao().upsertAll(listOf(sheet.copy(isCompleted = true).toEntity()))
        database.examResultDao().upsertAll(listOf(result.toEntity()))
        val appState = database.appStateDao().get()
        if (appState?.activeExamId == sheetId) {
            database.appStateDao().upsert(appState.clearExamSession())
        }
        result
    }

    override suspend fun deleteExamSheet(id: String): Boolean = database.withTransaction {
        val sheet = database.examSheetDao().findById(id) ?: return@withTransaction false
        if (database.examSheetDao().count() <= 1) return@withTransaction false
        database.examResultDao().deleteByExamId(sheet.id)
        if (database.examSheetDao().countByName(sheet.name) == 1) {
            database.examResultDao().deleteLegacyByName(sheet.name)
        }
        database.examSheetDao().deleteById(sheet.id)
        val appState = database.appStateDao().get()
        if (appState?.activeExamId == id) {
            database.appStateDao().upsert(appState.clearExamSession())
        }
        true
    }

    override suspend fun setActiveExam(id: String): Boolean = database.withTransaction {
        if (database.examSheetDao().findById(id) == null) return@withTransaction false
        val current = database.appStateDao().get()
        // Re-selecting the current exam is a resume/navigation action, not a new session.
        // Preserve its durable timer and question progress in that case.
        if (current?.activeExamId == id) return@withTransaction true

        database.appStateDao().upsert(
            (current ?: AppStateEntity(
                activeExamId = null,
                updatedAtEpochMillis = System.currentTimeMillis(),
            )).copy(
                activeExamId = id,
                activeExamQuestionNumber = 1,
                activeExamDeadlineEpochMillis = null,
                activeExamRemainingSeconds = 0,
                activeExamIsPaused = true,
                updatedAtEpochMillis = System.currentTimeMillis(),
            ),
        )
        true
    }

    override suspend fun saveExamSession(session: ExamSessionSnapshot): Boolean =
        database.withTransaction {
            val current = database.appStateDao().get() ?: return@withTransaction false
            if (current.activeExamId != session.examId) return@withTransaction false
            val sheet = database.examSheetDao().findById(session.examId)
                ?: return@withTransaction false
            if (session.currentQuestionNumber !in 1..sheet.questionCount) return@withTransaction false
            database.appStateDao().upsert(
                current.copy(
                    activeExamQuestionNumber = session.currentQuestionNumber,
                    activeExamDeadlineEpochMillis = session.deadlineEpochMillis,
                    activeExamRemainingSeconds = session.remainingSeconds,
                    activeExamIsPaused = session.isPaused,
                    updatedAtEpochMillis = System.currentTimeMillis(),
                ),
            )
            true
        }

    override suspend fun clearActiveExam(id: String?) = database.withTransaction {
        val current = database.appStateDao().get() ?: return@withTransaction
        if (id == null || current.activeExamId == id) {
            database.appStateDao().upsert(current.clearExamSession())
        }
    }

    suspend fun replaceAll(snapshot: DarsYarSnapshot) {
        require(snapshot.exams.isNotEmpty()) { "A backup must contain at least one exam sheet." }
        val activeId = snapshot.activeExamId
            ?.takeIf { requested -> snapshot.exams.any { it.id == requested } }
            ?: snapshot.exams.first().id

        database.withTransaction {
            database.studyTaskDao().deleteAll()
            database.studySessionDao().deleteAll()
            database.examResultDao().deleteAll()
            database.examSheetDao().deleteAll()
            database.studyTaskDao().upsertAll(snapshot.tasks.map { it.toEntity() })
            database.studySessionDao().upsertAll(snapshot.studySessions.map { it.toEntity() })
            database.examSheetDao().upsertAll(snapshot.exams.map { it.toEntity() })
            database.examResultDao().upsertAll(snapshot.results.map { it.toEntity() })
            val current = database.appStateDao().get()
            database.appStateDao().upsert(
                AppStateEntity(
                    activeExamId = activeId,
                    activeExamIsPaused = true,
                    legacyImportCompleted = current?.legacyImportCompleted ?: false,
                    updatedAtEpochMillis = System.currentTimeMillis(),
                ),
            )
        }
    }

    private fun AppStateEntity.clearExamSession(): AppStateEntity = copy(
        activeExamId = null,
        activeExamQuestionNumber = 1,
        activeExamDeadlineEpochMillis = null,
        activeExamRemainingSeconds = 0,
        activeExamIsPaused = false,
        updatedAtEpochMillis = System.currentTimeMillis(),
    )
}
