package com.mzarmehi1390.darsyar.features.exams.domain

data class AnswerScore(
    val correct: Int,
    val wrong: Int,
    val unanswered: Int,
    val keyedQuestions: Int,
    val percentage: Double?,
    val rawScore: Double,
)

/**
 * Mirrors the existing Flutter scoring contract:
 * unkeyed questions are excluded; each wrong answer costs one third of a
 * correct answer when negative marking is enabled; percentage is clamped.
 */
object AnswerScoring {
    fun calculate(
        answers: Map<Int, Int>,
        answerKey: Map<Int, Int>,
        questionCount: Int,
        negativeMarking: Boolean = false,
    ): AnswerScore {
        val safeQuestionCount = questionCount.coerceAtLeast(0)
        val validKey = answerKey.filter { (question, option) ->
            question in 1..safeQuestionCount && option in 0..3
        }
        val validAnswers = answers.filter { (question, option) ->
            question in 1..safeQuestionCount && option in 0..3
        }

        var correct = 0
        var wrong = 0
        validKey.forEach { (question, expected) ->
            val selected = validAnswers[question] ?: return@forEach
            if (selected == expected) correct++ else wrong++
        }

        val keyedQuestions = validKey.size
        val unanswered = safeQuestionCount - validAnswers.size
        val rawScore = correct.toDouble() - if (negativeMarking) wrong / 3.0 else 0.0
        val percentage = if (keyedQuestions == 0) {
            null
        } else {
            (rawScore * 100.0 / keyedQuestions).coerceIn(0.0, 100.0)
        }

        return AnswerScore(
            correct = correct,
            wrong = wrong,
            unanswered = unanswered,
            keyedQuestions = keyedQuestions,
            percentage = percentage,
            rawScore = rawScore,
        )
    }
}
