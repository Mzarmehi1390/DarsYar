package com.mzarmehi1390.darsyar.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.mzarmehi1390.darsyar.core.database.entity.StudyTaskEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface StudyTaskDao {
    @Query("SELECT * FROM study_tasks ORDER BY dueDate IS NULL, dueDate, id")
    fun observeAll(): Flow<List<StudyTaskEntity>>

    @Query("SELECT * FROM study_tasks WHERE id = :id LIMIT 1")
    suspend fun findById(id: String): StudyTaskEntity?

    @Query("SELECT COUNT(*) FROM study_tasks")
    suspend fun count(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(items: List<StudyTaskEntity>)

    @Query("DELETE FROM study_tasks WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM study_tasks")
    suspend fun deleteAll()
}
