package com.mzarmehi1390.darsyar.features.exams.domain

import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet

/** Immutable result creation and answer-key synchronization for exam history. */
object ExamResultOperations {
    fun create(
        sheet: ExamSheet,
        id: String,
        completedAt: String,
    ): ExamResult {
        require(id.isNotBlank()) { "Result ID must not be blank." }
        require(completedAt.isNotBlank()) { "Completion timestamp must not be blank." }
        val score = AnswerScoring.calculate(
            answers = sheet.answers,
            answerKey = sheet.answerKey,
            questionCount = sheet.questionCount,
            negativeMarking = sheet.negativeMarking,
        )
        return ExamResult(
            id = id,
            examId = sheet.id,
            examName = sheet.name,
            completedAt = completedAt,
            questionCount = sheet.questionCount,
            correct = score.correct,
            wrong = score.wrong,
            unanswered = score.unanswered,
            keyedQuestions = score.keyedQuestions,
            percentage = score.percentage,
            negativeMarking = sheet.negativeMarking,
            answers = sheet.answers.toMap(),
            answerKey = sheet.answerKey.toMap(),
        )
    }

    fun recalculate(
        result: ExamResult,
        answerKey: Map<Int, Int>,
        negativeMarking: Boolean = result.negativeMarking,
    ): ExamResult {
        val safeKey = answerKey.filter { (question, option) ->
            question in 1..result.questionCount && option in 0..3
        }
        val score = AnswerScoring.calculate(
            answers = result.answers,
            answerKey = safeKey,
            questionCount = result.questionCount,
            negativeMarking = negativeMarking,
        )
        return result.copy(
            correct = score.correct,
            wrong = score.wrong,
            unanswered = score.unanswered,
            keyedQuestions = score.keyedQuestions,
            percentage = score.percentage,
            answerKey = safeKey,
        )
    }

    /**
     * Updates results linked by ID and, only when explicitly safe, legacy
     * rows linked by name. Duplicate sheet names make name-only links ambiguous.
     */
    fun synchronizeAnswerKey(
        results: List<ExamResult>,
        sheet: ExamSheet,
        includeLegacyNameLinks: Boolean = true,
    ): List<ExamResult> = results.map { result ->
        if (belongsTo(result, sheet, includeLegacyNameLinks)) {
            recalculate(result, sheet.answerKey)
        } else {
            result
        }
    }

    /**
     * Mirrors a rename in linked history without changing score data.
     * Name-only legacy rows are changed only when the caller has established
     * that the old sheet name uniquely identifies this sheet.
     */
    fun synchronizeName(
        results: List<ExamResult>,
        sheetId: String,
        previousName: String,
        newName: String,
        includeLegacyNameLinks: Boolean = true,
    ): List<ExamResult> = results.map { result ->
        if (result.examId == sheetId ||
            (includeLegacyNameLinks && result.examId == null && result.examName == previousName)
        ) result.copy(examName = newName) else result
    }

    private fun belongsTo(
        result: ExamResult,
        sheet: ExamSheet,
        includeLegacyNameLinks: Boolean,
    ): Boolean =
        result.examId == sheet.id ||
            (includeLegacyNameLinks && result.examId == null && result.examName == sheet.name)
}
