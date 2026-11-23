package com.mzarmehi1390.darsyar.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.mzarmehi1390.darsyar.core.database.DarsYarDatabase
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
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
}
