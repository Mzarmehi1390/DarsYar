package com.mzarmehi1390.darsyar.features.exams.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ExamDurationOperationsTest {
    @Test
    fun convertsHoursMinutesAndSecondsPrecisely() {
        assertEquals(5_445, ExamDurationOperations.toSeconds(1, 30, 45))
    }

    @Test
    fun acceptsOneSecondAndTheTwentyFourHourBoundary() {
        assertEquals(1, ExamDurationOperations.toSeconds(0, 0, 1))
        assertEquals(86_400, ExamDurationOperations.toSeconds(24, 0, 0))
    }

    @Test
    fun rejectsZeroAndOutOfRangeComponents() {
        assertNull(ExamDurationOperations.toSeconds(0, 0, 0))
        assertNull(ExamDurationOperations.toSeconds(-1, 0, 1))
        assertNull(ExamDurationOperations.toSeconds(25, 0, 0))
        assertNull(ExamDurationOperations.toSeconds(24, 0, 1))
        assertNull(ExamDurationOperations.toSeconds(0, 60, 0))
        assertNull(ExamDurationOperations.toSeconds(0, 0, 60))
    }
}
