package com.mzarmehi1390.darsyar.core.database.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "app_state")
data class AppStateEntity(
    @PrimaryKey val id: Int = SINGLETON_ID,
    val activeExamId: String?,
    @ColumnInfo(defaultValue = "1")
    val activeExamQuestionNumber: Int = 1,
    @ColumnInfo(defaultValue = "NULL")
    val activeExamDeadlineEpochMillis: Long? = null,
    @ColumnInfo(defaultValue = "0")
    val activeExamRemainingSeconds: Int = 0,
    @ColumnInfo(defaultValue = "0")
    val activeExamIsPaused: Boolean = false,
    val legacyImportCompleted: Boolean = false,
    val updatedAtEpochMillis: Long,
) {
    companion object {
        const val SINGLETON_ID = 0
    }
}
