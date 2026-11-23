package com.mzarmehi1390.darsyar.features.exams.domain

import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import kotlinx.coroutines.flow.Flow

/** Persistence contract consumed by exam-taking, history and dashboard logic. */
interface ExamRepository {
    fun observeExamSheets(): Flow<List<ExamSheet>>
    fun observeExamResults(): Flow<List<ExamResult>>
    fun observeActiveExamId(): Flow<String?>
    suspend fun setActiveExam(id: String): Boolean
    suspend fun clearActiveExam(id: String? = null)
    suspend fun upsertExamSheet(sheet: ExamSheet)
    /** Returns null when the requested sheet no longer exists. */
    suspend fun completeExam(sheetId: String, resultId: String, completedAt: String): ExamResult?
    /** Returns false when the sheet is missing or is the final remaining sheet. */
    suspend fun deleteExamSheet(id: String): Boolean
}
