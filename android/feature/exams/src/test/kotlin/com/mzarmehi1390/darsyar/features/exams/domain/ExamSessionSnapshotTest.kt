package com.mzarmehi1390.darsyar.features.exams.domain

import org.junit.Assert.assertEquals
import org.junit.Test

class ExamSessionSnapshotTest {
    @Test
    fun pausedSessionHasNoDeadline() {
        val snapshot = ExamSessionSnapshot("exam", 1, null, 120, true)
        assertEquals(true, snapshot.isPaused)
    }

    @Test
    fun expiredRunningSessionRetainsItsDeadline() {
        val snapshot = ExamSessionSnapshot("exam", 1, 10_000L, 0, false)
        assertEquals(10_000L, snapshot.deadlineEpochMillis)
    }

    @Test(expected = IllegalArgumentException::class)
    fun runningSessionCannotHaveNullDeadlineAtZeroRemainingTime() {
        ExamSessionSnapshot("exam", 1, null, 0, false)
    }

    @Test(expected = IllegalArgumentException::class)
    fun pausedSessionCannotRetainDeadlineAtZeroRemainingTime() {
        ExamSessionSnapshot("exam", 1, 10_000L, 0, true)
    }
}
