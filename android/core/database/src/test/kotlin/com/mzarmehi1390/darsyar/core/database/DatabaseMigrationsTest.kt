package com.mzarmehi1390.darsyar.core.database

import android.content.Context
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class DatabaseMigrationsTest {
    private var helper: SupportSQLiteOpenHelper? = null

    @After
    fun closeDatabase() {
        helper?.close()
    }

    @Test
    fun migration1To2_preservesExistingStateAndPausesLegacyActiveExam() {
        val database = openVersionOneDatabase()

        database.execSQL(
            """
            INSERT INTO app_state (
                id, activeExamId, legacyImportCompleted, updatedAtEpochMillis
            ) VALUES (0, 'legacy-active-exam', 1, 123456789)
            """.trimIndent(),
        )

        MIGRATION_1_2.migrate(database)

        database.query(
            """
            SELECT activeExamId, activeExamQuestionNumber,
                   activeExamDeadlineEpochMillis, activeExamRemainingSeconds,
                   activeExamIsPaused, legacyImportCompleted, updatedAtEpochMillis
            FROM app_state WHERE id = 0
            """.trimIndent(),
        ).use { cursor ->
            assertTrue(cursor.moveToFirst())
            assertEquals("legacy-active-exam", cursor.getString(0))
            assertEquals(1, cursor.getInt(1))
            assertTrue(cursor.isNull(2))
            assertEquals(0, cursor.getInt(3))
            assertEquals(1, cursor.getInt(4))
            assertEquals(1, cursor.getInt(5))
            assertEquals(123456789L, cursor.getLong(6))
        }
    }

    @Test
    fun migration1To2_doesNotPauseStateWithoutAnActiveExam() {
        val database = openVersionOneDatabase()

        database.execSQL(
            """
            INSERT INTO app_state (
                id, activeExamId, legacyImportCompleted, updatedAtEpochMillis
            ) VALUES (0, NULL, 0, 987654321)
            """.trimIndent(),
        )

        MIGRATION_1_2.migrate(database)

        database.query(
            "SELECT activeExamIsPaused FROM app_state WHERE id = 0",
        ).use { cursor ->
            assertTrue(cursor.moveToFirst())
            assertFalse(cursor.getInt(0) != 0)
        }
    }

    private fun openVersionOneDatabase(): SupportSQLiteDatabase {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val name = "darsyar-migration-v1-test.db"
        context.deleteDatabase(name)
        val configuration = SupportSQLiteOpenHelper.Configuration.builder(context)
            .name(name)
            .callback(
                object : SupportSQLiteOpenHelper.Callback(1) {
                    override fun onCreate(db: SupportSQLiteDatabase) {
                        db.execSQL(
                            """
                            CREATE TABLE IF NOT EXISTS app_state (
                                id INTEGER NOT NULL PRIMARY KEY,
                                activeExamId TEXT,
                                legacyImportCompleted INTEGER NOT NULL,
                                updatedAtEpochMillis INTEGER NOT NULL
                            )
                            """.trimIndent(),
                        )
                    }

                    override fun onUpgrade(
                        db: SupportSQLiteDatabase,
                        oldVersion: Int,
                        newVersion: Int,
                    ) = Unit
                },
            )
            .build()
        return FrameworkSQLiteOpenHelperFactory().create(configuration).also {
            helper = it
        }.writableDatabase
    }
}
