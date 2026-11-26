package com.mzarmehi1390.darsyar.features.exams.domain

import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ExamHistoryAnalyticsTest {
    private fun result(id: String, date: String, percentage: Double?) = ExamResult(
        id = id, examId = null, examName = "آزمون $id", completedAt = date,
        questionCount = 10, correct = 0, wrong = 0, unanswered = 10,
        keyedQuestions = 0, percentage = percentage,
    )

    @Test
    fun summarizeSeparatesAttemptCountFromScoredAttemptsAndOrdersTrend() {
        val results = listOf(
            result("third", "2026-11-03T10:00:00Z", 80.0),
            result("unscored", "2026-11-02T10:00:00Z", null),
            result("first", "2026-11-01T10:00:00Z", 40.0),
            result("second", "2026-11-02T09:00:00Z", 60.0),
        )
        val summary = ExamHistoryAnalytics.summarize(results)
        assertEquals(4, summary.attemptCount)
        assertEquals(3, summary.scoredAttemptCount)
        assertEquals(60.0, summary.averagePercentage!!, 0.000001)
        assertEquals(80.0, summary.bestPercentage!!, 0.000001)
        assertEquals(listOf(40.0, 60.0, 80.0), summary.recentTrend)
    }

    @Test
    fun summarizeReturnsEmptyScoreStatisticsWhenNoResultCanBeScored() {
        val summary = ExamHistoryAnalytics.summarize(
            listOf(result("a", "2026-11-01T10:00:00Z", null)),
        )
        assertEquals(1, summary.attemptCount)
        assertEquals(0, summary.scoredAttemptCount)
        assertNull(summary.averagePercentage)
        assertNull(summary.bestPercentage)
        assertEquals(emptyList<Double>(), summary.recentTrend)
    }

    @Test
    fun summarizeOrdersOffsetTimestampsByInstantRatherThanText() {
        val results = listOf(
            result("later", "2026-11-01T08:00:00Z", 80.0),
            result("earlier", "2026-11-01T10:00:00+03:00", 40.0),
        )

        val summary = ExamHistoryAnalytics.summarize(results)

        assertEquals(listOf(40.0, 80.0), summary.recentTrend)
    }

    @Test
    fun summarizeKeepsOnlySevenMostRecentScoredAttempts() {
        val results = (1..9).map { index ->
            result("r$index", "2026-11-%02dT10:00:00Z".format(index), index * 10.0)
        }
        val summary = ExamHistoryAnalytics.summarize(results)
        assertEquals((30..90 step 10).map(Int::toDouble), summary.recentTrend)
    }
}
