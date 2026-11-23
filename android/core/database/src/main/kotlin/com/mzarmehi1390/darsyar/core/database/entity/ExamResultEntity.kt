package com.mzarmehi1390.darsyar.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "exam_results")
data class ExamResultEntity(
    @PrimaryKey val id: String,
    val examId: String?,
    val examName: String,
    val completedAt: String,
    val questionCount: Int,
    val correct: Int,
    val wrong: Int,
    val unanswered: Int,
    val keyedQuestions: Int,
    val percentage: Double?,
    val negativeMarking: Boolean,
    val answersJson: String,
    val answerKeyJson: String,
)
