package com.mzarmehi1390.darsyar.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.mzarmehi1390.darsyar.core.database.DarsYarDatabase
import com.mzarmehi1390.darsyar.core.database.entity.AppStateEntity
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class DarsYarDatabasePersistenceTest {
    @Test
    fun activeExamTimerSnapshot_survivesDatabaseCloseAndReopen() = runBlocking {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val databaseName = "darsyar-persistence-recovery-test.db"
        context.deleteDatabase(databaseName)

        val snapshot = AppStateEntity(
            activeExamId = "recovery-exam",
            activeExamQuestionNumber = 7,
            activeExamDeadlineEpochMillis = 1_795_789_200_000L,
            activeExamRemainingSeconds = 420,
            activeExamIsPaused = false,
            legacyImportCompleted = true,
            updatedAtEpochMillis = 1_795_788_780_000L,
        )

        val firstDatabase = Room.databaseBuilder(
            context,
            DarsYarDatabase::class.java,
            databaseName,
        ).allowMainThreadQueries().build()

        try {
            firstDatabase.appStateDao().upsert(snapshot)
        } finally {
            firstDatabase.close()
        }

        val reopenedDatabase = Room.databaseBuilder(
            context,
            DarsYarDatabase::class.java,
            databaseName,
        ).allowMainThreadQueries().build()

        try {
            val restored = DarsYarRepository(reopenedDatabase)
                .observeExamSession()
                .first()

            assertEquals(
                com.mzarmehi1390.darsyar.features.exams.domain.ExamSessionSnapshot(
                    examId = snapshot.activeExamId!!,
                    currentQuestionNumber = snapshot.activeExamQuestionNumber,
                    deadlineEpochMillis = snapshot.activeExamDeadlineEpochMillis,
                    remainingSeconds = snapshot.activeExamRemainingSeconds,
                    isPaused = snapshot.activeExamIsPaused,
                ),
                restored,
            )
            assertEquals(true, reopenedDatabase.appStateDao().get()?.legacyImportCompleted)
        } finally {
            reopenedDatabase.close()
            context.deleteDatabase(databaseName)
        }
    }
}
