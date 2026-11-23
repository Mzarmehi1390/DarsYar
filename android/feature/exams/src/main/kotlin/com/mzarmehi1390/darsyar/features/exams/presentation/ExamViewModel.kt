package com.mzarmehi1390.darsyar.features.exams.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mzarmehi1390.darsyar.features.exams.domain.ExamRepository
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import dagger.hilt.android.lifecycle.HiltViewModel
import java.time.Instant
import java.util.UUID
import javax.inject.Inject
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ExamUiState(
    val sheets: List<ExamSheet> = emptyList(),
    val results: List<ExamResult> = emptyList(),
    val activeExamId: String? = null,
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

    val uiState: StateFlow<ExamUiState> = combine(
        repository.observeExamSheets(),
        repository.observeExamResults(),
        repository.observeActiveExamId(),
        actionError,
    ) { sheets, results, activeExamId, error ->
        ExamUiState(
            sheets = sheets,
            results = results,
            activeExamId = activeExamId,
            isLoading = false,
            errorMessage = error,
        )
    }.onStart { emit(ExamUiState()) }
        .catch { throwable ->
            if (throwable is CancellationException) throw throwable
            emit(ExamUiState(isLoading = false, errorMessage = throwable.message ?: "خطا در دریافت اطلاعات آزمون‌ها"))
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ExamUiState())

    fun saveSheet(sheet: ExamSheet, onResult: (ExamActionResult) -> Unit = {}) {
        val invalid = when {
            sheet.id.isBlank() -> "شناسهٔ آزمون معتبر نیست"
            sheet.name.isBlank() -> "نام آزمون نمی‌تواند خالی باشد"
            sheet.questionCount < 1 -> "تعداد سؤال‌ها باید بیشتر از صفر باشد"
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
                val started = repository.setActiveExam(sheetId)
                actionError.update { null }
                onResult(if (started) ExamActionResult.Success else ExamActionResult.SheetNotFound)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Throwable) {
                actionError.update { failure.message ?: "شروع آزمون با خطا روبه‌رو شد" }
                onResult(ExamActionResult.Failure(failure))
            }
        }
    }

    fun clearActiveExam(sheetId: String? = null) {
        viewModelScope.launch {
            try {
                repository.clearActiveExam(sheetId)
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
        viewModelScope.launch {
            try {
                val result = repository.completeExam(sheetId, resultId, completedAt)
                actionError.update { null }
                onResult(result?.let(ExamActionResult::Completed) ?: ExamActionResult.SheetNotFound)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Throwable) {
                actionError.update { failure.message ?: "ثبت نتیجهٔ آزمون با خطا روبه‌رو شد" }
                onResult(ExamActionResult.Failure(failure))
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
    }
}
