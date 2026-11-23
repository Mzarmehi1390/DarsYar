package com.mzarmehi1390.darsyar.features.exams.domain.models

/** Historical score plus immutable answer/key snapshots used for recalculation. */
data class ExamResult(
    val id: String,
    val examId: String?,
    val examName: String,
    val completedAt: String,
    val questionCount: Int,
    val correct: Int,
    val wrong: Int,
    val unanswered: Int,
    val keyedQuestions: Int,
    val percentage: Double?,
    val negativeMarking: Boolean = false,
    val answers: Map<Int, Int> = emptyMap(),
    val answerKey: Map<Int, Int> = emptyMap(),
)
