package com.mzarmehi1390.darsyar.features.exams.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mzarmehi1390.darsyar.features.exams.domain.ExamRepository
import com.mzarmehi1390.darsyar.features.exams.domain.ExamSessionSnapshot
import com.mzarmehi1390.darsyar.features.exams.domain.ExamTakingOperations
import com.mzarmehi1390.darsyar.features.exams.domain.ExamTakingState
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import dagger.hilt.android.lifecycle.HiltViewModel
import java.time.Instant
import java.util.UUID
import javax.inject.Inject
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

data class ExamUiState(
    val sheets: List<ExamSheet> = emptyList(),
    val results: List<ExamResult> = emptyList(),
    val activeExamId: String? = null,
    val takingState: ExamTakingState = ExamTakingState(),
    val isLoading: Boolean = true,
    val errorMessage: String? = null,
)

sealed interface ExamActionResult {
    data object Success : ExamActionResult
    data class Completed(val result: ExamResult) : ExamActionResult
    data object SheetNotFound : ExamActionResult
    data object CannotDeleteLastSheet : ExamActionResult
    data class Invalid(val reason: String) : ExamActionResult
    data class Failure(val cause: Throwable) : ExamActionResult
}

@HiltViewModel
class ExamViewModel @Inject constructor(
    private val repository: ExamRepository,
) : ViewModel() {
    private val actionError = MutableStateFlow<String?>(null)
    private val takingState = MutableStateFlow(ExamTakingState())
    internal var nowEpochMillis: () -> Long = System::currentTimeMillis
    private var restoredExamId: String? = null
    private var activeQuestionCount: Int = 0
    private var pendingSessionPersistence: Job? = null
    private val sessionPersistenceMutex = Mutex()
    private val completionInFlight = mutableSetOf<String>()

    val uiState: StateFlow<ExamUiState> = combine(
        repository.observeExamSheets(),
        repository.observeExamResults(),
        repository.observeActiveExamId(),
        takingState,
        actionError,
    ) { sheets, results, activeExamId, taking, error ->
        ExamUiState(
            sheets = sheets,
            results = results,
            activeExamId = activeExamId,
            takingState = taking,
            isLoading = false,
            errorMessage = error,
        )
    }.onStart { emit(ExamUiState()) }
        .catch { throwable ->
            if (throwable is CancellationException) throw throwable
            emit(ExamUiState(isLoading = false, errorMessage = throwable.message ?: "خطا در دریافت اطلاعات آزمون‌ها"))
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ExamUiState())

    init {
        viewModelScope.launch {
            val activeId = repository.observeActiveExamId().first()
            if (activeId != null) restoreExamSession(activeId)
        }
    }

    fun saveSheet(sheet: ExamSheet, onResult: (ExamActionResult) -> Unit = {}) {
        val invalid = when {
            sheet.id.isBlank() -> "شناسهٔ آزمون معتبر نیست"
            sheet.name.isBlank() -> "نام آزمون نمی‌تواند خالی باشد"
            sheet.questionCount !in 1..MAX_QUESTION_COUNT -> "تعداد سؤال‌ها باید بین ۱ تا ۲۰۰ باشد"
            sheet.durationSeconds !in 1..MAX_DURATION_SECONDS -> "مدت آزمون معتبر نیست"
            sheet.answers.keys.any { it !in 1..sheet.questionCount } -> "شمارهٔ یکی از پاسخ‌ها معتبر نیست"
            sheet.answers.values.any { it !in 0..3 } -> "گزینهٔ یکی از پاسخ‌ها معتبر نیست"
            sheet.answerKey.keys.any { it !in 1..sheet.questionCount } -> "شمارهٔ یکی از پاسخ‌های کلیدی معتبر نیست"
            sheet.answerKey.values.any { it !in 0..3 } -> "گزینهٔ یکی از پاسخ‌های کلیدی معتبر نیست"
            sheet.marked.any { it !in 1..sheet.questionCount } -> "شمارهٔ سؤال علامت‌گذاری‌شده معتبر نیست"
            else -> null
        }
        if (invalid != null) {
            onResult(ExamActionResult.Invalid(invalid))
            return
        }
        performAction(onResult) { repository.upsertExamSheet(sheet) }
    }

    fun startExam(sheetId: String, onResult: (ExamActionResult) -> Unit = {}) {
        if (sheetId.isBlank()) {
            onResult(ExamActionResult.Invalid("شناسهٔ آزمون معتبر نیست"))
            return
        }
        viewModelScope.launch {
            try {
                // Flush only when leaving this sheet; reopening it must not overwrite its persisted snapshot.
                if (takingState.value.examId != null && takingState.value.examId != sheetId) {
                    persistTakingStateImmediately()
                }
                val started = repository.setActiveExam(sheetId)
                if (!started) {
                    onResult(ExamActionResult.SheetNotFound)
                    return@launch
                }
                val sheet = repository.observeExamSheets().first().firstOrNull { it.id == sheetId }
                    ?: run { onResult(ExamActionResult.SheetNotFound); return@launch }
                restoreExamSession(sheetId, sheet)
                actionError.update { null }
                onResult(ExamActionResult.Success)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Throwable) {
                actionError.update { failure.message ?: "شروع آزمون با خطا روبه‌رو شد" }
                onResult(ExamActionResult.Failure(failure))
            }
        }
    }

    private suspend fun restoreExamSession(examId: String, knownSheet: ExamSheet? = null) {
        val sheet = knownSheet ?: repository.observeExamSheets().first().firstOrNull { it.id == examId }
            ?: return
        if (restoredExamId == examId && takingState.value.examId == examId) {
            activeQuestionCount = sheet.questionCount
            return
        }
        val saved = repository.observeExamSession().first()?.takeIf { it.examId == examId }
        val now = nowEpochMillis()
        val restored = when {
            saved == null || (saved.isPaused && saved.remainingSeconds == 0 && saved.deadlineEpochMillis == null) ->
                ExamTakingOperations.begin(ExamTakingState(), examId, sheet.durationSeconds, sheet.questionCount, now)
            saved.isPaused -> ExamTakingState(
                examId = examId,
                currentQuestionNumber = saved.currentQuestionNumber.coerceIn(1, sheet.questionCount),
                remainingSeconds = saved.remainingSeconds,
            )
            else -> ExamTakingState(
                examId = examId,
                currentQuestionNumber = saved.currentQuestionNumber.coerceIn(1, sheet.questionCount),
                isTaking = true,
                remainingSeconds = saved.remainingSeconds,
                deadlineEpochMillis = saved.deadlineEpochMillis,
            )
        }
        takingState.value = restored
        restoredExamId = examId
        activeQuestionCount = sheet.questionCount
        persistTakingState()
    }

    fun selectQuestion(number: Int) {
        // The active sheet is loaded once when the session starts/restores. Avoid
        // querying Room for every tap in the question navigator.
        if (activeQuestionCount < 1 || takingState.value.examId == null) return
        val updated = ExamTakingOperations.selectQuestion(
            takingState.value,
            number,
            activeQuestionCount,
        )
        if (updated == takingState.value) return
        takingState.value = updated
        scheduleSessionPersistence()
    }

    fun pauseExam() {
        takingState.update { ExamTakingOperations.pause(it, nowEpochMillis()) }
        viewModelScope.launch { persistTakingStateImmediately() }
    }

    fun resumeExam() {
        takingState.update { ExamTakingOperations.resume(it, nowEpochMillis()) }
        viewModelScope.launch { persistTakingStateImmediately() }
    }

    /**
     * Refreshes the deadline-derived timer while the exam UI is visible.
     * The persisted deadline remains authoritative while the UI is backgrounded.
     * Avoiding a perpetual ViewModel coroutine keeps coroutine-test schedulers idle.
     */
    fun refreshTimer() {
        val current = takingState.value
        if (!current.isTaking || current.isFinishing) return
        val tick = ExamTakingOperations.tick(current, nowEpochMillis())
        if (tick.state != current) takingState.value = tick.state
        if (tick.expired) {
            viewModelScope.launch {
                persistTakingStateImmediately()
                completeExam(current.examId.orEmpty())
            }
        }
    }

    private fun scheduleSessionPersistence() {
        pendingSessionPersistence?.cancel()
        pendingSessionPersistence = viewModelScope.launch {
            delay(SESSION_PERSISTENCE_DEBOUNCE_MILLIS)
            persistTakingState()
        }
    }

    private suspend fun persistTakingStateImmediately(): Boolean {
        pendingSessionPersistence?.cancel()
        pendingSessionPersistence = null
        return persistTakingState()
    }

    private suspend fun persistTakingState(): Boolean = sessionPersistenceMutex.withLock {
        // Read the state only after acquiring the lock. If pause/resume/navigation
        // requests overlap, each write persists the newest state available when
        // its turn begins instead of allowing an older snapshot to finish last.
        val current = takingState.value
        val examId = current.examId ?: return@withLock false
        repository.saveExamSession(
            ExamSessionSnapshot(
                examId = examId,
                currentQuestionNumber = current.currentQuestionNumber,
                deadlineEpochMillis = current.deadlineEpochMillis,
                remainingSeconds = current.remainingSeconds,
                isPaused = !current.isTaking && !current.isFinishing,
            ),
        )
    }

    fun clearActiveExam(sheetId: String? = null) {
        viewModelScope.launch {
            try {
                if (sheetId == null || takingState.value.examId == sheetId) {
                    pendingSessionPersistence?.cancel()
                    pendingSessionPersistence = null
                }
                repository.clearActiveExam(sheetId)
                if (sheetId == null || takingState.value.examId == sheetId) {
                    takingState.value = ExamTakingState()
                    restoredExamId = null
                    activeQuestionCount = 0
                }
                actionError.update { null }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Throwable) {
                actionError.update { failure.message ?: "پاک‌کردن وضعیت آزمون فعال ناموفق بود" }
            }
        }
    }

    fun completeExam(
        sheetId: String,
        completedAt: String = Instant.now().toString(),
        resultId: String = UUID.randomUUID().toString(),
        onResult: (ExamActionResult) -> Unit = {},
    ) {
        if (sheetId.isBlank() || completedAt.isBlank() || resultId.isBlank()) {
            onResult(ExamActionResult.Invalid("اطلاعات ثبت نتیجهٔ آزمون معتبر نیست"))
            return
        }
        if (!completionInFlight.add(sheetId)) return
        viewModelScope.launch {
            try {
                if (takingState.value.examId == sheetId) persistTakingStateImmediately()
                if (takingState.value.examId == sheetId && takingState.value.isFinishing) {
                    takingState.update { ExamTakingOperations.beginSavingResult(it) ?: it }
                }
                val result = repository.completeExam(sheetId, resultId, completedAt)
                if (result != null && takingState.value.examId == sheetId) {
                    takingState.value = ExamTakingState()
                    restoredExamId = null
                    activeQuestionCount = 0
                    actionError.update { null }
                } else if (result == null) {
                    takingState.update { if (it.examId == sheetId) it.copy(isSavingResult = false) else it }
                    actionError.update { "نتیجهٔ آزمون ثبت نشد؛ می‌توانی دوباره تلاش کنی" }
                }
                onResult(result?.let(ExamActionResult::Completed) ?: ExamActionResult.SheetNotFound)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Throwable) {
                takingState.update { if (it.examId == sheetId) it.copy(isSavingResult = false) else it }
                actionError.update { failure.message ?: "ثبت نتیجهٔ آزمون با خطا روبه‌رو شد" }
                onResult(ExamActionResult.Failure(failure))
            } finally {
                completionInFlight.remove(sheetId)
            }
        }
    }

    fun deleteSheet(id: String, onResult: (ExamActionResult) -> Unit = {}) {
        if (id.isBlank()) {
            onResult(ExamActionResult.Invalid("شناسهٔ آزمون معتبر نیست"))
            return
        }
        val knownSheets = uiState.value.sheets
        val sheetExists = knownSheets.any { it.id == id }
        val isLastKnownSheet = sheetExists && knownSheets.size == 1
        viewModelScope.launch {
            try {
                val deleted = repository.deleteExamSheet(id)
                if (deleted && takingState.value.examId == id) {
                    pendingSessionPersistence?.cancel()
                    pendingSessionPersistence = null
                    takingState.value = ExamTakingState()
                    restoredExamId = null
                    activeQuestionCount = 0
                }
                actionError.update { null }
                val result = when {
                    deleted -> ExamActionResult.Success
                    isLastKnownSheet -> ExamActionResult.CannotDeleteLastSheet
                    else -> ExamActionResult.SheetNotFound
                }
                onResult(result)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Throwable) {
                actionError.update { failure.message ?: "حذف آزمون با خطا روبه‌رو شد" }
                onResult(ExamActionResult.Failure(failure))
            }
        }
    }

    fun clearError() {
        actionError.update { null }
    }

    private fun performAction(
        onResult: (ExamActionResult) -> Unit,
        action: suspend () -> Unit,
    ) {
        viewModelScope.launch {
            try {
                action()
                actionError.update { null }
                onResult(ExamActionResult.Success)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Throwable) {
                actionError.update { failure.message ?: "انجام عملیات آزمون با خطا روبه‌رو شد" }
                onResult(ExamActionResult.Failure(failure))
            }
        }
    }

    private companion object {
        const val MAX_DURATION_SECONDS = 24 * 60 * 60
        // Keep the domain-level guard aligned with the answer-sheet UI and persistence limits.
        const val MAX_QUESTION_COUNT = 200
        const val SESSION_PERSISTENCE_DEBOUNCE_MILLIS = 300L
    }
}
