package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import java.time.LocalDate

object PlannerOperations {
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
            val date = PlannerCalendar.parseDateKey(session.scheduledDate)
            if (date == null) session.weekday == weekday
            else PlannerCalendar.weekdayForDate(date) == weekday
        }.sortedBy(StudySession::startMinutes)
    }

    fun hasOverlap(
        sessions: Iterable<StudySession>,
        candidate: StudySession,
        excludingId: String? = null,
    ): Boolean = sessions.any { session ->
        if (session.id == excludingId) return@any false
        PlannerCalendar.sameOccurrence(
            firstDateKey = candidate.scheduledDate,
            firstWeekday = candidate.weekday,
            secondDateKey = session.scheduledDate,
            secondWeekday = session.weekday,
        ) &&
            candidate.startMinutes < session.startMinutes + session.durationMinutes &&
            session.startMinutes < candidate.startMinutes + candidate.durationMinutes
    }

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
