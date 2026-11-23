package com.mzarmehi1390.darsyar.features.planner.domain.models

/** Immutable task model shared by the dashboard and planner. */
data class StudyTask(
    val id: String,
    val title: String,
    val subject: String,
    val done: Boolean = false,
    /** ISO local calendar date (yyyy-MM-dd), null when unscheduled. */
    val dueDate: String? = null,
)
