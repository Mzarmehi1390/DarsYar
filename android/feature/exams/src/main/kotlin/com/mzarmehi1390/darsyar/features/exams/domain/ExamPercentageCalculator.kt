package com.mzarmehi1390.darsyar.features.exams.domain

data class ExamPercentageResult(
    val withoutPenalty: Double?,
    val withPenalty: Double?,
)

/** Calculates both common exam percentages using the total number of questions as denominator. */
object ExamPercentageCalculator {
    fun calculate(correct: Int, wrong: Int, unanswered: Int): ExamPercentageResult {
        if (correct < 0 || wrong < 0 || unanswered < 0) {
            return ExamPercentageResult(null, null)
        }
        val total = correct.toLong() + wrong.toLong() + unanswered.toLong()
        if (total !in 1L..200L) return ExamPercentageResult(null, null)

        val denominator = total.toDouble()
        val plain = correct * 100.0 / denominator
        val penalized = ((correct - wrong / 3.0) * 100.0 / denominator)
            .coerceIn(0.0, 100.0)
        return ExamPercentageResult(plain, penalized)
    }
}
