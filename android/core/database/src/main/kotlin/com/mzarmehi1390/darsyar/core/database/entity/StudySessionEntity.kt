package com.mzarmehi1390.darsyar.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "study_sessions")
data class StudySessionEntity(
    @PrimaryKey val id: String,
    val title: String,
    val subject: String,
    /** Sunday = 0 ... Saturday = 6; retained for legacy weekday-only records. */
    val weekday: Int,
    val startMinutes: Int,
    val durationMinutes: Int,
    val completed: Boolean,
    /** ISO-8601 local calendar date (yyyy-MM-dd), null for legacy records. */
    val scheduledDate: String?,
)
