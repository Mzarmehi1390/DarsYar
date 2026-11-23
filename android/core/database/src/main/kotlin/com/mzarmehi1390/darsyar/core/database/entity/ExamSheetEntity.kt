package com.mzarmehi1390.darsyar.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "exam_sheets")
data class ExamSheetEntity(
    @PrimaryKey val id: String,
    val name: String,
    val questionCount: Int,
    val durationSeconds: Int,
    val negativeMarking: Boolean,
    val isCompleted: Boolean,
    /** JSON object with question numbers as keys and option indexes as values. */
    val answersJson: String,
    val answerKeyJson: String,
    /** JSON array of question numbers. */
    val markedJson: String,
)
