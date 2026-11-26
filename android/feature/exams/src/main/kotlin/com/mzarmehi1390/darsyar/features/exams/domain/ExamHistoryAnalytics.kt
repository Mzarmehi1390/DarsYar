package com.mzarmehi1390.darsyar.features.exams.domain

import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import java.time.Instant

/** Lightweight, deterministic aggregates for the exam-history overview. */
data class ExamHistorySummary(
    val attemptCount: Int,
    val scoredAttemptCount: Int,
    val averagePercentage: Double?,
    val bestPercentage: Double?,
    /** Up to seven scored attempts, ordered oldest to newest. */
    val recentTrend: List<Double>,
)

object ExamHistoryAnalytics {
    fun summarize(results: List<ExamResult>): ExamHistorySummary {
        val percentages = results.asSequence()
            .filter { it.percentage != null }
            .sortedWith(
                compareBy<ExamResult> { timestamp(it.completedAt) }
                    .thenBy { it.id },
            )
            .mapNotNull { it.percentage }
            .toList()
        return ExamHistorySummary(
            attemptCount = results.size,
            scoredAttemptCount = percentages.size,
            averagePercentage = percentages.takeIf { it.isNotEmpty() }?.average(),
            bestPercentage = percentages.maxOrNull(),
            recentTrend = percentages.takeLast(7),
        )
    }

    private fun timestamp(value: String): Long =
        runCatching { Instant.parse(value).toEpochMilli() }.getOrDefault(0L)
}
