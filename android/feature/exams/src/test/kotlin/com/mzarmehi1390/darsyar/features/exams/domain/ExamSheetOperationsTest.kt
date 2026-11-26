package com.mzarmehi1390.darsyar.features.exams.domain

import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ExamSheetOperationsTest {
    private fun sheet() = ExamSheet(
        id = "exam-1",
        name = "آزمون",
        questionCount = 5,
        answers = mapOf(1 to 2, 4 to 1, 5 to 3),
        answerKey = mapOf(1 to 2, 2 to 0, 5 to 3),
        marked = setOf(2, 4),
    )

    @Test
    fun createClampsRangesAndFiltersInvalidAnswerKeyEntries() {
        val created = ExamSheetOperations.create(
            id = "exam-2",
            name = " آزمون جدید ",
            questionCount = 250,
            durationSeconds = 0,
            answerKey = mapOf(1 to 3, 201 to 1, 2 to 9),
        )

        assertEquals(200, created.questionCount)
        assertEquals(1, created.durationSeconds)
        assertEquals(mapOf(1 to 3), created.answerKey)
    }

    @Test
    fun renamePreservesOtherSheetState() {
        val original = sheet()
        val renamed = ExamSheetOperations.rename(original, "آزمون نهایی")

        assertEquals("آزمون نهایی", renamed.name)
        assertEquals(original.answers, renamed.answers)
        assertEquals(original.answerKey, renamed.answerKey)
        assertEquals(original.marked, renamed.marked)
        assertEquals("آزمون", original.name)
    }

    @Test
    fun renameTrimsWhitespaceAndPreservesEveryAnswerSheetField() {
        val original = sheet().copy(
            durationSeconds = 75 * 60,
            negativeMarking = true,
            isCompleted = true,
        )

        val renamed = ExamSheetOperations.rename(original, "  آزمون نهایی  ")

        assertEquals("آزمون نهایی", renamed.name)
        assertEquals(original.copy(name = "آزمون نهایی"), renamed)
        assertEquals("آزمون", original.name)
    }

    @Test
    fun resizeRemovesOutOfRangeAnswersKeysAndMarks() {
        val resized = ExamSheetOperations.resize(sheet(), 2)

        assertEquals(2, resized.questionCount)
        assertEquals(mapOf(1 to 2), resized.answers)
        assertEquals(mapOf(1 to 2, 2 to 0), resized.answerKey)
        assertEquals(setOf(2), resized.marked)
    }

    @Test
    fun selectingAnswerClearsReviewMarkAndClearingCanSetReviewMark() {
        val original = sheet()
        val answered = ExamSheetOperations.setAnswer(original, 2, 1, marked = true)

        assertEquals(1, answered.answers[2])
        assertFalse(answered.marked.contains(2))

        val cleared = ExamSheetOperations.setAnswer(answered, 2, null, marked = true)
        assertFalse(cleared.answers.containsKey(2))
        assertTrue(cleared.marked.contains(2))
    }

    @Test
    fun selectingAnswerClearsOnlyThatQuestionsReviewMarkWithoutMutatingOriginal() {
        val original = sheet()

        val updated = ExamSheetOperations.setAnswer(
            original,
            question = 4,
            answer = 2,
            marked = true,
        )

        assertEquals(mapOf(1 to 2, 4 to 2, 5 to 3), updated.answers)
        assertEquals(setOf(2), updated.marked)
        assertEquals(setOf(2, 4), original.marked)
        assertEquals(mapOf(1 to 2, 4 to 1, 5 to 3), original.answers)
    }

    @Test
    fun invalidQuestionOrOptionDoesNotMutateSheet() {
        val original = sheet()

        assertEquals(original, ExamSheetOperations.setAnswer(original, 0, 1))
        assertEquals(original, ExamSheetOperations.setAnswer(original, 2, 4))
    }

    @Test
    fun replacingKeyFiltersInvalidQuestionAndOptionValues() {
        val replaced = ExamSheetOperations.replaceAnswerKey(
            sheet(),
            mapOf(1 to 0, 2 to 4, 6 to 1),
        )

        assertEquals(mapOf(1 to 0), replaced.answerKey)
    }

    @Test
    fun settingAndRemovingSingleAnswerKeyEntryPreservesOtherSheetData() {
        val original = sheet()
        val updated = ExamSheetOperations.setAnswerKeyOption(original, 3, 2)
        val removed = ExamSheetOperations.setAnswerKeyOption(updated, 1, null)

        assertEquals(mapOf(2 to 0, 3 to 2, 5 to 3), updated.answerKey)
        assertEquals(mapOf(2 to 0, 3 to 2, 5 to 3), removed.answerKey)
        assertEquals(original.answers, removed.answers)
        assertEquals(original.marked, removed.marked)
        assertEquals(mapOf(1 to 2, 2 to 0, 5 to 3), original.answerKey)
    }

    @Test
    fun clearingAnswerKeyDoesNotChangeAnswersSettingsOrReviewMarks() {
        val original = sheet().copy(negativeMarking = true, durationSeconds = 900)
        val cleared = ExamSheetOperations.clearAnswerKey(original)

        assertTrue(cleared.answerKey.isEmpty())
        assertEquals(original.answers, cleared.answers)
        assertEquals(original.marked, cleared.marked)
        assertEquals(original.negativeMarking, cleared.negativeMarking)
        assertEquals(original.durationSeconds, cleared.durationSeconds)
        assertEquals(3, original.answerKey.size)
    }

    @Test
    fun invalidAnswerKeyEntryUpdateDoesNotMutateSheet() {
        val original = sheet()

        assertEquals(original, ExamSheetOperations.setAnswerKeyOption(original, 0, 1))
        assertEquals(original, ExamSheetOperations.setAnswerKeyOption(original, 2, 4))
    }
}
