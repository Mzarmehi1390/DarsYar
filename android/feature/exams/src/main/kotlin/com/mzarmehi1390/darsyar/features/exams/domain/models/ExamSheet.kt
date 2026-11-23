package com.mzarmehi1390.darsyar.features.exams.domain.models

/** Immutable representation of one independently saved answer sheet. */
data class ExamSheet(
    val id: String,
    val name: String,
    val questionCount: Int = 20,
    val durationSeconds: Int = 30 * 60,
    val negativeMarking: Boolean = false,
    val isCompleted: Boolean = false,
    val answers: Map<Int, Int> = emptyMap(),
    val answerKey: Map<Int, Int> = emptyMap(),
    val marked: Set<Int> = emptySet(),
)
