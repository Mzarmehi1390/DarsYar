package com.mzarmehi1390.darsyar.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.mzarmehi1390.darsyar.core.database.entity.ExamSheetEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface ExamSheetDao {
    @Query("SELECT * FROM exam_sheets ORDER BY rowid")
    fun observeAll(): Flow<List<ExamSheetEntity>>

    @Query("SELECT * FROM exam_sheets WHERE id = :id LIMIT 1")
    suspend fun findById(id: String): ExamSheetEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(items: List<ExamSheetEntity>)

    @Query("DELETE FROM exam_sheets WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM exam_sheets")
    suspend fun deleteAll()
}
