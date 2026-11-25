package com.mzarmehi1390.darsyar.features.planner.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerCalendar
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerDayCopyService
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerDayCopyResult
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerOperations
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerRepository
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerWeekCopyService
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerWeekCopyResult
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
import java.time.LocalDate
import java.util.UUID
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
    private val weekCopyService = PlannerWeekCopyService()
    private val dayCopyService = PlannerDayCopyService()

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
            val result = try {
                sessionMutationMutex.withLock {
                    // Read the latest persisted collection inside the mutation lock.
                    // This prevents concurrent saves from both passing overlap validation.
                    val currentSessions = repository.observeStudySessions().first()
                    val overlapping = PlannerOperations.hasOverlap(
                        sessions = currentSessions,
                        candidate = session,
                        excludingId = session.id,
                    )
                    if (overlapping) {
                        PlannerActionResult.Invalid("این بازهٔ زمانی با برنامهٔ دیگری تداخل دارد")
                    } else {
                        repository.upsertStudySession(session)
                        actionError.update { null }
                        PlannerActionResult.Success
                    }
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Exception) {
                actionError.update { failure.message ?: "ذخیرهٔ جلسهٔ مطالعه ناموفق بود" }
                PlannerActionResult.Failure(failure)
            }
            // Keep client callbacks outside the persistence try/catch. A callback failure
            // must never be mistaken for a database failure or trigger a second callback.
            onResult(result)
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

    fun copyWeekToNext(sourceWeekStart: LocalDate, onResult: (PlannerActionResult) -> Unit = {}) {
        viewModelScope.launch {
            val result = try {
                sessionMutationMutex.withLock {
                    val plan = weekCopyService.createNextWeekPlan(
                        sessions = repository.observeStudySessions().first(),
                        tasks = repository.observeTasks().first(),
                        sourceWeekStart = sourceWeekStart,
                        createSessionId = { UUID.randomUUID().toString() },
                        createTaskId = { UUID.randomUUID().toString() },
                    )
                    when (repository.copyWeekPlan(plan)) {
                        is PlannerWeekCopyResult.Copied -> {
                            actionError.update { null }
                            PlannerActionResult.Success
                        }
                        PlannerWeekCopyResult.TargetWeekNotEmpty ->
                            PlannerActionResult.Invalid("هفتهٔ مقصد از قبل برنامه دارد؛ هیچ موردی جایگزین نشد")
                        PlannerWeekCopyResult.SessionConflict ->
                            PlannerActionResult.Invalid("جلسه‌های کپی‌شده با برنامه‌های هفتگی موجود تداخل دارند")
                        PlannerWeekCopyResult.IdCollision ->
                            PlannerActionResult.Invalid("اطلاعات برنامهٔ کپی‌شده معتبر نیست")
                    }
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Exception) {
                actionError.update { failure.message ?: "کپی برنامهٔ هفتگی ناموفق بود" }
                PlannerActionResult.Failure(failure)
            }
            onResult(result)
        }
    }

    fun copySelectedDayTo(
        sourceDate: LocalDate,
        targetDate: LocalDate,
        onResult: (PlannerActionResult) -> Unit = {},
    ) {
        if (sourceDate == targetDate) {
            onResult(PlannerActionResult.Invalid("روز مبدأ و مقصد نمی‌توانند یکسان باشند"))
            return
        }
        viewModelScope.launch {
            val result = try {
                sessionMutationMutex.withLock {
                    val plan = dayCopyService.createPlan(
                        sessions = repository.observeStudySessions().first(),
                        sourceDate = sourceDate,
                        targetDate = targetDate,
                        createId = { UUID.randomUUID().toString() },
                    )
                    when (repository.copyDayPlan(plan)) {
                        is PlannerDayCopyResult.Copied -> {
                            actionError.update { null }
                            PlannerActionResult.Success
                        }
                        PlannerDayCopyResult.TargetDateNotEmpty ->
                            PlannerActionResult.Invalid("روز مقصد از قبل جلسه دارد؛ هیچ موردی جایگزین نشد")
                        PlannerDayCopyResult.SessionConflict ->
                            PlannerActionResult.Invalid("جلسه‌های این روز با برنامهٔ هفتگی موجود تداخل دارند")
                        PlannerDayCopyResult.IdCollision ->
                            PlannerActionResult.Invalid("شناسه یا تاریخ جلسهٔ کپی‌شده معتبر نیست")
                        PlannerDayCopyResult.SourceChanged ->
                            PlannerActionResult.Invalid("برنامهٔ روز مبدأ تغییر کرده است؛ دوباره تلاش کن")
                        PlannerDayCopyResult.InvalidPlan ->
                            PlannerActionResult.Invalid("ساختار برنامهٔ کپی‌شده معتبر نیست؛ دوباره تلاش کن")
                    }
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Exception) {
                actionError.update { failure.message ?: "کپی برنامهٔ روزانه ناموفق بود" }
                PlannerActionResult.Failure(failure)
            }
            onResult(result)
        }
    }

    fun clearError() {
        actionError.update { null }
    }

    private fun performAction(
        onResult: (PlannerActionResult) -> Unit,
        action: suspend () -> Unit,
    ) {
        viewModelScope.launch {
            val result = try {
                action()
                actionError.update { null }
                PlannerActionResult.Success
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Exception) {
                actionError.update { failure.message ?: "انجام عملیات با خطا روبه‌رو شد" }
                PlannerActionResult.Failure(failure)
            }
            // Do not catch exceptions thrown by UI/client callbacks as repository failures.
            onResult(result)
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
        SessionValidation.WeekdayDoesNotMatchDate -> "روز هفته با تاریخ جلسه هم‌خوانی ندارد"
    }
}
