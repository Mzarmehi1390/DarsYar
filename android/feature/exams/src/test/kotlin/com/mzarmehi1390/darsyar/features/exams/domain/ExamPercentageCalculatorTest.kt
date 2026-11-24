package com.mzarmehi1390.darsyar.features.exams.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ExamPercentageCalculatorTest {
    @Test
    fun calculatesBothPercentages() {
        val result = ExamPercentageCalculator.calculate(correct = 12, wrong = 6, unanswered = 2)

        assertEquals(60.0, result.withoutPenalty!!, 0.0001)
        assertEquals(50.0, result.withPenalty!!, 0.0001)
    }

    @Test
    fun clampsNegativeMarkingAtZero() {
        val result = ExamPercentageCalculator.calculate(correct = 1, wrong = 9, unanswered = 0)

        assertEquals(10.0, result.withoutPenalty!!, 0.0001)
        assertEquals(0.0, result.withPenalty!!, 0.0001)
    }

    @Test
    fun rejectsEmptyAndOverLimitTotals() {
        assertNull(ExamPercentageCalculator.calculate(0, 0, 0).withoutPenalty)
        assertNull(ExamPercentageCalculator.calculate(201, 0, 0).withPenalty)
    }

    @Test
    fun rejectsNegativeCounts() {
        val result = ExamPercentageCalculator.calculate(correct = -1, wrong = 2, unanswered = 3)

        assertNull(result.withoutPenalty)
        assertNull(result.withPenalty)
    }
}
