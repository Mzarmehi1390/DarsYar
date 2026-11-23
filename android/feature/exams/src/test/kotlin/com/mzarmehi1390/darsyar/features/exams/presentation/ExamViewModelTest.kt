package com.mzarmehi1390.darsyar.features.exams.presentation

import com.mzarmehi1390.darsyar.features.exams.domain.ExamRepository
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ExamViewModelTest {
    private val mainDispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(mainDispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun saveSheet_rejectsOutOfRangeAnswerBeforePersistence() = runTest(mainDispatcher) {
        val repository = FakeExamRepository()
        val viewModel = ExamViewModel(repository)
        var result: ExamActionResult? = null

        viewModel.saveSheet(
            ExamSheet(
                id = "exam-1",
                name = "آزمون ریاضی",
                questionCount = 10,
                answers = mapOf(11 to 2),
            ),
        ) { result = it }
        advanceUntilIdle()

        assertTrue(result is ExamActionResult.Invalid)
        assertTrue(repository.savedSheets.isEmpty())
    }

    @Test
    fun saveSheet_persistsValidSheetAndReportsSuccess() = runTest(mainDispatcher) {
        val repository = FakeExamRepository()
        val viewModel = ExamViewModel(repository)
        val sheet = ExamSheet(
            id = "exam-1",
            name = "آزمون ریاضی",
            questionCount = 10,
            durationSeconds = 45 * 60,
            answers = mapOf(1 to 2, 4 to 1),
            answerKey = mapOf(1 to 2, 4 to 0),
            marked = setOf(4),
        )
        var result: ExamActionResult? = null

        viewModel.saveSheet(sheet) { result = it }
        advanceUntilIdle()

        assertEquals(sheet, repository.sheets.value.single())
        assertEquals(ExamActionResult.Success, result)
    }

    @Test
    fun completeExam_returnsPersistedResult() = runTest(mainDispatcher) {
        val expected = ExamResult(
            id = "result-1",
            examId = "exam-1",
            examName = "آزمون ریاضی",
            completedAt = "2026-11-23T12:00:00Z",
            questionCount = 2,
            correct = 1,
            wrong = 1,
            unanswered = 0,
            keyedQuestions = 2,
            percentage = 50.0,
        )
        val repository = FakeExamRepository(
            initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون ریاضی")),
            completion = expected,
        )
        val viewModel = ExamViewModel(repository)
        var result: ExamActionResult? = null

        viewModel.completeExam(
            sheetId = "exam-1",
            completedAt = expected.completedAt,
            resultId = expected.id,
        ) { result = it }
        advanceUntilIdle()

        assertEquals(ExamActionResult.Completed(expected), result)
        assertEquals("exam-1", repository.completedSheetId)
    }

    @Test
    fun deleteSheet_distinguishesMissingSheetFromFinalSheet() = runTest(mainDispatcher) {
        val repository = FakeExamRepository(
            initialSheets = listOf(ExamSheet(id = "only-sheet", name = "تنها آزمون")),
        )
        val viewModel = ExamViewModel(repository)
        val stateJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            viewModel.uiState.collect {}
        }
        advanceUntilIdle()

        var missingResult: ExamActionResult? = null
        viewModel.deleteSheet("missing") { missingResult = it }
        advanceUntilIdle()
        assertEquals(ExamActionResult.SheetNotFound, missingResult)

        var lastResult: ExamActionResult? = null
        viewModel.deleteSheet("only-sheet") { lastResult = it }
        advanceUntilIdle()
        assertEquals(ExamActionResult.CannotDeleteLastSheet, lastResult)
        stateJob.cancel()
    }

    private class FakeExamRepository(
        initialSheets: List<ExamSheet> = emptyList(),
        private val completion: ExamResult? = null,
    ) : ExamRepository {
        val sheets = MutableStateFlow(initialSheets)
        private val results = MutableStateFlow<List<ExamResult>>(emptyList())
        val savedSheets = mutableListOf<ExamSheet>()
        var completedSheetId: String? = null

        override fun observeExamSheets(): Flow<List<ExamSheet>> = sheets.asStateFlow()
        override fun observeExamResults(): Flow<List<ExamResult>> = results.asStateFlow()

        override suspend fun upsertExamSheet(sheet: ExamSheet) {
            savedSheets += sheet
            sheets.value = sheets.value.filterNot { it.id == sheet.id } + sheet
        }

        override suspend fun completeExam(
            sheetId: String,
            resultId: String,
            completedAt: String,
        ): ExamResult? {
            completedSheetId = sheetId
            return completion
        }

        override suspend fun deleteExamSheet(id: String): Boolean {
            if (sheets.value.size <= 1 || sheets.value.none { it.id == id }) return false
            sheets.value = sheets.value.filterNot { it.id == id }
            return true
        }
    }
}
