package com.mzarmehi1390.darsyar.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.mzarmehi1390.darsyar.core.database.entity.AppStateEntity

@Dao
interface AppStateDao {
    @Query("SELECT * FROM app_state WHERE id = 0 LIMIT 1")
    suspend fun get(): AppStateEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(state: AppStateEntity)
}
