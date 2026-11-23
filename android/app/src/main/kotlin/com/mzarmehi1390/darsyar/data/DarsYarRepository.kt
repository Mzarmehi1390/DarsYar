package com.mzarmehi1390.darsyar.data

import androidx.room.withTransaction
import com.mzarmehi1390.darsyar.core.database.DarsYarDatabase
import com.mzarmehi1390.darsyar.core.database.entity.AppStateEntity
import com.mzarmehi1390.darsyar.features.exams.domain.ExamResultOperations
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
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
) {
    fun observeTasks(): Flow<List<StudyTask>> =
        database.studyTaskDao().observeAll().map { rows -> rows.map { it.toDomain() } }

    fun observeStudySessions(): Flow<List<StudySession>> =
        database.studySessionDao().observeAll().map { rows -> rows.map { it.toDomain() } }

    fun observeExamSheets(): Flow<List<ExamSheet>> =
        database.examSheetDao().observeAll().map { rows -> rows.map { it.toDomain() } }

    fun observeExamResults(): Flow<List<ExamResult>> =
        database.examResultDao().observeAll().map { rows -> rows.map { it.toDomain() } }

    suspend fun upsertTask(task: StudyTask) {
        database.studyTaskDao().upsertAll(listOf(task.toEntity()))
    }

    suspend fun deleteTask(id: String) {
        database.studyTaskDao().deleteById(id)
    }

    suspend fun upsertStudySession(session: StudySession) {
        database.studySessionDao().upsertAll(listOf(session.toEntity()))
    }

    suspend fun deleteStudySession(id: String) {
        database.studySessionDao().deleteById(id)
    }

    /**
     * Persists a sheet edit and synchronizes linked historical result names and
     * score snapshots in the same transaction. An unrelated sheet's history
     * is never recalculated.
     */
    suspend fun upsertExamSheet(sheet: ExamSheet) {
        database.withTransaction {
            val previous = database.examSheetDao().findById(sheet.id)?.toDomain()
            val existingResults = database.examResultDao().getAll().map { it.toDomain() }
            var synchronized = existingResults
            // Rename legacy name-linked rows first so answer-key synchronization
            // can still identify those rows after the sheet's name has changed.
            if (previous != null && previous.name != sheet.name) {
                synchronized = ExamResultOperations.synchronizeName(
                    synchronized,
                    sheet.id,
                    previous.name,
                    sheet.name,
                )
            }
            if (previous != null && previous.answerKey != sheet.answerKey) {
                synchronized = ExamResultOperations.synchronizeAnswerKey(synchronized, sheet)
            }
            database.examSheetDao().upsertAll(listOf(sheet.toEntity()))
            if (synchronized != existingResults) {
                database.examResultDao().upsertAll(synchronized.map { it.toEntity() })
            }
        }
    }

    /** Completes the attempt and records its immutable score snapshot atomically. */
    suspend fun completeExam(
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
        database.examSheetDao().upsertAll(
            listOf(sheet.copy(isCompleted = true).toEntity()),
        )
        database.examResultDao().upsertAll(listOf(result.toEntity()))
        result
    }

    suspend fun deleteExamSheet(id: String): Boolean = database.withTransaction {
        val sheet = database.examSheetDao().findById(id) ?: return@withTransaction false
        if (database.examSheetDao().count() <= 1) return@withTransaction false
        database.examResultDao().deleteForExam(sheet.id, sheet.name)
        database.examSheetDao().deleteById(sheet.id)
        true
    }

    suspend fun setActiveExam(id: String): Boolean = database.withTransaction {
        if (database.examSheetDao().findById(id) == null) return@withTransaction false
        val current = database.appStateDao().get()
        database.appStateDao().upsert(
            AppStateEntity(
                activeExamId = id,
                legacyImportCompleted = current?.legacyImportCompleted ?: false,
                updatedAtEpochMillis = System.currentTimeMillis(),
            ),
        )
        true
    }

    /** Restores a fully validated backup as one all-or-nothing database transaction. */
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
                    legacyImportCompleted = current?.legacyImportCompleted ?: false,
                    updatedAtEpochMillis = System.currentTimeMillis(),
                ),
            )
        }
    }
}
