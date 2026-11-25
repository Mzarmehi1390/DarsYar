package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import java.time.LocalDate

class PlannerDayCopyService {
    fun createPlan(
        sessions: Iterable<StudySession>,
        sourceDate: LocalDate,
        targetDate: LocalDate,
        createId: (StudySession) -> String,
    ): PlannerDayCopyPlan {
        require(sourceDate != targetDate) { "Source and target dates must differ." }
        val sourceWeekday = PlannerCalendar.weekdayForDate(sourceDate)
        val sourceDateKey = PlannerCalendar.dateKey(sourceDate)
        val sourceSessions = sessions.filter { session ->
            PlannerCalendar.sameOccurrence(
                firstDateKey = session.scheduledDate,
                firstWeekday = session.weekday,
                secondDateKey = sourceDateKey,
                secondWeekday = sourceWeekday,
            )
        }.sortedBy(StudySession::startMinutes)
        val copies = sourceSessions.map { source ->
            source.copy(
                id = createId(source),
                weekday = PlannerCalendar.weekdayForDate(targetDate),
                completed = false,
                scheduledDate = PlannerCalendar.dateKey(targetDate),
            )
        }
        return PlannerDayCopyPlan(sourceDate, targetDate, sourceSessions, copies)
    }
}

data class PlannerDayCopyPlan(
    val sourceDate: LocalDate,
    val targetDate: LocalDate,
    val sourceSessions: List<StudySession>,
    val copiedSessions: List<StudySession>,
)

sealed interface PlannerDayCopyResult {
    data class Copied(val sessionCount: Int) : PlannerDayCopyResult
    data object TargetDateNotEmpty : PlannerDayCopyResult
    data object SessionConflict : PlannerDayCopyResult
    data object IdCollision : PlannerDayCopyResult
    data object SourceChanged : PlannerDayCopyResult
}
