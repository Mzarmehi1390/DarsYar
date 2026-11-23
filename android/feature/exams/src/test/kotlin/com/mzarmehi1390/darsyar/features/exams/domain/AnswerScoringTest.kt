package com.mzarmehi1390.darsyar.features.exams.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AnswerScoringTest {
    @Test
    fun unkeyedQuestionsDoNotAffectDenominator() {
        val result = AnswerScoring.calculate(
            answers = mapOf(1 to 2, 2 to 1, 3 to 0),
            answerKey = mapOf(1 to 2, 2 to 3),
            questionCount = 5,
        )

        assertEquals(1, result.correct)
        assertEquals(1, result.wrong)
        assertEquals(2, result.keyedQuestions)
        assertEquals(2, result.unanswered)
        assertEquals(50.0, result.percentage!!, 0.0001)
    }

    @Test
    fun threeWrongAnswersCancelOneCorrectAnswerWithNegativeMarking() {
        val result = AnswerScoring.calculate(
            answers = mapOf(1 to 0, 2 to 0, 3 to 0, 4 to 0),
            answerKey = mapOf(1 to 0, 2 to 1, 3 to 1, 4 to 1),
            questionCount = 4,
            negativeMarking = true,
        )

        assertEquals(1, result.correct)
        assertEquals(3, result.wrong)
        assertEquals(0.0, result.rawScore, 0.0001)
        assertEquals(0.0, result.percentage!!, 0.0001)
    }

    @Test
    fun noValidAnswerKeyProducesNullPercentage() {
        val result = AnswerScoring.calculate(
            answers = mapOf(1 to 2),
            answerKey = mapOf(0 to 1, 4 to 2),
            questionCount = 3,
        )

        assertEquals(0, result.keyedQuestions)
        assertNull(result.percentage)
    }

    @Test
    fun invalidQuestionNumbersAndOptionsAreIgnored() {
        val result = AnswerScoring.calculate(
            answers = mapOf(1 to 4, 2 to 1, 5 to 0),
            answerKey = mapOf(1 to 0, 2 to 1, 5 to 0),
            questionCount = 2,
        )

        assertEquals(1, result.correct)
        assertEquals(0, result.wrong)
        assertEquals(2, result.keyedQuestions)
        assertEquals(1, result.unanswered)
        assertEquals(50.0, result.percentage!!, 0.0001)
    }

    @Test
    fun negativeRawScoreIsClampedAtZeroPercentage() {
        val result = AnswerScoring.calculate(
            answers = mapOf(1 to 1, 2 to 1),
            answerKey = mapOf(1 to 0, 2 to 0),
            questionCount = 2,
            negativeMarking = true,
        )

        assertEquals(0.0, result.percentage!!, 0.0001)
        assertEquals(-2.0 / 3.0, result.rawScore, 0.0001)
    }
}
