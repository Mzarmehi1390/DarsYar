package com.mzarmehi1390.darsyar.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.mzarmehi1390.darsyar.core.database.DarsYarDatabase
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerDayCopyService
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerDayCopyResult
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerWeekCopyService
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerWeekCopyResult
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.LocalDate

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class DarsYarRepositoryTest {
    private lateinit var database: DarsYarDatabase
    private lateinit var repository: DarsYarRepository

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        database = Room.inMemoryDatabaseBuilder(
            context,
            DarsYarDatabase::class.java,
        ).allowMainThreadQueries().build()
        repository = DarsYarRepository(database)
    }

    @After
    fun tearDown() {
        database.close()
    }


    @Test
    fun plannerRecords_supportCreateObserveUpdateAndDelete() = runBlocking {
        val task = StudyTask(
            id = "task-1",
            title = "Review algebra",
            subject = "Math",
            dueDate = "2026-11-25",
        )
        val session = StudySession(
            id = "session-1",
            title = "Physics review",
            subject = "Physics",
            weekday = 2,
            startMinutes = 10 * 60,
            durationMinutes = 45,
            scheduledDate = "2026-11-24",
        )

        repository.upsertTask(task)
        repository.upsertStudySession(session)

        assertEquals(listOf(task), repository.observeTasks().first())
        assertEquals(listOf(session), repository.observeStudySessions().first())

        val updatedTask = task.copy(title = "Updated algebra", done = true)
        val updatedSession = session.copy(
            title = "Updated physics",
            startMinutes = 11 * 60,
            completed = true,
        )
        repository.upsertTask(updatedTask)
        repository.upsertStudySession(updatedSession)

        assertEquals(listOf(updatedTask), repository.observeTasks().first())
        assertEquals(listOf(updatedSession), repository.observeStudySessions().first())

        repository.deleteTask(task.id)
        repository.deleteStudySession(session.id)

        assertTrue(repository.observeTasks().first().isEmpty())
        assertTrue(repository.observeStudySessions().first().isEmpty())
    }

    @Test
    fun activeExamSelection_isObservableAndClearedOnlyForMatchingId() = runBlocking {
        repository.upsertExamSheet(ExamSheet(id = "exam-1", name = "First"))
        repository.upsertExamSheet(ExamSheet(id = "exam-2", name = "Second"))

        assertTrue(repository.setActiveExam("exam-1"))
        assertEquals("exam-1", database.appStateDao().get()?.activeExamId)

        repository.clearActiveExam("exam-2")
        assertEquals("exam-1", database.appStateDao().get()?.activeExamId)

        repository.clearActiveExam("exam-1")
        assertNull(database.appStateDao().get()?.activeExamId)
        assertFalse(repository.setActiveExam("missing"))
    }

    @Test
    fun examSheet_roundTripsAllConfigurationAndAnswerStateThroughRoom() = runBlocking {
        val sheet = ExamSheet(
            id = "configured-exam",
            name = "آزمون جامع",
            questionCount = 25,
            durationSeconds = 45 * 60,
            negativeMarking = true,
            answers = mapOf(1 to 2, 7 to 0, 25 to 3),
            answerKey = mapOf(1 to 2, 2 to 1, 25 to 3),
            marked = setOf(7, 25),
        )

        repository.upsertExamSheet(sheet)

        assertEquals(sheet, repository.observeExamSheets().first().single())
        val persisted = database.examSheetDao().findById(sheet.id)
        assertNotNull(persisted)
        assertEquals(25, persisted?.questionCount)
        assertEquals(45 * 60, persisted?.durationSeconds)
        assertTrue(persisted?.negativeMarking == true)
        assertEquals("{\"1\":2,\"7\":0,\"25\":3}", persisted?.answersJson)
        assertEquals("{\"1\":2,\"2\":1,\"25\":3}", persisted?.answerKeyJson)
        assertEquals("[7,25]", persisted?.markedJson)

        val updated = sheet.copy(
            questionCount = 30,
            durationSeconds = 60 * 60,
            negativeMarking = false,
            answers = mapOf(1 to 0, 30 to 3),
            answerKey = mapOf(1 to 0, 2 to 1, 30 to 3),
            marked = setOf(2, 30),
        )
        repository.upsertExamSheet(updated)

        assertEquals(updated, repository.observeExamSheets().first().single())
        val updatedPersisted = database.examSheetDao().findById(sheet.id)
        assertNotNull(updatedPersisted)
        assertEquals(30, updatedPersisted?.questionCount)
        assertEquals(60 * 60, updatedPersisted?.durationSeconds)
        assertFalse(updatedPersisted?.negativeMarking ?: true)
        assertEquals("{\"1\":0,\"30\":3}", updatedPersisted?.answersJson)
        assertEquals("{\"1\":0,\"2\":1,\"30\":3}", updatedPersisted?.answerKeyJson)
        assertEquals("[2,30]", updatedPersisted?.markedJson)
    }

    @Test
    fun completingActiveExam_clearsActiveSelectionAtomically() = runBlocking {
        repository.upsertExamSheet(ExamSheet(id = "exam-1", name = "Active"))
        assertTrue(repository.setActiveExam("exam-1"))

        repository.completeExam("exam-1", "result-1", "2026-11-23T12:00:00Z")

        assertNull(database.appStateDao().get()?.activeExamId)
        assertNotNull(database.examResultDao().findById("result-1"))
    }

    @Test
    fun completeExam_atomicallyMarksSheetAndPersistsScoreSnapshot() = runBlocking {
        val sheet = ExamSheet(
            id = "exam-1",
            name = "Algebra",
            questionCount = 3,
            answers = mapOf(1 to 2, 2 to 1),
            answerKey = mapOf(1 to 2, 2 to 0),
        )
        repository.upsertExamSheet(sheet)

        val result = repository.completeExam(
            sheetId = sheet.id,
            resultId = "result-1",
            completedAt = "2026-11-23T12:00:00Z",
        )

        assertNotNull(result)
        assertEquals(1, result?.correct)
        assertEquals(1, result?.wrong)
        assertEquals(1, result?.unanswered)
        assertEquals(50.0, result?.percentage ?: -1.0, 0.001)

        val persistedSheet = database.examSheetDao().findById(sheet.id)
        val persistedResult = database.examResultDao().findById("result-1")
        assertTrue(persistedSheet?.isCompleted == true)
        assertNotNull(persistedResult)
        assertEquals(sheet.id, persistedResult?.examId)
        assertEquals(50.0, persistedResult?.percentage ?: -1.0, 0.001)
        assertEquals("{\"1\":2,\"2\":0}", persistedResult?.answerKeyJson)
    }

    @Test
    fun completeExam_rejectsDuplicateResultIdWithoutCompletingSecondSheet() = runBlocking {
        repository.upsertExamSheet(ExamSheet(id = "exam-1", name = "First"))
        repository.completeExam("exam-1", "shared-result", "2026-11-23T12:00:00Z")
        repository.upsertExamSheet(ExamSheet(id = "exam-2", name = "Second"))

        assertThrows(IllegalArgumentException::class.java) {
            runBlocking {
                repository.completeExam("exam-2", "shared-result", "2026-11-23T12:05:00Z")
            }
        }

        assertFalse(database.examSheetDao().findById("exam-2")?.isCompleted ?: true)
        assertEquals(1, database.examResultDao().getAll().size)
    }

    @Test
    fun changingAnswerKey_recalculatesOnlyTheLinkedHistoricalSnapshot() = runBlocking {
        val sheet = ExamSheet(
            id = "exam-1",
            name = "Physics",
            questionCount = 2,
            answers = mapOf(1 to 0, 2 to 2),
            answerKey = mapOf(1 to 0, 2 to 1),
        )
        repository.upsertExamSheet(sheet)
        repository.completeExam(sheet.id, "result-1", "2026-11-23T12:00:00Z")
        repository.upsertExamSheet(sheet.copy(answerKey = mapOf(1 to 0, 2 to 2)))

        val result = database.examResultDao().findById("result-1")
        assertEquals(2, result?.correct)
        assertEquals(0, result?.wrong)
        assertEquals(100.0, result?.percentage ?: -1.0, 0.001)
        assertEquals("{\"1\":0,\"2\":2}", result?.answerKeyJson)
    }

    @Test
    fun renamingAndChangingKey_preservesLegacyNameLinkedHistory() = runBlocking {
        val sheet = ExamSheet(
            id = "exam-1",
            name = "Old name",
            questionCount = 1,
            answers = mapOf(1 to 0),
            answerKey = mapOf(1 to 0),
        )
        repository.upsertExamSheet(sheet)
        database.examResultDao().upsertAll(
            listOf(
                ExamResult(
                    id = "legacy-result",
                    examId = null,
                    examName = "Old name",
                    completedAt = "2026-11-22T12:00:00Z",
                    questionCount = 1,
                    correct = 1,
                    wrong = 0,
                    unanswered = 0,
                    keyedQuestions = 1,
                    percentage = 100.0,
                    answers = mapOf(1 to 0),
                    answerKey = mapOf(1 to 0),
                ).toEntity(),
            ),
        )

        repository.upsertExamSheet(
            sheet.copy(
                name = "New name",
                answerKey = mapOf(1 to 1),
            ),
        )

        val result = database.examResultDao().findById("legacy-result")
        assertEquals("New name", result?.examName)
        assertEquals(0, result?.correct)
        assertEquals(1, result?.wrong)
        assertEquals(0.0, result?.percentage ?: -1.0, 0.001)
        assertEquals("{\"1\":1}", result?.answerKeyJson)
    }

    @Test
    fun duplicateSheetNames_doNotRenameOrRecalculateAmbiguousLegacyHistory() = runBlocking {
        val first = ExamSheet(
            id = "exam-1",
            name = "Shared name",
            questionCount = 1,
            answerKey = mapOf(1 to 0),
        )
        repository.upsertExamSheet(first)
        repository.upsertExamSheet(first.copy(id = "exam-2"))

        val legacy = ExamResult(
            id = "legacy-result",
            examId = null,
            examName = "Shared name",
            completedAt = "2026-11-22T12:00:00Z",
            questionCount = 1,
            correct = 1,
            wrong = 0,
            unanswered = 0,
            keyedQuestions = 1,
            percentage = 100.0,
            answers = mapOf(1 to 0),
            answerKey = mapOf(1 to 0),
        )
        database.examResultDao().upsertAll(listOf(legacy.toEntity()))

        repository.upsertExamSheet(
            first.copy(
                name = "Renamed first",
                answerKey = mapOf(1 to 1),
            ),
        )

        val persisted = database.examResultDao().findById("legacy-result")?.toDomain()
        assertEquals("Shared name", persisted?.examName)
        assertEquals(1, persisted?.correct)
        assertEquals(0, persisted?.wrong)
        assertEquals(100.0, persisted?.percentage ?: -1.0, 0.001)
        assertEquals(mapOf(1 to 0), persisted?.answerKey)
    }

    @Test
    fun deletingOneOfDuplicateNamedSheets_preservesAmbiguousLegacyHistory() = runBlocking {
        val first = ExamSheet(id = "exam-1", name = "Duplicate")
        repository.upsertExamSheet(first)
        repository.upsertExamSheet(ExamSheet(id = "exam-2", name = "Duplicate"))
        repository.completeExam(first.id, "linked-result", "2026-11-23T12:00:00Z")

        val legacy = ExamResult(
            id = "legacy-result",
            examId = null,
            examName = "Duplicate",
            completedAt = "2026-11-22T12:00:00Z",
            questionCount = 1,
            correct = 1,
            wrong = 0,
            unanswered = 0,
            keyedQuestions = 1,
            percentage = 100.0,
            answers = mapOf(1 to 0),
            answerKey = mapOf(1 to 0),
        )
        database.examResultDao().upsertAll(listOf(legacy.toEntity()))

        assertTrue(repository.deleteExamSheet(first.id))
        assertNull(database.examResultDao().findById("linked-result"))
        assertNotNull(database.examResultDao().findById("legacy-result"))
        assertNotNull(database.examSheetDao().findById("exam-2"))
    }

    @Test
    fun deletingSheet_removesItsHistoryAndProtectsLastSheet() = runBlocking {
        repository.upsertExamSheet(ExamSheet(id = "exam-1", name = "First"))
        repository.upsertExamSheet(ExamSheet(id = "exam-2", name = "Second"))
        repository.completeExam("exam-1", "result-1", "2026-11-23T12:00:00Z")

        assertTrue(repository.deleteExamSheet("exam-1"))
        assertNull(database.examResultDao().findById("result-1"))
        assertNotNull(database.examSheetDao().findById("exam-2"))
        assertFalse(repository.deleteExamSheet("exam-2"))
        assertNotNull(database.examSheetDao().findById("exam-2"))
    }


    @Test
    fun copyWeekPlan_copiesAndResetsItemsButNeverOverwritesAnOccupiedTargetWeek() = runBlocking {
        val sourceStart = LocalDate.parse("2026-11-21")
        val session = StudySession("source-session", "مرور فیزیک", "فیزیک", 2, 600, 45, true, "2026-11-24")
        val task = StudyTask("source-task", "تمرین جبر", "ریاضی", true, "2026-11-25")
        repository.upsertStudySession(session)
        repository.upsertTask(task)
        val service = PlannerWeekCopyService()
        val plan = service.createNextWeekPlan(
            repository.observeStudySessions().first(), repository.observeTasks().first(), sourceStart,
            { "copy-${it.id}" }, { "copy-${it.id}" },
        )

        assertEquals(PlannerWeekCopyResult.Copied(1, 1), repository.copyWeekPlan(plan))
        val copiedSession = repository.observeStudySessions().first().single { it.id == "copy-source-session" }
        val copiedTask = repository.observeTasks().first().single { it.id == "copy-source-task" }
        assertEquals("2026-12-01", copiedSession.scheduledDate)
        assertFalse(copiedSession.completed)
        assertEquals("2026-12-02", copiedTask.dueDate)
        assertFalse(copiedTask.done)

        val protected = StudyTask("protected", "کار مقصد", "عمومی", dueDate = "2026-12-03")
        repository.upsertTask(protected)
        val second = service.createNextWeekPlan(
            repository.observeStudySessions().first(), repository.observeTasks().first(), sourceStart,
            { "second-${it.id}" }, { "second-${it.id}" },
        )
        assertEquals(PlannerWeekCopyResult.TargetWeekNotEmpty, repository.copyWeekPlan(second))
        assertEquals(protected, repository.observeTasks().first().single { it.id == protected.id })
        assertNull(repository.observeStudySessions().first().firstOrNull { it.id == "second-source-session" })
    }


    @Test
    fun copyDayPlan_persistsCopiesAndResetsCompletionWithoutChangingSourceOrOtherDays() = runBlocking {
        val sourceDate = LocalDate.parse("2026-11-24")
        val targetDate = LocalDate.parse("2026-11-26")
        val dated = StudySession("dated-source", "Physics", "Science", 0, 9 * 60, 45, true, "2026-11-24")
        val legacy = StudySession("legacy-source", "Math", "Math", 2, 10 * 60, 45, true)
        val unrelated = StudySession("unrelated", "Chemistry", "Science", 3, 12 * 60, 30, false, "2026-11-25")
        repository.upsertStudySession(dated)
        repository.upsertStudySession(legacy)
        repository.upsertStudySession(unrelated)

        val plan = PlannerDayCopyService().createPlan(
            repository.observeStudySessions().first(), sourceDate, targetDate,
        ) { "copy-${it.id}" }

        assertEquals(PlannerDayCopyResult.Copied(2), repository.copyDayPlan(plan))
        val persisted = repository.observeStudySessions().first().associateBy(StudySession::id)
        assertEquals(dated, persisted[dated.id])
        assertEquals(legacy, persisted[legacy.id])
        assertEquals(unrelated, persisted[unrelated.id])
        val datedCopy = persisted.getValue("copy-dated-source")
        val legacyCopy = persisted.getValue("copy-legacy-source")
        assertEquals("2026-11-26", datedCopy.scheduledDate)
        assertEquals("2026-11-26", legacyCopy.scheduledDate)
        assertEquals(4, datedCopy.weekday)
        assertEquals(4, legacyCopy.weekday)
        assertFalse(datedCopy.completed)
        assertFalse(legacyCopy.completed)
        assertEquals(5, persisted.size)
    }

    @Test
    fun copyDayPlan_rejectsOccupiedTargetAndPreservesEveryExistingRecord() = runBlocking {
        val sourceDate = LocalDate.parse("2026-11-24")
        val targetDate = LocalDate.parse("2026-11-26")
        val source = StudySession("source", "Review", "Physics", 2, 9 * 60, 45, false, "2026-11-24")
        val occupied = StudySession("target-existing", "Existing target", "Math", 4, 14 * 60, 30, false, "2026-11-26")
        repository.upsertStudySession(source)
        repository.upsertStudySession(occupied)
        val before = repository.observeStudySessions().first()
        val plan = PlannerDayCopyService().createPlan(before, sourceDate, targetDate) { "copy-${it.id}" }

        assertEquals(PlannerDayCopyResult.TargetDateNotEmpty, repository.copyDayPlan(plan))
        assertEquals(before, repository.observeStudySessions().first())
    }

    @Test
    fun copyDayPlan_detectsChangedSourceAndDoesNotWriteStaleCopies() = runBlocking {
        val sourceDate = LocalDate.parse("2026-11-24")
        val targetDate = LocalDate.parse("2026-11-26")
        val source = StudySession("source", "Original", "Physics", 2, 9 * 60, 45, false, "2026-11-24")
        repository.upsertStudySession(source)
        val plan = PlannerDayCopyService().createPlan(
            repository.observeStudySessions().first(), sourceDate, targetDate,
        ) { "copy-${it.id}" }
        val changed = source.copy(title = "Edited after preview")
        repository.upsertStudySession(changed)

        assertEquals(PlannerDayCopyResult.SourceChanged, repository.copyDayPlan(plan))
        assertEquals(listOf(changed), repository.observeStudySessions().first())
    }

    @Test
    fun copyDayPlan_rejectsOverlappingCopiesWithoutPartiallyPersistingThem() = runBlocking {
        val sourceDate = LocalDate.parse("2026-11-24")
        val targetDate = LocalDate.parse("2026-11-26")
        val first = StudySession("first-source", "First", "Physics", 2, 9 * 60, 45, false, "2026-11-24")
        val second = StudySession("second-source", "Second", "Math", 2, 9 * 60 + 30, 45, false, "2026-11-24")
        repository.upsertStudySession(first)
        repository.upsertStudySession(second)
        val before = repository.observeStudySessions().first()
        val plan = PlannerDayCopyService().createPlan(before, sourceDate, targetDate) { "copy-${it.id}" }

        assertEquals(PlannerDayCopyResult.SessionConflict, repository.copyDayPlan(plan))
        assertEquals(before, repository.observeStudySessions().first())
        assertTrue(repository.observeStudySessions().first().none { it.id.startsWith("copy-") })
    }

    @Test
    fun createBackupSnapshot_capturesEveryCollectionAndActiveExamConsistently() = runBlocking {
        val task = StudyTask("backup-task", "مرور هندسه", "ریاضی", true, "2026-11-26")
        val session = StudySession("backup-session", "تمرین فیزیک", "فیزیک", 3, 720, 50, true, "2026-11-25")
        val exam = ExamSheet(
            id = "backup-exam",
            name = "آزمون جامع",
            questionCount = 3,
            durationSeconds = 1200,
            negativeMarking = true,
            answers = mapOf(1 to 2, 3 to 1),
            answerKey = mapOf(1 to 2, 2 to 0, 3 to 1),
            marked = setOf(2),
        )
        repository.upsertTask(task)
        repository.upsertStudySession(session)
        repository.upsertExamSheet(exam)
        repository.completeExam(exam.id, "backup-result", "2026-11-24T12:00:00Z")
        assertTrue(repository.setActiveExam(exam.id))

        val snapshot = repository.createBackupSnapshot()

        assertEquals(listOf(task), snapshot.tasks)
        assertEquals(listOf(session), snapshot.studySessions)
        assertEquals(listOf(exam.copy(isCompleted = true)), snapshot.exams)
        assertEquals(listOf(database.examResultDao().findById("backup-result")!!.toDomain()), snapshot.results)
        assertEquals(exam.id, snapshot.activeExamId)
    }

}
