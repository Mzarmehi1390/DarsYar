package com.mzarmehi1390.darsyar.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.mzarmehi1390.darsyar.core.database.DarsYarDatabase
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class DarsYarBackupServiceTest {
    private lateinit var database: DarsYarDatabase
    private lateinit var repository: DarsYarRepository
    private lateinit var backupService: DarsYarBackupService

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        database = Room.inMemoryDatabaseBuilder(
            context,
            DarsYarDatabase::class.java,
        ).allowMainThreadQueries().build()
        repository = DarsYarRepository(database)
        backupService = DarsYarBackupService(repository)
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun exportValidateAndRestore_roundTripsEveryCollection() = runBlocking {
        val task = StudyTask("task-1", "مرور هندسه", "ریاضی", true, "2026-11-26")
        val session = StudySession("session-1", "تمرین فیزیک", "فیزیک", 3, 720, 50, true, "2026-11-25")
        val exam = ExamSheet(
            id = "exam-1",
            name = "آزمون جامع",
            questionCount = 2,
            answers = mapOf(1 to 0, 2 to 1),
            answerKey = mapOf(1 to 0, 2 to 2),
            marked = setOf(2),
        )
        repository.upsertTask(task)
        repository.upsertStudySession(session)
        repository.upsertExamSheet(exam)
        repository.completeExam(exam.id, "result-1", "2026-11-24T12:00:00Z")
        repository.setActiveExam(exam.id)
        val original = repository.createBackupSnapshot()

        val backup = backupService.exportBackup()
        assertEquals(
            DarsYarBackupSummary(
                taskCount = 1,
                studySessionCount = 1,
                examCount = 1,
                resultCount = 1,
            ),
            backupService.validateBackup(backup),
        )

        repository.upsertTask(task.copy(title = "مقدار تغییریافته"))
        repository.upsertStudySession(session.copy(title = "جلسهٔ تغییریافته"))
        repository.upsertExamSheet(exam.copy(name = "آزمون تغییریافته"))

        backupService.restoreBackup(backup)

        assertEquals(original, repository.createBackupSnapshot())
    }

    @Test
    fun restoreBackup_rejectsInvalidInputWithoutMutatingExistingData() = runBlocking {
        val task = StudyTask("task-preserved", "اطلاعات محفوظ", "ریاضی", true)
        val exam = ExamSheet(id = "exam-preserved", name = "آزمون محفوظ")
        repository.upsertTask(task)
        repository.upsertExamSheet(exam)
        repository.setActiveExam(exam.id)
        val before = repository.createBackupSnapshot()

        assertThrows(BackupFormatException::class.java) {
            runBlocking {
                backupService.restoreBackup(
                    """{"app":"DarsYar","schemaVersion":1,"tasks":[{"id":"broken"}]}""",
                )
            }
        }

        assertEquals(before, repository.createBackupSnapshot())
    }

    @Test
    fun validateBackup_rejectsInvalidInputBeforeAnyRestoreCanOccur() = runBlocking {
        val task = StudyTask("task-1", "کار محفوظ", "عمومی")
        repository.upsertTask(task)
        repository.upsertExamSheet(ExamSheet(id = "exam-1", name = "آزمون"))
        val before = repository.createBackupSnapshot()

        assertThrows(BackupFormatException::class.java) {
            backupService.validateBackup("""{"app":"DarsYar","schemaVersion":"1"}""")
        }

        assertEquals(before, repository.createBackupSnapshot())
    }
}
