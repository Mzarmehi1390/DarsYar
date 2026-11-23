package com.mzarmehi1390.darsyar.features.planner.presentation

import com.mzarmehi1390.darsyar.features.planner.domain.PlannerRepository
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
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
                startMinutes = 9 * 30 + 15,
                durationMinutes = 45,
            ),
        ) { result = it }
        advanceUntilIdle()

        assertTrue(result is PlannerActionResult.Invalid)
        assertTrue(repository.savedSessions.isEmpty())
        stateJob.cancel()
    }

    private class FakePlannerRepository(
        initialSessions: List<StudySession> = emptyList(),
    ) : PlannerRepository {
        val tasks = MutableStateFlow<List<StudyTask>>(emptyList())
        private val sessionFlow = MutableStateFlow(initialSessions)
        val savedTasks = mutableListOf<StudyTask>()
        val savedSessions = mutableListOf<StudySession>()

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
    }
}
