package com.mzarmehi1390.darsyar.features.planner.presentation

import com.mzarmehi1390.darsyar.features.planner.domain.PlannerRepository
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerDayCopyPlan
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerDayCopyResult
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerWeekCopyPlan
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerWeekCopyResult
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
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
class PlannerViewModelTest {
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
    fun copySelectedDayTo_createsFreshIncompleteDatedSessions() = runTest(mainDispatcher) {
        val source = StudySession(
            id = "source-session",
            title = "مطالعه ریاضی",
            subject = "ریاضی",
            weekday = 1,
            startMinutes = 9 * 60,
            durationMinutes = 45,
            completed = true,
            scheduledDate = "2026-11-23",
        )
        val repository = FakePlannerRepository(initialSessions = listOf(source))
        val viewModel = PlannerViewModel(repository)
        var result: PlannerActionResult? = null

        viewModel.copySelectedDayTo(
            sourceDate = java.time.LocalDate.parse("2026-11-23"),
            targetDate = java.time.LocalDate.parse("2026-11-24"),
        ) { result = it }
        advanceUntilIdle()

        assertEquals(PlannerActionResult.Success, result)
        assertEquals(2, repository.sessionsSnapshot().size)
        val copy = repository.sessionsSnapshot().single { it.id != source.id }
        assertEquals("2026-11-24", copy.scheduledDate)
        assertEquals(2, copy.weekday)
        assertEquals(9 * 60, copy.startMinutes)
        assertTrue(!copy.completed)
        assertEquals(source, repository.sessionsSnapshot().first { it.id == source.id })
    }

    @Test
    fun saveTask_persistsValidTaskAndReportsSuccess() = runTest(mainDispatcher) {
        val repository = FakePlannerRepository()
        val viewModel = PlannerViewModel(repository)
        val stateJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            viewModel.uiState.collect {}
        }
        val task = StudyTask(
            id = "task-1",
            title = "مرور جبر",
            subject = "ریاضی",
            dueDate = "2026-11-24",
        )
        var result: PlannerActionResult? = null

        viewModel.saveTask(task) { result = it }
        advanceUntilIdle()

        assertEquals(task, repository.tasks.value.single())
        assertEquals(PlannerActionResult.Success, result)
        assertTrue(viewModel.uiState.value.errorMessage == null)
        stateJob.cancel()
    }

    @Test
    fun saveTask_rejectsBlankTitleWithoutCallingRepository() = runTest(mainDispatcher) {
        val repository = FakePlannerRepository()
        val viewModel = PlannerViewModel(repository)
        var result: PlannerActionResult? = null

        viewModel.saveTask(StudyTask(id = "task-1", title = "  ", subject = "ریاضی")) {
            result = it
        }
        advanceUntilIdle()

        assertTrue(result is PlannerActionResult.Invalid)
        assertTrue(repository.savedTasks.isEmpty())
    }

    @Test
    fun saveTask_normalizesBlankSubjectAndTrimsTextBeforePersistence() = runTest(mainDispatcher) {
        val repository = FakePlannerRepository()
        val viewModel = PlannerViewModel(repository)
        var result: PlannerActionResult? = null

        viewModel.saveTask(
            StudyTask(
                id = "task-normalize",
                title = "  مرور فصل  ",
                subject = "   ",
            ),
        ) { result = it }
        advanceUntilIdle()

        assertEquals(PlannerActionResult.Success, result)
        assertEquals("مرور فصل", repository.tasks.value.single().title)
        assertEquals("عمومی", repository.tasks.value.single().subject)
    }

    @Test
    fun concurrentOverlappingSessionSaves_areSerializedAndOnlyOnePersists() = runTest(mainDispatcher) {
        val repository = FakePlannerRepository()
        val viewModel = PlannerViewModel(repository)
        val first = StudySession(
            id = "session-a",
            title = "مطالعه اول",
            subject = "ریاضی",
            weekday = 1,
            startMinutes = 9 * 60,
            durationMinutes = 60,
        )
        val second = first.copy(
            id = "session-b",
            title = "مطالعه دوم",
            startMinutes = 9 * 60 + 30,
        )
        val results = mutableListOf<PlannerActionResult>()

        viewModel.saveSession(first) { results += it }
        viewModel.saveSession(second) { results += it }
        advanceUntilIdle()

        assertEquals(1, repository.savedSessions.size)
        assertEquals(1, results.count { it == PlannerActionResult.Success })
        assertEquals(1, results.count { it is PlannerActionResult.Invalid })
    }

    @Test
    fun saveSession_persistsDatedSessionWithItsConcreteWeekday() = runTest(mainDispatcher) {
        val repository = FakePlannerRepository()
        val viewModel = PlannerViewModel(repository)
        val session = StudySession(
            id = "dated-session",
            title = "مطالعه تاریخ‌دار",
            subject = "ریاضی",
            weekday = 2,
            startMinutes = 10 * 60,
            durationMinutes = 45,
            scheduledDate = "2026-11-24",
        )
        var result: PlannerActionResult? = null

        viewModel.saveSession(session) { result = it }
        advanceUntilIdle()

        assertEquals(PlannerActionResult.Success, result)
        assertEquals(session, repository.sessionsSnapshot().single())
    }

    @Test
    fun saveSession_rejectsWeekdayThatDoesNotMatchScheduledDate() = runTest(mainDispatcher) {
        val repository = FakePlannerRepository()
        val viewModel = PlannerViewModel(repository)
        val inconsistent = StudySession(
            id = "dated-weekday-mismatch",
            title = "جلسه با روز ناسازگار",
            subject = "ریاضی",
            weekday = 1,
            startMinutes = 10 * 60,
            durationMinutes = 45,
            scheduledDate = "2026-11-24",
        )
        var result: PlannerActionResult? = null

        viewModel.saveSession(inconsistent) { result = it }
        advanceUntilIdle()

        assertTrue(result is PlannerActionResult.Invalid)
        assertTrue(repository.savedSessions.isEmpty())
        assertTrue(repository.sessionsSnapshot().isEmpty())
    }

    @Test
    fun saveSession_trimsTitleAndUsesGeneralSubjectWhenSubjectIsBlank() = runTest(mainDispatcher) {
        val repository = FakePlannerRepository()
        val viewModel = PlannerViewModel(repository)
        val session = StudySession(
            id = "session-normalize",
            title = "  مرور فصل  ",
            subject = "   ",
            weekday = 2,
            startMinutes = 16 * 60,
            durationMinutes = 55,
            scheduledDate = "2026-11-24",
        )
        var result: PlannerActionResult? = null

        viewModel.saveSession(session) { result = it }
        advanceUntilIdle()

        assertEquals(PlannerActionResult.Success, result)
        val saved = repository.sessionsSnapshot().single()
        assertEquals("مرور فصل", saved.title)
        assertEquals("عمومی", saved.subject)
        assertEquals("session-normalize", saved.id)
        assertEquals("2026-11-24", saved.scheduledDate)
        assertEquals(16 * 60, saved.startMinutes)
        assertEquals(55, saved.durationMinutes)
    }

    @Test
    fun saveSession_persistsWeeklyLegacySessionWithoutDate() = runTest(mainDispatcher) {
        val repository = FakePlannerRepository()
        val viewModel = PlannerViewModel(repository)
        val session = StudySession(
            id = "weekly-session",
            title = "مطالعه هفتگی",
            subject = "علوم",
            weekday = 4,
            startMinutes = 16 * 60,
            durationMinutes = 30,
        )
        var result: PlannerActionResult? = null

        viewModel.saveSession(session) { result = it }
        advanceUntilIdle()

        assertEquals(PlannerActionResult.Success, result)
        assertEquals(session, repository.sessionsSnapshot().single())
        assertEquals(null, repository.sessionsSnapshot().single().scheduledDate)
    }

    @Test
    fun saveSession_rejectsOverlappingOccurrence() = runTest(mainDispatcher) {
        val existing = StudySession(
            id = "session-1",
            title = "مطالعه اول",
            subject = "ریاضی",
            weekday = 2,
            startMinutes = 9 * 60,
            durationMinutes = 60,
        )
        val repository = FakePlannerRepository(initialSessions = listOf(existing))
        val viewModel = PlannerViewModel(repository)
        val stateJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            viewModel.uiState.collect {}
        }
        advanceUntilIdle()
        var result: PlannerActionResult? = null

        viewModel.saveSession(
            existing.copy(
                id = "session-2",
                title = "مطالعه دوم",
                startMinutes = 9 * 60 + 15,
                durationMinutes = 45,
            ),
        ) { result = it }
        advanceUntilIdle()

        assertTrue(result is PlannerActionResult.Invalid)
        assertTrue(repository.savedSessions.isEmpty())
        stateJob.cancel()
    }

    @Test
    fun saveSession_rejectsOverlapBetweenDatedAndLegacyOccurrences() = runTest(mainDispatcher) {
        val datedTuesdayWithStaleWeekday = StudySession(
            id = "dated-session",
            title = "جلسه تاریخ‌دار",
            subject = "ریاضی",
            weekday = 1,
            startMinutes = 9 * 60,
            durationMinutes = 60,
            scheduledDate = "2026-11-24",
        )
        val repository = FakePlannerRepository(initialSessions = listOf(datedTuesdayWithStaleWeekday))
        val viewModel = PlannerViewModel(repository)
        val legacyTuesday = StudySession(
            id = "legacy-session",
            title = "جلسه قدیمی",
            subject = "علوم",
            weekday = 2,
            startMinutes = 9 * 60 + 30,
            durationMinutes = 45,
        )
        var result: PlannerActionResult? = null

        viewModel.saveSession(legacyTuesday) { result = it }
        advanceUntilIdle()

        assertTrue(result is PlannerActionResult.Invalid)
        assertTrue(repository.savedSessions.isEmpty())
    }

    @Test
    fun saveTask_updatesExistingTaskAndPreservesCompletionAndDueDate() = runTest(mainDispatcher) {
        val existing = StudyTask(
            id = "task-edit",
            title = "عنوان قبلی",
            subject = "ریاضی",
            done = true,
            dueDate = "2026-11-24",
        )
        val repository = FakePlannerRepository()
        repository.tasks.value = listOf(existing)
        val viewModel = PlannerViewModel(repository)
        var result: PlannerActionResult? = null

        viewModel.saveTask(
            existing.copy(title = "عنوان جدید", subject = "علوم", dueDate = "2026-11-26"),
        ) { result = it }
        advanceUntilIdle()

        assertEquals(PlannerActionResult.Success, result)
        assertEquals(1, repository.tasks.value.size)
        assertEquals("عنوان جدید", repository.tasks.value.single().title)
        assertEquals("علوم", repository.tasks.value.single().subject)
        assertTrue(repository.tasks.value.single().done)
        assertEquals("2026-11-26", repository.tasks.value.single().dueDate)
        assertEquals(1, repository.savedTasks.size)
    }

    @Test
    fun saveTask_rejectsMalformedDueDateWithoutCallingRepository() = runTest(mainDispatcher) {
        val repository = FakePlannerRepository()
        val viewModel = PlannerViewModel(repository)
        var result: PlannerActionResult? = null

        viewModel.saveTask(
            StudyTask("task-bad-date", "تمرین", "ریاضی", dueDate = "24-11-2026"),
        ) { result = it }
        advanceUntilIdle()

        assertTrue(result is PlannerActionResult.Invalid)
        assertTrue(repository.savedTasks.isEmpty())
        assertTrue(repository.tasks.value.isEmpty())
    }

    @Test
    fun saveSession_updatesExistingSessionWithoutChangingIdentityOrCompletion() = runTest(mainDispatcher) {
        val existing = StudySession(
            id = "session-edit",
            title = "عنوان قبلی",
            subject = "ریاضی",
            weekday = 2,
            startMinutes = 9 * 60,
            durationMinutes = 60,
            completed = true,
        )
        val repository = FakePlannerRepository(initialSessions = listOf(existing))
        val viewModel = PlannerViewModel(repository)
        var result: PlannerActionResult? = null

        viewModel.saveSession(
            existing.copy(title = "عنوان جدید", subject = "علوم", startMinutes = 11 * 60),
        ) { result = it }
        advanceUntilIdle()

        assertEquals(PlannerActionResult.Success, result)
        assertEquals(1, repository.savedSessions.size)
        assertEquals(1, repository.sessionsSnapshot().size)
        val saved = repository.sessionsSnapshot().single()
        assertEquals("session-edit", saved.id)
        assertEquals("عنوان جدید", saved.title)
        assertEquals("علوم", saved.subject)
        assertTrue(saved.completed)
    }

    @Test
    fun editingSessionIntoAnotherSessionsTimeRangeIsRejectedWithoutMutation() = runTest(mainDispatcher) {
        val original = StudySession(
            id = "session-edit-source",
            title = "جلسه قابل ویرایش",
            subject = "ریاضی",
            weekday = 2,
            startMinutes = 9 * 60,
            durationMinutes = 45,
        )
        val conflicting = StudySession(
            id = "session-conflict",
            title = "جلسه مقصد",
            subject = "علوم",
            weekday = 2,
            startMinutes = 11 * 60,
            durationMinutes = 60,
        )
        val repository = FakePlannerRepository(initialSessions = listOf(original, conflicting))
        val viewModel = PlannerViewModel(repository)
        var result: PlannerActionResult? = null

        viewModel.saveSession(original.copy(startMinutes = 11 * 60 + 15)) { result = it }
        advanceUntilIdle()

        assertTrue(result is PlannerActionResult.Invalid)
        assertTrue(repository.savedSessions.isEmpty())
        assertEquals(listOf(original, conflicting), repository.sessionsSnapshot())
    }

    @Test
    fun toggleSessionChangesOnlyCompletionAndPreservesSessionIdentityAndSchedule() = runTest(mainDispatcher) {
        val original = StudySession(
            id = "session-toggle",
            title = "مرور فیزیک",
            subject = "فیزیک",
            weekday = 2,
            startMinutes = 16 * 60,
            durationMinutes = 55,
            completed = false,
            scheduledDate = "2026-11-24",
        )
        val repository = FakePlannerRepository(initialSessions = listOf(original))
        val viewModel = PlannerViewModel(repository)
        var result: PlannerActionResult? = null

        viewModel.toggleSession(original) { result = it }
        advanceUntilIdle()

        assertEquals(PlannerActionResult.Success, result)
        assertEquals(1, repository.sessionsSnapshot().size)
        assertEquals(original.copy(completed = true), repository.sessionsSnapshot().single())
    }

    @Test
    fun deleteSessionRemovesOnlyTheRequestedSession() = runTest(mainDispatcher) {
        val first = StudySession(
            id = "session-delete",
            title = "حذف‌شدنی",
            subject = "ریاضی",
            weekday = 2,
            startMinutes = 9 * 60,
            durationMinutes = 45,
        )
        val retained = first.copy(id = "session-retained", title = "باقی‌مانده")
        val repository = FakePlannerRepository(initialSessions = listOf(first, retained))
        val viewModel = PlannerViewModel(repository)
        var result: PlannerActionResult? = null

        viewModel.deleteSession(first.id) { result = it }
        advanceUntilIdle()

        assertEquals(PlannerActionResult.Success, result)
        assertEquals(listOf(retained), repository.sessionsSnapshot())
    }

    private class FakePlannerRepository(
        initialSessions: List<StudySession> = emptyList(),
    ) : PlannerRepository {
        val tasks = MutableStateFlow<List<StudyTask>>(emptyList())
        private val sessionFlow = MutableStateFlow(initialSessions)
        val savedTasks = mutableListOf<StudyTask>()
        val savedSessions = mutableListOf<StudySession>()
        fun sessionsSnapshot(): List<StudySession> = sessionFlow.value

        override fun observeTasks(): Flow<List<StudyTask>> = tasks.asStateFlow()
        override fun observeStudySessions(): Flow<List<StudySession>> = sessionFlow.asStateFlow()

        override suspend fun upsertTask(task: StudyTask) {
            savedTasks += task
            tasks.value = tasks.value.filterNot { it.id == task.id } + task
        }

        override suspend fun deleteTask(id: String) {
            tasks.value = tasks.value.filterNot { it.id == id }
        }

        override suspend fun upsertStudySession(session: StudySession) {
            savedSessions += session
            sessionFlow.value = sessionFlow.value.filterNot { it.id == session.id } + session
        }

        override suspend fun deleteStudySession(id: String) {
            sessionFlow.value = sessionFlow.value.filterNot { it.id == id }
        }

        override suspend fun copyDayPlan(plan: PlannerDayCopyPlan): PlannerDayCopyResult {
            if (sessionFlow.value.any { it.scheduledDate == plan.targetDate.toString() }) {
                return PlannerDayCopyResult.TargetDateNotEmpty
            }
            sessionFlow.value = sessionFlow.value + plan.copiedSessions
            return PlannerDayCopyResult.Copied(plan.copiedSessions.size)
        }

        override suspend fun copyWeekPlan(plan: PlannerWeekCopyPlan): PlannerWeekCopyResult {
            tasks.value = tasks.value + plan.copiedTasks
            sessionFlow.value = sessionFlow.value + plan.copiedSessions
            return PlannerWeekCopyResult.Copied(plan.copiedSessions.size, plan.copiedTasks.size)
        }
    }
}
