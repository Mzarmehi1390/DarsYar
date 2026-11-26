package com.mzarmehi1390.darsyar.features.exams.presentation

import com.mzarmehi1390.darsyar.features.exams.domain.ExamRepository
import com.mzarmehi1390.darsyar.features.exams.domain.ExamSessionSnapshot
import com.mzarmehi1390.darsyar.features.exams.domain.ExamTakingState
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
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
            negativeMarking = true,
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
    fun startExam_persistsExistingSheetAsActiveAndRejectsMissingSheet() = runTest(mainDispatcher) {
        val repository = FakeExamRepository(
            initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون ریاضی")),
        )
        val viewModel = ExamViewModel(repository)
        val stateJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            viewModel.uiState.collect {}
        }
        advanceUntilIdle()

        var started: ExamActionResult? = null
        viewModel.startExam("exam-1") { started = it }
        advanceUntilIdle()
        assertEquals(ExamActionResult.Success, started)
        assertEquals("exam-1", viewModel.uiState.value.activeExamId)

        var missing: ExamActionResult? = null
        viewModel.startExam("missing") { missing = it }
        advanceUntilIdle()
        assertEquals(ExamActionResult.SheetNotFound, missing)
        assertEquals("exam-1", viewModel.uiState.value.activeExamId)
        stateJob.cancel()
    }

    @Test
    fun manualFinishKeepsTimerRunningAndCanBeCancelled() = runTest(mainDispatcher) {
        val repository = FakeExamRepository(
            initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون زمان‌دار", durationSeconds = 10)),
        )
        val viewModel = ExamViewModel(repository)
        val stateJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            viewModel.uiState.collect {}
        }
        var now = 5_000L
        viewModel.nowEpochMillis = { now }
        viewModel.startExam("exam-1")
        advanceUntilIdle()

        assertTrue(viewModel.beginFinish())
        assertTrue(viewModel.uiState.value.takingState.isFinishing)
        now += 3_250L
        viewModel.refreshTimer()

        assertEquals(7, viewModel.uiState.value.takingState.remainingSeconds)
        assertTrue(viewModel.uiState.value.takingState.isTaking)
        assertTrue(viewModel.uiState.value.takingState.isFinishing)

        viewModel.cancelFinish()
        assertTrue(viewModel.uiState.value.takingState.isTaking)
        assertTrue(!viewModel.uiState.value.takingState.isFinishing)
        assertEquals(7, viewModel.uiState.value.takingState.remainingSeconds)
        stateJob.cancel()
    }

    @Test
    fun timerExpiryDuringManualFinishStillCompletesExamAutomatically() = runTest(mainDispatcher) {
        val expected = ExamResult(
            id = "result-expired-manual",
            examId = "exam-1",
            examName = "آزمون زمان‌دار",
            completedAt = "2026-11-23T12:00:00Z",
            questionCount = 1,
            correct = 0,
            wrong = 0,
            unanswered = 1,
            keyedQuestions = 1,
            percentage = 0.0,
        )
        val repository = FakeExamRepository(
            initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون زمان‌دار", questionCount = 1, durationSeconds = 5)),
            completion = expected,
        )
        val viewModel = ExamViewModel(repository)
        val stateJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            viewModel.uiState.collect {}
        }
        var now = 10_000L
        viewModel.nowEpochMillis = { now }
        viewModel.startExam("exam-1")
        advanceUntilIdle()

        assertTrue(viewModel.beginFinish())
        now += 5_000L
        viewModel.refreshTimer()
        advanceUntilIdle()

        assertEquals(1, repository.completionCalls)
        assertEquals(ExamTakingState(), viewModel.uiState.value.takingState)
        stateJob.cancel()
    }

    @Test
    fun clearActiveExam_clearsPersistedSelection() = runTest(mainDispatcher) {
        val repository = FakeExamRepository(
            initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون ریاضی")),
        )
        val viewModel = ExamViewModel(repository)
        val stateJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            viewModel.uiState.collect {}
        }
        advanceUntilIdle()
        viewModel.startExam("exam-1")
        advanceUntilIdle()
        viewModel.clearActiveExam("exam-1")
        advanceUntilIdle()
        assertEquals(null, viewModel.uiState.value.activeExamId)
        stateJob.cancel()
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
    fun completeExam_ignoresConcurrentDuplicateSubmission() = runTest(mainDispatcher) {
        val expected = ExamResult(
            id = "result-1",
            examId = "exam-1",
            examName = "آزمون ریاضی",
            completedAt = "2026-11-23T12:00:00Z",
            questionCount = 1,
            correct = 1,
            wrong = 0,
            unanswered = 0,
            keyedQuestions = 1,
            percentage = 100.0,
        )
        val repository = FakeExamRepository(
            initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون ریاضی")),
            completion = expected,
        )
        val viewModel = ExamViewModel(repository)
        var callbacks = 0

        viewModel.completeExam("exam-1", expected.completedAt, "result-1") { callbacks++ }
        viewModel.completeExam("exam-1", expected.completedAt, "result-2") { callbacks++ }
        advanceUntilIdle()

        assertEquals(1, repository.completionCalls)
        assertEquals(1, callbacks)
    }

    @Test
    fun refreshTimer_autoSubmitsExpiredExamAndResetsSession() = runTest(mainDispatcher) {
        val expected = ExamResult(
            id = "result-expired",
            examId = "exam-1",
            examName = "آزمون زمان‌دار",
            completedAt = "2026-11-23T12:00:00Z",
            questionCount = 1,
            correct = 1,
            wrong = 0,
            unanswered = 0,
            keyedQuestions = 1,
            percentage = 100.0,
        )
        val repository = FakeExamRepository(
            initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون زمان‌دار", questionCount = 1, durationSeconds = 10)),
            completion = expected,
        )
        val viewModel = ExamViewModel(repository)
        var now = 5_000L
        viewModel.nowEpochMillis = { now }
        viewModel.startExam("exam-1")
        advanceUntilIdle()

        now += 10_000L
        viewModel.refreshTimer()
        advanceUntilIdle()

        assertEquals(1, repository.completionCalls)
        assertEquals(null, repository.activeExam.value)
        assertEquals(null, repository.examSession.value)
    }

    @Test
    fun restoreExpiredSession_autoSubmitsAfterProcessRecreation() = runTest(mainDispatcher) {
        val expected = ExamResult(
            id = "result-restored",
            examId = "exam-1",
            examName = "آزمون بازیابی‌شده",
            completedAt = "2026-11-23T12:00:00Z",
            questionCount = 1,
            correct = 0,
            wrong = 0,
            unanswered = 1,
            keyedQuestions = 1,
            percentage = 0.0,
        )
        val repository = FakeExamRepository(
            initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون بازیابی‌شده", questionCount = 1, durationSeconds = 10)),
            completion = expected,
        )
        repository.setActiveExam("exam-1")
        repository.saveExamSession(
            ExamSessionSnapshot(
                examId = "exam-1",
                currentQuestionNumber = 1,
                deadlineEpochMillis = 15_000L,
                remainingSeconds = 0,
                isPaused = false,
            ),
        )
        val viewModel = ExamViewModel(repository)
        viewModel.nowEpochMillis = { 20_000L }
        advanceUntilIdle()

        viewModel.refreshTimer()
        advanceUntilIdle()

        assertEquals(1, repository.completionCalls)
        assertEquals(null, repository.activeExam.value)
        assertEquals(null, repository.examSession.value)
    }

    @Test
    fun failedAutoSubmissionCanBeRetried() = runTest(mainDispatcher) {
        val expected = ExamResult(
            id = "result-retry",
            examId = "exam-1",
            examName = "آزمون قابل تکرار",
            completedAt = "2026-11-23T12:00:00Z",
            questionCount = 1,
            correct = 1,
            wrong = 0,
            unanswered = 0,
            keyedQuestions = 1,
            percentage = 100.0,
        )
        val repository = FakeExamRepository(
            initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون قابل تکرار", questionCount = 1, durationSeconds = 10)),
            completion = expected,
        )
        repository.completionFailure = IllegalStateException("temporary storage failure")
        val viewModel = ExamViewModel(repository)
        val stateJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            viewModel.uiState.collect {}
        }
        var now = 5_000L
        viewModel.nowEpochMillis = { now }
        viewModel.startExam("exam-1")
        advanceUntilIdle()

        now += 10_000L
        viewModel.refreshTimer()
        advanceUntilIdle()
        assertEquals(1, repository.completionCalls)
        assertEquals(true, viewModel.uiState.value.takingState.isFinishing)
        assertEquals(false, viewModel.uiState.value.takingState.isSavingResult)

        repository.completionFailure = null
        viewModel.completeExam("exam-1", expected.completedAt, "result-retry")
        advanceUntilIdle()

        assertEquals(2, repository.completionCalls)
        assertEquals(null, viewModel.uiState.value.takingState.examId)
        stateJob.cancel()
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

    @Test
    fun startExam_sameExamPreservesPersistedSession() = runTest(mainDispatcher) {
        val sheet = ExamSheet(id = "exam-1", name = "آزمون ریاضی", questionCount = 12)
        val repository = FakeExamRepository(initialSheets = listOf(sheet))
        val viewModel = ExamViewModel(repository)
        val stateJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            viewModel.uiState.collect {}
        }
        advanceUntilIdle()
        viewModel.startExam("exam-1")
        advanceUntilIdle()
        val saved = ExamSessionSnapshot(
            examId = "exam-1",
            currentQuestionNumber = 7,
            deadlineEpochMillis = 1_800_000_000_000,
            remainingSeconds = 900,
            isPaused = false,
        )
        assertTrue(repository.saveExamSession(saved))

        viewModel.startExam("exam-1")
        advanceUntilIdle()

        assertEquals(saved, repository.examSession.value)
        stateJob.cancel()
    }

    @Test
    fun pauseExam_flushesPendingNavigationImmediately() = runTest(mainDispatcher) {
        val repository = FakeExamRepository(
            initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون", questionCount = 8)),
        )
        val viewModel = ExamViewModel(repository)
        viewModel.startExam("exam-1")
        advanceUntilIdle()

        viewModel.selectQuestion(5)
        viewModel.pauseExam()
        advanceUntilIdle()

        assertEquals(5, repository.examSession.value?.currentQuestionNumber)
        assertEquals(true, repository.examSession.value?.isPaused)
        assertEquals(1, repository.sessionSaveCalls - 1)
    }

    @Test
    fun overlappingPauseAndResumePersistenceIsSerializedAndKeepsLatestState() = runTest(mainDispatcher) {
        val repository = FakeExamRepository(
            initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون", questionCount = 8)),
        )
        val viewModel = ExamViewModel(repository)
        val stateJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            viewModel.uiState.collect {}
        }
        viewModel.nowEpochMillis = { 10_000L }
        viewModel.startExam("exam-1")
        advanceUntilIdle()

        val gate = CompletableDeferred<Unit>()
        val firstSaveStarted = CompletableDeferred<Unit>()
        repository.saveGate = gate
        repository.saveStarted = firstSaveStarted

        viewModel.pauseExam()
        runCurrent()
        assertTrue(firstSaveStarted.isCompleted)

        viewModel.resumeExam()
        runCurrent()
        assertEquals(1, repository.maxConcurrentSessionSaves)

        gate.complete(Unit)
        advanceUntilIdle()

        assertEquals(1, repository.maxConcurrentSessionSaves)
        assertEquals(false, repository.examSession.value?.isPaused)
        assertTrue(viewModel.uiState.value.takingState.isTaking)
        assertEquals(viewModel.uiState.value.takingState.deadlineEpochMillis, repository.examSession.value?.deadlineEpochMillis)
        stateJob.cancel()
    }

    @Test
    fun startExam_newSessionPersistsDeadline() = runTest(mainDispatcher) {
        val repository = FakeExamRepository(initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون", questionCount = 5, durationSeconds = 120)))
        val viewModel = ExamViewModel(repository)
        viewModel.nowEpochMillis = { 1_000_000L }
        viewModel.startExam("exam-1")
        advanceUntilIdle()
        assertEquals(1_120_000L, repository.examSession.value?.deadlineEpochMillis)
        assertEquals(false, repository.examSession.value?.isPaused)
    }

    @Test
    fun pauseAndResumePersistDeadlineDerivedRemainingTime() = runTest(mainDispatcher) {
        val repository = FakeExamRepository(initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون", questionCount = 5, durationSeconds = 120)))
        val viewModel = ExamViewModel(repository)
        var now = 1_000_000L
        viewModel.nowEpochMillis = { now }
        viewModel.startExam("exam-1")
        advanceUntilIdle()
        now += 25_000L
        viewModel.pauseExam()
        advanceUntilIdle()
        assertEquals(95, repository.examSession.value?.remainingSeconds)
        assertEquals(null, repository.examSession.value?.deadlineEpochMillis)
        assertEquals(true, repository.examSession.value?.isPaused)
        now += 10_000L
        viewModel.resumeExam()
        advanceUntilIdle()
        assertEquals(now + 95_000L, repository.examSession.value?.deadlineEpochMillis)
        assertEquals(false, repository.examSession.value?.isPaused)
    }

    @Test
    fun refreshTimer_marksExpiredSessionOnce() = runTest(mainDispatcher) {
        val repository = FakeExamRepository(initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون", questionCount = 5, durationSeconds = 10)))
        val viewModel = ExamViewModel(repository)
        val stateJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            viewModel.uiState.collect {}
        }
        var now = 5_000L
        viewModel.nowEpochMillis = { now }
        viewModel.startExam("exam-1")
        advanceUntilIdle()
        now += 10_000L
        viewModel.refreshTimer()
        advanceUntilIdle()
        assertEquals(false, viewModel.uiState.value.takingState.isTaking)
        assertEquals(true, viewModel.uiState.value.takingState.isFinishing)
        assertEquals(15_000L, repository.examSession.value?.deadlineEpochMillis)
        assertEquals(false, repository.examSession.value?.isPaused)
        val expiredSnapshot = repository.examSession.value
        now += 5_000L
        viewModel.refreshTimer()
        advanceUntilIdle()
        assertEquals(expiredSnapshot, repository.examSession.value)
        stateJob.cancel()
    }

    @Test
    fun refreshTimer_persistsExpiredDeadlineForProcessRestoration() = runTest(mainDispatcher) {
        val repository = FakeExamRepository(
            initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون", questionCount = 5, durationSeconds = 10)),
        )
        val viewModel = ExamViewModel(repository)
        var now = 5_000L
        viewModel.nowEpochMillis = { now }
        viewModel.startExam("exam-1")
        advanceUntilIdle()
        now += 10_000L
        viewModel.refreshTimer()
        advanceUntilIdle()
        val snapshot = repository.examSession.value
        assertEquals(15_000L, snapshot?.deadlineEpochMillis)
        assertEquals(0, snapshot?.remainingSeconds)
        assertEquals(false, snapshot?.isPaused)
    }

    @Test
    fun selectQuestion_coalescesRapidNavigationWithoutRepeatedRoomReads() = runTest(mainDispatcher) {
        val repository = FakeExamRepository(
            initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون", questionCount = 8)),
        )
        val viewModel = ExamViewModel(repository)
        viewModel.nowEpochMillis = { 10_000L }
        viewModel.startExam("exam-1")
        advanceUntilIdle()

        val readsBeforeNavigation = repository.examSheetObservationCount
        val writesBeforeNavigation = repository.sessionSaveCalls
        viewModel.selectQuestion(3)
        viewModel.selectQuestion(5)
        viewModel.selectQuestion(6)

        assertEquals(readsBeforeNavigation, repository.examSheetObservationCount)
        advanceTimeBy(299)
        runCurrent()
        assertEquals(writesBeforeNavigation, repository.sessionSaveCalls)

        advanceTimeBy(1)
        runCurrent()
        assertEquals(6, repository.examSession.value?.currentQuestionNumber)
        assertEquals(writesBeforeNavigation + 1, repository.sessionSaveCalls)
    }

    @Test
    fun saveExamSession_rejectsInactiveExamAndOutOfRangeQuestion() = runTest(mainDispatcher) {
        val repository = FakeExamRepository(
            initialSheets = listOf(ExamSheet(id = "exam-1", name = "آزمون", questionCount = 5)),
        )
        repository.setActiveExam("exam-1")
        val inactive = ExamSessionSnapshot("other", 1, null, 0, true)
        val invalidQuestion = ExamSessionSnapshot("exam-1", 6, null, 0, true)

        assertEquals(false, repository.saveExamSession(inactive))
        assertEquals(false, repository.saveExamSession(invalidQuestion))
    }


    @Test
    fun saveSheet_enforcesQuestionCountBoundaryAndAcceptsMaximum() = runTest(mainDispatcher) {
        val repository = FakeExamRepository()
        val viewModel = ExamViewModel(repository)
        var invalidResult: ExamActionResult? = null
        viewModel.saveSheet(
            ExamSheet(id = "too-many", name = "تعداد نامعتبر", questionCount = 201),
        ) { invalidResult = it }
        advanceUntilIdle()

        assertTrue(invalidResult is ExamActionResult.Invalid)
        assertTrue(repository.savedSheets.isEmpty())

        var validResult: ExamActionResult? = null
        val maximumSheet = ExamSheet(
            id = "maximum-count",
            name = "حداکثر سؤال",
            questionCount = 200,
            durationSeconds = 24 * 60 * 60,
            negativeMarking = true,
            answers = mapOf(200 to 3),
            answerKey = mapOf(200 to 3),
            marked = setOf(200),
        )
        viewModel.saveSheet(maximumSheet) { validResult = it }
        advanceUntilIdle()

        assertEquals(ExamActionResult.Success, validResult)
        assertEquals(listOf(maximumSheet), repository.savedSheets)
    }

    private class FakeExamRepository(
        initialSheets: List<ExamSheet> = emptyList(),
        private val completion: ExamResult? = null,
    ) : ExamRepository {
        val sheets = MutableStateFlow(initialSheets)
        private val results = MutableStateFlow<List<ExamResult>>(emptyList())
        val savedSheets = mutableListOf<ExamSheet>()
        var examSheetObservationCount: Int = 0
        var sessionSaveCalls: Int = 0
        var completedSheetId: String? = null
        var completionCalls: Int = 0
        var completionFailure: Throwable? = null
        var saveGate: CompletableDeferred<Unit>? = null
        var saveStarted: CompletableDeferred<Unit>? = null
        var activeSessionSaves: Int = 0
        var maxConcurrentSessionSaves: Int = 0

        override fun observeExamSheets(): Flow<List<ExamSheet>> {
            examSheetObservationCount++
            return sheets.asStateFlow()
        }
        override fun observeExamResults(): Flow<List<ExamResult>> = results.asStateFlow()
        val activeExam = MutableStateFlow<String?>(null)
        val examSession = MutableStateFlow<ExamSessionSnapshot?>(null)
        override fun observeActiveExamId(): Flow<String?> = activeExam.asStateFlow()
        override fun observeExamSession(): Flow<ExamSessionSnapshot?> = examSession.asStateFlow()
        override suspend fun setActiveExam(id: String): Boolean {
            if (sheets.value.none { it.id == id }) return false
            if (activeExam.value != id) {
                activeExam.value = id
                examSession.value = ExamSessionSnapshot(
                    examId = id,
                    currentQuestionNumber = 1,
                    deadlineEpochMillis = null,
                    remainingSeconds = 0,
                    isPaused = true,
                )
            }
            return true
        }
        override suspend fun saveExamSession(session: ExamSessionSnapshot): Boolean {
            sessionSaveCalls++
            activeSessionSaves++
            maxConcurrentSessionSaves = maxOf(maxConcurrentSessionSaves, activeSessionSaves)
            saveStarted?.complete(Unit)
            return try {
                saveGate?.await()
                val sheet = sheets.value.firstOrNull { it.id == session.examId } ?: return false
                if (activeExam.value != session.examId) return false
                if (session.currentQuestionNumber !in 1..sheet.questionCount) return false
                examSession.value = session
                true
            } finally {
                activeSessionSaves--
            }
        }
        override suspend fun clearActiveExam(id: String?) {
            if (id == null || activeExam.value == id) {
                activeExam.value = null
                examSession.value = null
            }
        }

        override suspend fun upsertExamSheet(sheet: ExamSheet) {
            savedSheets += sheet
            sheets.value = sheets.value.filterNot { it.id == sheet.id } + sheet
        }

        override suspend fun completeExam(
            sheetId: String,
            resultId: String,
            completedAt: String,
        ): ExamResult? {
            completionCalls++
            completedSheetId = sheetId
            completionFailure?.let { throw it }
            if (completion != null && activeExam.value == sheetId) {
                activeExam.value = null
                examSession.value = null
            }
            return completion
        }

        override suspend fun deleteExamSheet(id: String): Boolean {
            if (sheets.value.size <= 1 || sheets.value.none { it.id == id }) return false
            sheets.value = sheets.value.filterNot { it.id == id }
            return true
        }
    }
}
