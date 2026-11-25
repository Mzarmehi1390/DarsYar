package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PlannerOperationsTest {
    private fun session(
        id: String,
        weekday: Int = 2,
        start: Int = 9 * 60,
        duration: Int = 60,
        date: String? = null,
    ) = StudySession(
        id = id,
        title = "مطالعه",
        subject = "ریاضی",
        weekday = weekday,
        startMinutes = start,
        durationMinutes = duration,
        scheduledDate = date,
    )

    @Test
    fun overlapUsesConcreteDateEvenWhenStoredWeekdayIsStale() {
        val existing = session("existing", weekday = 1, date = "2026-11-24")
        val candidate = session("candidate", weekday = 2, start = 9 * 60 + 30, date = "2026-11-24")

        assertTrue(PlannerOperations.hasOverlap(listOf(existing), candidate))
    }

    @Test
    fun differentDatedOccurrencesDoNotOverlapJustBecauseWeekdayMatches() {
        val monday = session("monday", weekday = 1, date = "2026-11-23")
        val followingMonday = session("following-monday", weekday = 1, date = "2026-11-30")
        val candidate = session("candidate", weekday = 1, start = 9 * 60 + 15, date = "2026-11-30")

        assertFalse(PlannerOperations.hasOverlap(listOf(monday), candidate))
        assertTrue(PlannerOperations.hasOverlap(listOf(followingMonday), candidate))
    }

    @Test
    fun datedAndLegacyOccurrencesAreComparedByEffectiveWeekday() {
        val datedTuesday = session("dated", weekday = 0, date = "2026-11-24")
        val legacyTuesday = session("legacy", weekday = 2, start = 9 * 60 + 20)

        assertTrue(PlannerOperations.hasOverlap(listOf(datedTuesday), legacyTuesday))
        assertTrue(PlannerOperations.hasOverlap(listOf(legacyTuesday), datedTuesday))
    }

    @Test
    fun adjacentIntervalsDoNotOverlap() {
        val existing = session("existing", start = 9 * 60, duration = 60)
        val candidate = session("candidate", start = 10 * 60, duration = 45)

        assertFalse(PlannerOperations.hasOverlap(listOf(existing), candidate))
    }

    @Test
    fun malformedStoredDateIsNotReinterpretedAsLegacyWeekday() {
        val malformed = session("malformed", weekday = 2, date = "24/11/2026")
        val candidate = session("candidate", weekday = 2, start = 9 * 60 + 15)

        assertFalse(PlannerOperations.hasOverlap(listOf(malformed), candidate))
    }

    @Test
    fun invalidPersistedTimeRangeDoesNotBlockAValidSession() {
        val corrupted = session("corrupted", start = 23 * 60 + 30, duration = 90)
        val candidate = session("candidate", start = 23 * 60 + 30, duration = 20)

        assertFalse(PlannerOperations.hasOverlap(listOf(corrupted), candidate))
    }

    @Test
    fun sessionsForDateExcludesLegacyAndMalformedDatesAndSortsByStartTime() {
        val late = session("late", start = 11 * 60, date = "2026-11-24")
        val early = session("early", start = 8 * 60, date = "2026-11-24")
        val legacy = session("legacy", weekday = 2)
        val malformed = session("malformed", weekday = 2, date = "24/11/2026")

        assertEquals(
            listOf(early, late),
            PlannerOperations.sessionsForDate(
                listOf(late, legacy, malformed, early),
                LocalDate.parse("2026-11-24"),
            ),
        )
    }

    @Test
    fun migrateLegacySessionsPreservesConcreteDatesAndMigratesOnlyMissingDates() {
        val dated = session("dated", weekday = 2, date = "2026-11-30")
        val legacy = session("legacy", weekday = 2)
        val migrated = PlannerOperations.migrateLegacySessions(
            listOf(dated, legacy),
            referenceDate = LocalDate.parse("2026-11-24"),
        )

        assertEquals(dated, migrated[0])
        assertEquals("2026-11-24", migrated[1].scheduledDate)
        assertEquals(2, migrated[1].weekday)
    }
}
