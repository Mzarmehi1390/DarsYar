package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import kotlinx.coroutines.flow.Flow

/** Persistence contract consumed by planner and dashboard presentation logic. */
interface PlannerRepository {
    fun observeTasks(): Flow<List<StudyTask>>
    fun observeStudySessions(): Flow<List<StudySession>>
    suspend fun upsertTask(task: StudyTask)
    suspend fun deleteTask(id: String)
    suspend fun upsertStudySession(session: StudySession)
    suspend fun deleteStudySession(id: String)
    suspend fun copyWeekPlan(plan: PlannerWeekCopyPlan): PlannerWeekCopyResult
    suspend fun copyDayPlan(plan: PlannerDayCopyPlan): PlannerDayCopyResult
}
