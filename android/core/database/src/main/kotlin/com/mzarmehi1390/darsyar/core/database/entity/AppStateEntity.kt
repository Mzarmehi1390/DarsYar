package com.mzarmehi1390.darsyar.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "app_state")
data class AppStateEntity(
    @PrimaryKey val id: Int = SINGLETON_ID,
    val activeExamId: String?,
    val legacyImportCompleted: Boolean = false,
    val updatedAtEpochMillis: Long,
) {
    companion object {
        const val SINGLETON_ID = 0
    }
}
