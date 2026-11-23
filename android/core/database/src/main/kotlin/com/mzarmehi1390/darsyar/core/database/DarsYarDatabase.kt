package com.mzarmehi1390.darsyar.core.database

import androidx.room.Database
import androidx.room.RoomDatabase
import com.mzarmehi1390.darsyar.core.database.dao.AppStateDao
import com.mzarmehi1390.darsyar.core.database.dao.ExamResultDao
import com.mzarmehi1390.darsyar.core.database.dao.ExamSheetDao
import com.mzarmehi1390.darsyar.core.database.dao.StudySessionDao
import com.mzarmehi1390.darsyar.core.database.dao.StudyTaskDao
import com.mzarmehi1390.darsyar.core.database.entity.AppStateEntity
import com.mzarmehi1390.darsyar.core.database.entity.ExamResultEntity
import com.mzarmehi1390.darsyar.core.database.entity.ExamSheetEntity
import com.mzarmehi1390.darsyar.core.database.entity.StudySessionEntity
import com.mzarmehi1390.darsyar.core.database.entity.StudyTaskEntity

@Database(
    entities = [
        StudyTaskEntity::class,
        AppStateEntity::class,
        StudySessionEntity::class,
        ExamSheetEntity::class,
        ExamResultEntity::class,
    ],
    version = 2,
    exportSchema = true,
)
abstract class DarsYarDatabase : RoomDatabase() {
    abstract fun appStateDao(): AppStateDao
    abstract fun studyTaskDao(): StudyTaskDao
    abstract fun studySessionDao(): StudySessionDao
    abstract fun examSheetDao(): ExamSheetDao
    abstract fun examResultDao(): ExamResultDao

    companion object {
        const val DATABASE_NAME = "darsyar.db"
    }
}
