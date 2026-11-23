package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession

data class PlannerSummary(
    val totalSessionCount: Int,
    val completedSessionCount: Int,
    val plannedMinutes: Int,
    val completedMinutes: Int,
    val sessionsByDay: Map<Int, List<StudySession>>,
    val minutesByDay: Map<Int, Int>,
) {
    val completion: Double
        get() = if (plannedMinutes == 0) 0.0 else completedMinutes.toDouble() / plannedMinutes

    companion object {
        fun fromSessions(sessions: Iterable<StudySession>): PlannerSummary {
            val byDay = mutableMapOf<Int, MutableList<StudySession>>()
            val minutesByDay = mutableMapOf<Int, Int>()
            var total = 0
            var completedCount = 0
            var planned = 0
            var completed = 0

            sessions.forEach { session ->
                total++
                planned += session.durationMinutes
                if (session.completed) {
                    completedCount++
                    completed += session.durationMinutes
                }
                val date = PlannerCalendar.parseDateKey(session.scheduledDate)
                val day = date?.let(PlannerCalendar::weekdayForDate) ?: session.weekday
                byDay.getOrPut(day) { mutableListOf() }.add(session)
                minutesByDay[day] = (minutesByDay[day] ?: 0) + session.durationMinutes
            }

            val immutableByDay = byDay.mapValues { (_, items) ->
                items.sortedBy(StudySession::startMinutes).toList()
            }
            return PlannerSummary(
                totalSessionCount = total,
                completedSessionCount = completedCount,
                plannedMinutes = planned,
                completedMinutes = completed,
                sessionsByDay = immutableByDay,
                minutesByDay = minutesByDay.toMap(),
            )
        }
    }
}
