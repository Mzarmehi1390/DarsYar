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

    fun recalculate(result: ExamResult, answerKey: Map<Int, Int>): ExamResult {
        val safeKey = answerKey.filter { (question, option) ->
            question in 1..result.questionCount && option in 0..3
        }
        val score = AnswerScoring.calculate(
            answers = result.answers,
            answerKey = safeKey,
            questionCount = result.questionCount,
            negativeMarking = result.negativeMarking,
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

    /** Updates only results belonging to this sheet, including legacy name links. */
    fun synchronizeAnswerKey(
        results: List<ExamResult>,
        sheet: ExamSheet,
    ): List<ExamResult> = results.map { result ->
        if (belongsTo(result, sheet)) recalculate(result, sheet.answerKey) else result
    }

    /** Mirrors a sheet rename in its historical rows without changing score data. */
    fun synchronizeName(
        results: List<ExamResult>,
        sheetId: String,
        previousName: String,
        newName: String,
    ): List<ExamResult> = results.map { result ->
        if (result.examId == sheetId ||
            (result.examId == null && result.examName == previousName)
        ) result.copy(examName = newName) else result
    }

    private fun belongsTo(result: ExamResult, sheet: ExamSheet): Boolean =
        result.examId == sheet.id ||
            (result.examId == null && result.examName == sheet.name)
}
