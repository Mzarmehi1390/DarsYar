package com.mzarmehi1390.darsyar.core.database

import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

/**
 * Adds durable exam-taking session fields while preserving all existing app state.
 */
val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            "ALTER TABLE app_state ADD COLUMN activeExamQuestionNumber INTEGER NOT NULL DEFAULT 1",
        )
        db.execSQL(
            "ALTER TABLE app_state ADD COLUMN activeExamDeadlineEpochMillis INTEGER DEFAULT NULL",
        )
        db.execSQL(
            "ALTER TABLE app_state ADD COLUMN activeExamRemainingSeconds INTEGER NOT NULL DEFAULT 0",
        )
        db.execSQL(
            "ALTER TABLE app_state ADD COLUMN activeExamIsPaused INTEGER NOT NULL DEFAULT 0",
        )
    }
}
