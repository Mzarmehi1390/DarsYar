package com.mzarmehi1390.darsyar.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.mzarmehi1390.darsyar.core.database.entity.ExamResultEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface ExamResultDao {
    @Query("SELECT * FROM exam_results ORDER BY completedAt DESC, id")
    fun observeAll(): Flow<List<ExamResultEntity>>

    @Query("SELECT * FROM exam_results")
    suspend fun getAll(): List<ExamResultEntity>

    @Query("SELECT * FROM exam_results WHERE id = :id LIMIT 1")
    suspend fun findById(id: String): ExamResultEntity?

    @Query("SELECT COUNT(*) FROM exam_results")
    suspend fun count(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(items: List<ExamResultEntity>)

    @Query("DELETE FROM exam_results WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM exam_results WHERE examId = :examId OR (examId IS NULL AND examName = :legacyName)")
    suspend fun deleteForExam(examId: String, legacyName: String)

    @Query("DELETE FROM exam_results")
    suspend fun deleteAll()
}
