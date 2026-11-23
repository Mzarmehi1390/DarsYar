package com.mzarmehi1390.darsyar.features.exams.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ExamTakingOperationsTest {
    @Test
    fun beginResetsNavigationAndCreatesDeadline() {
        val initial = ExamTakingState(currentQuestionNumber = 8, showQuestionNavigator = true)
        val started = ExamTakingOperations.begin(initial, "exam-1", 90, 20, 1_000L)

        assertEquals("exam-1", started.examId)
        assertEquals(1, started.currentQuestionNumber)
        assertFalse(started.showQuestionNavigator)
        assertTrue(started.isTaking)
        assertEquals(91_000L, started.deadlineEpochMillis)
        assertEquals(90, started.remainingSeconds)
    }

    @Test
    fun questionNavigationIsBounded() {
        val first = ExamTakingState(currentQuestionNumber = 1)
        assertEquals(1, ExamTakingOperations.previousQuestion(first).currentQuestionNumber)
        assertEquals(20, ExamTakingOperations.selectQuestion(first, 99, 20).currentQuestionNumber)
        assertEquals(2, ExamTakingOperations.nextQuestion(first, 20).currentQuestionNumber)
        assertEquals(1, ExamTakingOperations.selectQuestion(first, 9, 0).currentQuestionNumber)
    }

    @Test
    fun timerTickUsesDeadlineAndRoundsUpRemainingSeconds() {
        val running = ExamTakingOperations.begin(ExamTakingState(), "exam-1", 10, 5, 5_000L)
        val tick = ExamTakingOperations.tick(running, 5_001L)

        assertEquals(10, tick.state.remainingSeconds)
        assertFalse(tick.expired)
    }

    @Test
    fun timerExpiresExactlyOnceAndMovesToFinishing() {
        val running = ExamTakingOperations.begin(ExamTakingState(), "exam-1", 2, 5, 0L)
        val expired = ExamTakingOperations.tick(running, 2_000L)
        val repeated = ExamTakingOperations.tick(expired.state, 3_000L)

        assertTrue(expired.expired)
        assertEquals(0, expired.state.remainingSeconds)
        assertTrue(expired.state.isFinishing)
        assertFalse(expired.state.isTaking)
        assertFalse(repeated.expired)
    }

    @Test
    fun pauseAndResumePreserveRemainingDuration() {
        val running = ExamTakingOperations.begin(ExamTakingState(), "exam-1", 10, 5, 0L)
        val paused = ExamTakingOperations.pause(running, 3_250L)
        val resumed = ExamTakingOperations.resume(paused, 20_000L)

        assertEquals(7, paused.remainingSeconds)
        assertFalse(paused.isTaking)
        assertNull(paused.deadlineEpochMillis)
        assertTrue(resumed.isTaking)
        assertEquals(27_000L, resumed.deadlineEpochMillis)
    }

    @Test
    fun finishAndResultSavingAreGuardedAgainstDuplicateCalls() {
        val running = ExamTakingOperations.begin(ExamTakingState(), "exam-1", 30, 5, 0L)
        val finishing = ExamTakingOperations.beginFinish(running)!!

        assertTrue(finishing.isTaking)
        assertTrue(finishing.isFinishing)
        assertNull(ExamTakingOperations.beginFinish(finishing))
        val saving = ExamTakingOperations.beginSavingResult(finishing)!!
        assertNull(ExamTakingOperations.beginSavingResult(saving))
        assertFalse(ExamTakingOperations.complete(saving).isSavingResult)
    }

    @Test
    fun cancelManualFinishKeepsCountdownRunning() {
        val running = ExamTakingOperations.begin(ExamTakingState(), "exam-1", 30, 5, 0L)
        val confirmation = ExamTakingOperations.beginFinish(running)!!
        val cancelled = ExamTakingOperations.cancelFinish(confirmation)

        assertTrue(cancelled.isTaking)
        assertFalse(cancelled.isFinishing)
        assertEquals(running.deadlineEpochMillis, cancelled.deadlineEpochMillis)
    }

    @Test
    fun resetClearsAllSessionState() {
        val running = ExamTakingOperations.begin(ExamTakingState(), "exam-1", 30, 5, 0L)
        assertEquals(ExamTakingState(), ExamTakingOperations.stop(running, reset = true))
    }
}
