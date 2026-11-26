package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import java.time.LocalDate

object PlannerOperations {
    /**
     * Counts occurrences for a seven-day planner strip in one pass.
     * Each stored date is parsed at most once; legacy weekday-only records
     * are assigned to the matching date in [dates]. Malformed non-null dates
     * are excluded rather than silently reinterpreted as recurring sessions.
     */
    fun sessionCountsByDate(
        sessions: Iterable<StudySession>,
        dates: List<LocalDate>,
    ): Map<LocalDate, Int> {
        if (dates.isEmpty()) return emptyMap()
        val validDates = dates.toHashSet()
        val dateByWeekday = dates.associateBy { PlannerCalendar.weekdayForDate(it) }
        val counts = HashMap<LocalDate, Int>(dates.size)

        for (session in sessions) {
            val occurrenceDate = if (session.scheduledDate == null) {
                dateByWeekday[session.weekday]
            } else {
                PlannerCalendar.parseDateKey(session.scheduledDate)
                    ?.takeIf(validDates::contains)
            }
            if (occurrenceDate != null) {
                counts[occurrenceDate] = (counts[occurrenceDate] ?: 0) + 1
            }
        }
        return dates.associateWith { counts[it] ?: 0 }
    }

    /**
     * Returns exact-date sessions plus legacy weekday-only sessions for [date].
     * Malformed dated records are intentionally not treated as legacy records.
     */
    fun sessionsForPlannerDate(
        sessions: Iterable<StudySession>,
        date: LocalDate,
    ): List<StudySession> {
        val weekday = PlannerCalendar.weekdayForDate(date)
        return sessions.filter { session ->
            if (session.scheduledDate == null) session.weekday == weekday
            else PlannerCalendar.parseDateKey(session.scheduledDate) == date
        }.sortedBy(StudySession::startMinutes)
    }

    fun migrateLegacySessions(
        sessions: Iterable<StudySession>,
        referenceDate: LocalDate,
    ): List<StudySession> = sessions.map { session ->
        if (session.scheduledDate != null) session
        else session.copy(
            scheduledDate = PlannerCalendar.dateKey(
                PlannerCalendar.migrateLegacyDate(session.weekday, referenceDate),
            ),
        )
    }

    fun sessionsForDate(
        sessions: Iterable<StudySession>,
        date: LocalDate,
    ): List<StudySession> = sessions.filter { session ->
        PlannerCalendar.parseDateKey(session.scheduledDate) == date
    }.sortedBy(StudySession::startMinutes)

    fun sessionsForWeek(
        sessions: Iterable<StudySession>,
        weekStart: LocalDate,
    ): List<StudySession> = sessions.filter { session ->
        val date = PlannerCalendar.parseDateKey(session.scheduledDate)
        date != null && PlannerCalendar.isInWeek(date, weekStart)
    }

    fun sessionsForDay(
        sessions: Iterable<StudySession>,
        weekday: Int,
    ): List<StudySession> {
        require(weekday in 0..6)
        return sessions.filter { session ->
            when {
                session.scheduledDate == null -> session.weekday == weekday
                else -> PlannerCalendar.parseDateKey(session.scheduledDate)
                    ?.let(PlannerCalendar::weekdayForDate) == weekday
            }
        }.sortedBy(StudySession::startMinutes)
    }

    /** Uses the same occurrence and interval rules for every planner save path. */
    fun hasOverlap(
        sessions: Iterable<StudySession>,
        candidate: StudySession,
        excludingId: String? = null,
    ): Boolean {
        if (!hasValidTimeRange(candidate)) return false
        val candidateStart = candidate.startMinutes.toLong()
        val candidateEnd = candidateStart + candidate.durationMinutes.toLong()
        return sessions.any { session ->
            if (session.id == excludingId || !hasValidTimeRange(session)) return@any false
            PlannerCalendar.sameOccurrence(
                firstDateKey = candidate.scheduledDate,
                firstWeekday = candidate.weekday,
                secondDateKey = session.scheduledDate,
                secondWeekday = session.weekday,
            ) && candidateStart < session.startMinutes.toLong() + session.durationMinutes.toLong() &&
                session.startMinutes.toLong() < candidateEnd
        }
    }

    private fun hasValidTimeRange(session: StudySession): Boolean =
        session.startMinutes in 0 until 24 * 60 &&
            session.durationMinutes > 0 &&
            session.durationMinutes <= 24 * 60 - session.startMinutes

    fun copyDay(
        sessions: Iterable<StudySession>,
        sourceWeekday: Int,
        targetDate: LocalDate,
        createId: (StudySession) -> String,
    ): List<StudySession> = sessionsForDay(sessions, sourceWeekday).map { source ->
        StudySession(
            id = createId(source),
            title = source.title,
            subject = source.subject,
            weekday = PlannerCalendar.weekdayForDate(targetDate),
            startMinutes = source.startMinutes,
            durationMinutes = source.durationMinutes,
            completed = false,
            scheduledDate = PlannerCalendar.dateKey(targetDate),
        )
    }

    fun copyTaskToDate(task: StudyTask, targetDate: LocalDate, newId: String): StudyTask =
        task.copy(
            id = newId,
            done = false,
            dueDate = PlannerCalendar.dateKey(targetDate),
        )
}
