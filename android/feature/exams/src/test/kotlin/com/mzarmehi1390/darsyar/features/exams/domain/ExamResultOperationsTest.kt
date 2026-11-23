package com.mzarmehi1390.darsyar.features.exams.domain

import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertNotEquals
import org.junit.Test

class ExamResultOperationsTest {
    private fun sheet() = ExamSheet(
        id = "sheet-1",
        name = "آزمون زیست",
        questionCount = 4,
        negativeMarking = true,
        answers = mapOf(1 to 2, 2 to 1, 3 to 0),
        answerKey = mapOf(1 to 2, 2 to 0, 3 to 0),
    )

    private fun result() = ExamResult(
        id = "result-1",
        examId = "sheet-1",
        examName = "آزمون زیست",
        completedAt = "2026-11-23T10:00:00Z",
        questionCount = 4,
        correct = 2,
        wrong = 1,
        unanswered = 1,
        keyedQuestions = 3,
        percentage = 55.555,
        negativeMarking = true,
        answers = mapOf(1 to 2, 2 to 1, 3 to 0),
        answerKey = mapOf(1 to 2, 2 to 0, 3 to 0),
    )

    @Test
    fun createCapturesAnswerAndKeySnapshotsWithScore() {
        val created = ExamResultOperations.create(sheet(), "result-2", "2026-11-23T12:00:00Z")

        assertEquals("sheet-1", created.examId)
        assertEquals("آزمون زیست", created.examName)
        assertEquals(2, created.correct)
        assertEquals(1, created.wrong)
        assertEquals(1, created.unanswered)
        assertEquals(3, created.keyedQuestions)
        assertEquals(55.55555555555556, created.percentage!!, 0.000001)
        assertEquals(sheet().answers, created.answers)
        assertEquals(sheet().answerKey, created.answerKey)
    }

    @Test
    fun recalculateUsesNewKeyWithoutChangingAttemptSnapshot() {
        val original = result()
        val recalculated = ExamResultOperations.recalculate(original, mapOf(1 to 2, 2 to 1))

        assertEquals(2, recalculated.correct)
        assertEquals(0, recalculated.wrong)
        assertEquals(2, recalculated.keyedQuestions)
        assertEquals(100.0, recalculated.percentage!!, 0.000001)
        assertEquals(original.answers, recalculated.answers)
        assertNotEquals(original.answerKey, recalculated.answerKey)
    }

    @Test
    fun recalculatingWithEmptyKeyProducesNullPercentage() {
        val recalculated = ExamResultOperations.recalculate(result(), emptyMap())
        assertEquals(0, recalculated.keyedQuestions)
        assertNull(recalculated.percentage)
    }

    @Test
    fun synchronizeKeyUpdatesOnlyLinkedResultsAndSupportsLegacyNameLink() {
        val legacy = result().copy(id = "legacy", examId = null)
        val unrelated = result().copy(id = "other", examId = "other-sheet", examName = "Other")
        val synchronized = ExamResultOperations.synchronizeAnswerKey(
            listOf(result(), legacy, unrelated),
            sheet(),
        )

        assertEquals(2, synchronized[0].correct)
        assertEquals(2, synchronized[1].correct)
        assertEquals(unrelated, synchronized[2])
    }

    @Test
    fun synchronizeNamePreservesScoresAndOnlyRenamesLinkedHistory() {
        val unrelated = result().copy(id = "other", examId = "other-sheet", examName = "Other")
        val renamed = ExamResultOperations.synchronizeName(
            listOf(result(), result().copy(id = "legacy", examId = null), unrelated),
            "sheet-1",
            "آزمون زیست",
            "آزمون نهایی",
        )

        assertEquals("آزمون نهایی", renamed[0].examName)
        assertEquals("آزمون نهایی", renamed[1].examName)
        assertEquals(result().percentage, renamed[0].percentage)
        assertEquals(unrelated, renamed[2])
    }
}
