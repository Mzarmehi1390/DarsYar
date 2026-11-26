package com.mzarmehi1390.darsyar.features.exams.domain

import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import kotlinx.coroutines.flow.Flow

/**
 * Durable snapshot of an in-progress exam. A null deadline represents a paused
 * session; a non-null deadline is interpreted against wall-clock time.
 */
data class ExamSessionSnapshot(
    val examId: String,
    val currentQuestionNumber: Int,
    val deadlineEpochMillis: Long?,
    val remainingSeconds: Int,
    val isPaused: Boolean,
) {
    init {
        require(examId.isNotBlank())
        require(currentQuestionNumber >= 1)
        require(remainingSeconds in 0..86_400)
        require(isPaused == (deadlineEpochMillis == null) || remainingSeconds == 0)
    }
}

/** Persistence contract consumed by exam-taking, history and dashboard logic. */
interface ExamRepository {
    fun observeExamSheets(): Flow<List<ExamSheet>>
    fun observeExamResults(): Flow<List<ExamResult>>
    fun observeActiveExamId(): Flow<String?>
    fun observeExamSession(): Flow<ExamSessionSnapshot?>
    suspend fun setActiveExam(id: String): Boolean
    /** Saves only when [session.examId] is still the active exam. */
    suspend fun saveExamSession(session: ExamSessionSnapshot): Boolean
    /** Clears active selection and all timer/navigation fields for the matching exam. */
    suspend fun clearActiveExam(id: String? = null)
    suspend fun upsertExamSheet(sheet: ExamSheet)
    /** Returns null when the requested sheet no longer exists. */
    suspend fun completeExam(sheetId: String, resultId: String, completedAt: String): ExamResult?
    /** Atomically replaces a saved historical result when its ID still exists. */
    suspend fun updateExamResult(result: ExamResult): Boolean
    /** Returns false when the sheet is missing or is the final remaining sheet. */
    suspend fun deleteExamSheet(id: String): Boolean
}
