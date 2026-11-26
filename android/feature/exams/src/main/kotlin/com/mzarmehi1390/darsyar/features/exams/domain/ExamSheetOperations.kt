package com.mzarmehi1390.darsyar.features.exams.domain

import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet

/** Pure, immutable answer-sheet mutations matching the legacy exam workflow. */
object ExamSheetOperations {
    fun create(
        id: String,
        name: String,
        questionCount: Int = 20,
        durationSeconds: Int = 30 * 60,
        negativeMarking: Boolean = false,
        answerKey: Map<Int, Int> = emptyMap(),
    ): ExamSheet {
        require(id.isNotBlank()) { "Exam ID must not be blank." }
        require(name.isNotBlank()) { "Exam name must not be blank." }
        val count = questionCount.coerceIn(1, MAX_QUESTIONS)
        return ExamSheet(
            id = id,
            name = name,
            questionCount = count,
            durationSeconds = durationSeconds.coerceIn(1, MAX_DURATION_SECONDS),
            negativeMarking = negativeMarking,
            answerKey = validAnswers(answerKey, count),
        )
    }

    fun rename(sheet: ExamSheet, name: String): ExamSheet {
        require(name.isNotBlank()) { "Exam name must not be blank." }
        return sheet.copy(name = name.trim())
    }

    /** Resizing discards answers, keys and review marks outside the new range. */
    fun resize(sheet: ExamSheet, requestedCount: Int): ExamSheet {
        val count = requestedCount.coerceIn(1, MAX_QUESTIONS)
        return sheet.copy(
            questionCount = count,
            answers = validAnswers(sheet.answers, count),
            answerKey = validAnswers(sheet.answerKey, count),
            marked = sheet.marked.filterTo(mutableSetOf()) { it in 1..count },
        )
    }

    fun setAnswer(
        sheet: ExamSheet,
        question: Int,
        answer: Int?,
        marked: Boolean = false,
    ): ExamSheet {
        if (question !in 1..sheet.questionCount) return sheet
        if (answer != null && answer !in 0..3) return sheet
        val answers = sheet.answers.toMutableMap()
        val marks = sheet.marked.toMutableSet()
        if (answer != null) {
            answers[question] = answer
            marks.remove(question)
        } else {
            answers.remove(question)
            if (marked) marks.add(question) else marks.remove(question)
        }
        return sheet.copy(answers = answers, marked = marks)
    }

    fun replaceAnswerKey(sheet: ExamSheet, answerKey: Map<Int, Int>): ExamSheet =
        sheet.copy(answerKey = validAnswers(answerKey, sheet.questionCount))

    /** Updates one key entry; null removes it. Invalid indices leave the sheet unchanged. */
    fun setAnswerKeyOption(sheet: ExamSheet, question: Int, answer: Int?): ExamSheet {
        if (question !in 1..sheet.questionCount || (answer != null && answer !in 0..3)) {
            return sheet
        }
        val updated = sheet.answerKey.toMutableMap()
        if (answer == null) updated.remove(question) else updated[question] = answer
        return sheet.copy(answerKey = updated)
    }

    /** Clears the full answer key without changing answers or exam settings. */
    fun clearAnswerKey(sheet: ExamSheet): ExamSheet =
        sheet.copy(answerKey = emptyMap())

    private fun validAnswers(values: Map<Int, Int>, questionCount: Int): Map<Int, Int> =
        values.filter { (question, answer) ->
            question in 1..questionCount && answer in 0..3
        }

    const val MAX_QUESTIONS = 200
    const val MAX_DURATION_SECONDS = 24 * 60 * 60
}
