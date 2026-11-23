package com.mzarmehi1390.darsyar.features.exams.domain

/**
 * Pure state transitions for an active exam. Wall-clock time is injected so
 * timer behavior is deterministic in tests and independent from Compose.
 */
data class ExamTakingState(
    val examId: String? = null,
    val currentQuestionNumber: Int = 1,
    val showQuestionNavigator: Boolean = false,
    val isTaking: Boolean = false,
    val isFinishing: Boolean = false,
    val isSavingResult: Boolean = false,
    val remainingSeconds: Int = 0,
    val deadlineEpochMillis: Long? = null,
)

data class ExamTimerTick(
    val state: ExamTakingState,
    val expired: Boolean,
)

object ExamTakingOperations {
    fun begin(
        state: ExamTakingState,
        examId: String,
        durationSeconds: Int,
        questionCount: Int,
        nowEpochMillis: Long,
    ): ExamTakingState {
        require(examId.isNotBlank()) { "Exam ID must not be blank." }
        require(questionCount >= 1) { "Question count must be positive." }
        val duration = durationSeconds.coerceIn(0, MAX_DURATION_SECONDS)
        return state.copy(
            examId = examId,
            currentQuestionNumber = 1,
            showQuestionNavigator = false,
            isTaking = true,
            isFinishing = false,
            isSavingResult = false,
            remainingSeconds = duration,
            deadlineEpochMillis = nowEpochMillis + duration * 1_000L,
        )
    }

    fun selectQuestion(state: ExamTakingState, number: Int, questionCount: Int): ExamTakingState {
        if (questionCount < 1) return state.copy(currentQuestionNumber = 1)
        return state.copy(currentQuestionNumber = number.coerceIn(1, questionCount))
    }

    fun nextQuestion(state: ExamTakingState, questionCount: Int): ExamTakingState =
        if (questionCount < 1) state.copy(currentQuestionNumber = 1)
        else state.copy(currentQuestionNumber = (state.currentQuestionNumber + 1).coerceAtMost(questionCount))

    fun previousQuestion(state: ExamTakingState): ExamTakingState =
        state.copy(currentQuestionNumber = (state.currentQuestionNumber - 1).coerceAtLeast(1))

    fun toggleQuestionNavigator(state: ExamTakingState): ExamTakingState =
        state.copy(showQuestionNavigator = !state.showQuestionNavigator)

    fun pause(state: ExamTakingState, nowEpochMillis: Long): ExamTakingState {
        if (!state.isTaking) return state
        return state.copy(
            remainingSeconds = remainingAt(state, nowEpochMillis),
            isTaking = false,
            deadlineEpochMillis = null,
        )
    }

    fun resume(state: ExamTakingState, nowEpochMillis: Long): ExamTakingState {
        if (state.isTaking || state.remainingSeconds <= 0 || state.examId == null) return state
        return state.copy(
            isTaking = true,
            deadlineEpochMillis = nowEpochMillis + state.remainingSeconds * 1_000L,
        )
    }

    fun tick(state: ExamTakingState, nowEpochMillis: Long): ExamTimerTick {
        if (!state.isTaking || state.deadlineEpochMillis == null) {
            return ExamTimerTick(state, expired = false)
        }
        val remaining = remainingAt(state, nowEpochMillis)
        if (remaining == 0) {
            return ExamTimerTick(
                state.copy(
                    remainingSeconds = 0,
                    isTaking = false,
                    isFinishing = true,
                    deadlineEpochMillis = null,
                ),
                expired = true,
            )
        }
        return ExamTimerTick(state.copy(remainingSeconds = remaining), expired = false)
    }

    fun beginFinish(state: ExamTakingState): ExamTakingState? {
        if (!state.isTaking || state.isFinishing) return null
        return state.copy(isFinishing = true, isTaking = false, deadlineEpochMillis = null)
    }

    fun cancelFinish(state: ExamTakingState): ExamTakingState =
        if (state.examId == null || state.remainingSeconds <= 0) state
        else state.copy(isFinishing = false, isTaking = false, deadlineEpochMillis = null)

    fun beginSavingResult(state: ExamTakingState): ExamTakingState? =
        if (!state.isFinishing || state.isSavingResult) null
        else state.copy(isSavingResult = true)

    fun complete(state: ExamTakingState): ExamTakingState =
        state.copy(
            isTaking = false,
            isFinishing = false,
            isSavingResult = false,
            deadlineEpochMillis = null,
        )

    fun stop(state: ExamTakingState, reset: Boolean = false): ExamTakingState =
        if (reset) ExamTakingState()
        else state.copy(isTaking = false, deadlineEpochMillis = null)

    private fun remainingAt(state: ExamTakingState, nowEpochMillis: Long): Int {
        val deadline = state.deadlineEpochMillis ?: return state.remainingSeconds
        val milliseconds = deadline - nowEpochMillis
        if (milliseconds <= 0) return 0
        return ((milliseconds + 999L) / 1_000L)
            .coerceIn(0L, MAX_DURATION_SECONDS.toLong())
            .toInt()
    }

    const val MAX_DURATION_SECONDS = 24 * 60 * 60
}
