package com.mzarmehi1390.darsyar.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "study_tasks")
data class StudyTaskEntity(
    @PrimaryKey val id: String,
    val title: String,
    val subject: String,
    val isDone: Boolean,
    /** ISO-8601 local calendar date (yyyy-MM-dd), null for unscheduled tasks. */
    val dueDate: String?,
)
