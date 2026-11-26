package com.mzarmehi1390.darsyar.features.statistics.domain

import com.mzarmehi1390.darsyar.features.planner.domain.PlannerCalendar
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import java.time.LocalDate
import java.time.temporal.ChronoUnit

data class DailyStudyTotal(
    val date: LocalDate,
    val plannedMinutes: Int,
    val completedMinutes: Int,
)

data class StudyStatistics(
    val weekStart: LocalDate,
    val dailyTotals: List<DailyStudyTotal>,
    val totalPlannedMinutes: Int,
    val totalCompletedMinutes: Int,
    val completedTaskCount: Int,
    val totalTaskCount: Int,
) {
    val completion: Double
        get() = if (totalPlannedMinutes == 0) 0.0 else totalCompletedMinutes.toDouble() / totalPlannedMinutes

    val taskCompletion: Double
        get() = if (totalTaskCount == 0) 0.0 else completedTaskCount.toDouble() / totalTaskCount

    companion object {
        fun calculate(
            sessions: Iterable<StudySession>,
            tasks: Iterable<StudyTask>,
            anchorDate: LocalDate,
        ): StudyStatistics {
            val start = PlannerCalendar.startOfWeek(anchorDate)
            val totals = PlannerCalendar.days(start).map { DailyStudyTotal(it, 0, 0) }.toMutableList()

            sessions.forEach { session ->
                val date = if (session.scheduledDate == null) {
                    runCatching { PlannerCalendar.dateForWeekday(start, session.weekday) }.getOrNull()
                } else {
                    PlannerCalendar.parseDateKey(session.scheduledDate)
                } ?: return@forEach
                if (!PlannerCalendar.isInWeek(date, start)) return@forEach

                val index = ChronoUnit.DAYS.between(start, date).toInt()
                val current = totals[index]
                totals[index] = current.copy(
                    plannedMinutes = current.plannedMinutes + session.durationMinutes,
                    completedMinutes = current.completedMinutes + if (session.completed) session.durationMinutes else 0,
                )
            }

            val taskList = tasks.toList()
            return StudyStatistics(
                weekStart = start,
                dailyTotals = totals.toList(),
                totalPlannedMinutes = totals.sumOf(DailyStudyTotal::plannedMinutes),
                totalCompletedMinutes = totals.sumOf(DailyStudyTotal::completedMinutes),
                completedTaskCount = taskList.count(StudyTask::done),
                totalTaskCount = taskList.size,
            )
        }
    }
}
