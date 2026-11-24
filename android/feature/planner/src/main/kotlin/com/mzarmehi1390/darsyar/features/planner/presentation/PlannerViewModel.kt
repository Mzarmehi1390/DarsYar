package com.mzarmehi1390.darsyar.features.planner.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerCalendar
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerRepository
import com.mzarmehi1390.darsyar.features.planner.domain.StudySessionOperations
import com.mzarmehi1390.darsyar.features.planner.domain.SessionValidation
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

data class PlannerUiState(
    val tasks: List<StudyTask> = emptyList(),
    val sessions: List<StudySession> = emptyList(),
    val isLoading: Boolean = true,
    val errorMessage: String? = null,
)

sealed interface PlannerActionResult {
    data object Success : PlannerActionResult
    data class Invalid(val reason: String) : PlannerActionResult
    data class Failure(val cause: Throwable) : PlannerActionResult
}

@HiltViewModel
class PlannerViewModel @Inject constructor(
    private val repository: PlannerRepository,
) : ViewModel() {
    private val actionError = MutableStateFlow<String?>(null)
    private val sessionMutationMutex = Mutex()

    val uiState: StateFlow<PlannerUiState> = combine(
        repository.observeTasks(),
        repository.observeStudySessions(),
        actionError,
    ) { tasks, sessions, error ->
        PlannerUiState(
            tasks = tasks,
            sessions = sessions,
            isLoading = false,
            errorMessage = error,
        )
    }.onStart { emit(PlannerUiState()) }
        .catch { throwable ->
            if (throwable is CancellationException) throw throwable
            emit(PlannerUiState(isLoading = false, errorMessage = throwable.message ?: "خطا در دریافت اطلاعات برنامه‌ریز"))
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), PlannerUiState())

    fun saveTask(task: StudyTask, onResult: (PlannerActionResult) -> Unit = {}) {
        val normalizedTask = task.copy(
            title = task.title.trim(),
            subject = task.subject.trim().ifBlank { "عمومی" },
        )
        val invalid = when {
            normalizedTask.id.isBlank() -> "شناسهٔ کار معتبر نیست"
            normalizedTask.title.isBlank() -> "عنوان کار نمی‌تواند خالی باشد"
            normalizedTask.dueDate != null &&
                PlannerCalendar.parseDateKey(normalizedTask.dueDate) == null -> "تاریخ کار معتبر نیست"
            else -> null
        }
        if (invalid != null) {
            onResult(PlannerActionResult.Invalid(invalid))
            return
        }
        performAction(onResult) { repository.upsertTask(normalizedTask) }
    }

    fun deleteTask(id: String, onResult: (PlannerActionResult) -> Unit = {}) {
        if (id.isBlank()) {
            onResult(PlannerActionResult.Invalid("شناسهٔ کار معتبر نیست"))
            return
        }
        performAction(onResult) { repository.deleteTask(id) }
    }

    fun toggleTask(task: StudyTask, onResult: (PlannerActionResult) -> Unit = {}) =
        saveTask(task.copy(done = !task.done), onResult)

    fun saveSession(
        session: StudySession,
        onResult: (PlannerActionResult) -> Unit = {},
    ) {
        when (val validation = StudySessionOperations.validate(session)) {
            SessionValidation.Valid -> Unit
            else -> {
                onResult(PlannerActionResult.Invalid(validation.message()))
                return
            }
        }
        viewModelScope.launch {
            try {
                sessionMutationMutex.withLock {
                    // Read the latest persisted collection inside the mutation lock.
                    // This prevents two near-simultaneous saves from both passing overlap validation.
                    val currentSessions = repository.observeStudySessions().first()
                    val overlapping = currentSessions.any { existing ->
                        existing.id != session.id &&
                            PlannerCalendar.sameOccurrence(
                                firstDateKey = session.scheduledDate,
                                firstWeekday = session.weekday,
                                secondDateKey = existing.scheduledDate,
                                secondWeekday = existing.weekday,
                            ) &&
                            session.startMinutes < existing.startMinutes + existing.durationMinutes &&
                            existing.startMinutes < session.startMinutes + session.durationMinutes
                    }
                    if (overlapping) {
                        onResult(PlannerActionResult.Invalid("این بازهٔ زمانی با برنامهٔ دیگری تداخل دارد"))
                        return@withLock
                    }
                    repository.upsertStudySession(session)
                    actionError.update { null }
                    onResult(PlannerActionResult.Success)
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Throwable) {
                actionError.update { failure.message ?: "ذخیرهٔ جلسهٔ مطالعه ناموفق بود" }
                onResult(PlannerActionResult.Failure(failure))
            }
        }
    }

    fun deleteSession(id: String, onResult: (PlannerActionResult) -> Unit = {}) {
        if (id.isBlank()) {
            onResult(PlannerActionResult.Invalid("شناسهٔ جلسه معتبر نیست"))
            return
        }
        performAction(onResult) { repository.deleteStudySession(id) }
    }

    fun toggleSession(session: StudySession, onResult: (PlannerActionResult) -> Unit = {}) =
        saveSession(session.copy(completed = !session.completed), onResult)

    fun clearError() {
        actionError.update { null }
    }

    private fun performAction(
        onResult: (PlannerActionResult) -> Unit,
        action: suspend () -> Unit,
    ) {
        viewModelScope.launch {
            try {
                action()
                actionError.update { null }
                onResult(PlannerActionResult.Success)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Throwable) {
                actionError.update { failure.message ?: "انجام عملیات با خطا روبه‌رو شد" }
                onResult(PlannerActionResult.Failure(failure))
            }
        }
    }

    private fun SessionValidation.message(): String = when (this) {
        SessionValidation.Valid -> ""
        SessionValidation.InvalidId -> "شناسهٔ جلسه معتبر نیست"
        SessionValidation.EmptyTitle -> "عنوان جلسه نمی‌تواند خالی باشد"
        SessionValidation.EmptySubject -> "نام درس نمی‌تواند خالی باشد"
        SessionValidation.InvalidWeekday -> "روز هفته معتبر نیست"
        SessionValidation.InvalidStartTime -> "زمان شروع معتبر نیست"
        SessionValidation.InvalidDuration -> "مدت جلسه باید بیشتر از صفر باشد"
        SessionValidation.CrossesMidnight -> "جلسه نباید از نیمه‌شب عبور کند"
        SessionValidation.InvalidDate -> "تاریخ جلسه معتبر نیست"
    }
}
