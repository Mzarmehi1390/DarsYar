package com.mzarmehi1390.darsyar.data

import com.mzarmehi1390.darsyar.core.database.entity.ExamResultEntity
import com.mzarmehi1390.darsyar.core.database.entity.ExamSheetEntity
import com.mzarmehi1390.darsyar.core.database.entity.StudySessionEntity
import com.mzarmehi1390.darsyar.core.database.entity.StudyTaskEntity
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import org.json.JSONArray
import org.json.JSONObject

internal fun StudyTask.toEntity() = StudyTaskEntity(
    id = id,
    title = title,
    subject = subject,
    isDone = done,
    dueDate = dueDate?.let(::formatLocalDate),
)

internal fun StudyTaskEntity.toDomain() = StudyTask(
    id = id,
    title = title,
    subject = subject,
    done = isDone,
    dueDate = dueDate?.let(::parseLocalDate),
)

internal fun StudySession.toEntity() = StudySessionEntity(
    id = id,
    title = title,
    subject = subject,
    weekday = weekday,
    startMinutes = startMinutes,
    durationMinutes = durationMinutes,
    completed = completed,
    scheduledDate = scheduledDate?.let(::formatLocalDate),
)

internal fun StudySessionEntity.toDomain() = StudySession(
    id = id,
    title = title,
    subject = subject,
    weekday = weekday,
    startMinutes = startMinutes,
    durationMinutes = durationMinutes,
    completed = completed,
    scheduledDate = scheduledDate?.let(::parseLocalDate),
)

internal fun ExamSheet.toEntity() = ExamSheetEntity(
    id = id,
    name = name,
    questionCount = questionCount,
    durationSeconds = durationSeconds,
    negativeMarking = negativeMarking,
    isCompleted = isCompleted,
    answersJson = answers.toJsonObject(),
    answerKeyJson = answerKey.toJsonObject(),
    markedJson = marked.toJsonArray(),
)

internal fun ExamSheetEntity.toDomain() = ExamSheet(
    id = id,
    name = name,
    questionCount = questionCount,
    durationSeconds = durationSeconds,
    negativeMarking = negativeMarking,
    isCompleted = isCompleted,
    answers = answersJson.toIntMap(),
    answerKey = answerKeyJson.toIntMap(),
    marked = markedJson.toIntSet(),
)

internal fun ExamResult.toEntity() = ExamResultEntity(
    id = id,
    examId = examId,
    examName = examName,
    completedAt = completedAt,
    questionCount = questionCount,
    correct = correct,
    wrong = wrong,
    unanswered = unanswered,
    keyedQuestions = keyedQuestions,
    percentage = percentage,
    negativeMarking = negativeMarking,
    answersJson = answers.toJsonObject(),
    answerKeyJson = answerKey.toJsonObject(),
)

internal fun ExamResultEntity.toDomain() = ExamResult(
    id = id,
    examId = examId,
    examName = examName,
    completedAt = completedAt,
    questionCount = questionCount,
    correct = correct,
    wrong = wrong,
    unanswered = unanswered,
    keyedQuestions = keyedQuestions,
    percentage = percentage,
    negativeMarking = negativeMarking,
    answers = answersJson.toIntMap(),
    answerKey = answerKeyJson.toIntMap(),
)

private fun Map<Int, Int>.toJsonObject(): String = JSONObject().apply {
    for ((question, answer) in this@toJsonObject) put(question.toString(), answer)
}.toString()

private fun Set<Int>.toJsonArray(): String = JSONArray().apply {
    this@toJsonArray.sorted().forEach(::put)
}.toString()

private fun String.toIntMap(): Map<Int, Int> = runCatching {
    val json = JSONObject(this)
    buildMap {
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next().toIntOrNull() ?: continue
            val value = json.optInt(keys.next(), Int.MIN_VALUE)
            if (value != Int.MIN_VALUE) put(key, value)
        }
    }
}.getOrDefault(emptyMap())

private fun String.toIntSet(): Set<Int> = runCatching {
    val json = JSONArray(this)
    buildSet {
        for (index in 0 until json.length()) {
            if (!json.isNull(index)) add(json.getInt(index))
        }
    }
}.getOrDefault(emptySet())

private fun formatLocalDate(date: java.time.LocalDate): String =
    "%04d-%02d-%02d".format(java.util.Locale.ROOT, date.year, date.monthValue, date.dayOfMonth)

private fun parseLocalDate(value: String): java.time.LocalDate? = runCatching {
    val parts = value.split('-')
    require(parts.size == 3)
    java.time.LocalDate.of(parts[0].toInt(), parts[1].toInt(), parts[2].toInt())
}.getOrNull()
