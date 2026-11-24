package com.mzarmehi1390.darsyar.data

import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonObjectBuilder
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.time.LocalDate
import java.time.format.DateTimeParseException

/**
 * Portable, versioned JSON contract shared with the legacy Flutter application.
 *
 * Parsing and validation are deliberately completed before a caller can mutate
 * the database. Unknown object properties are ignored for forward compatibility,
 * while unknown schema versions and malformed known fields are rejected.
 */
internal object DarsYarBackupCodec {
    const val APP_NAME = "DarsYar"
    const val SCHEMA_VERSION = 1

    private val json = Json {
        prettyPrint = true
        prettyPrintIndent = "  "
    }

    fun encode(snapshot: DarsYarSnapshot, exportedAt: String): String {
        require(snapshot.exams.isNotEmpty()) { "A backup must contain at least one exam sheet." }
        val activeId = snapshot.activeExamId
            ?.takeIf { requested -> snapshot.exams.any { it.id == requested } }
            ?: snapshot.exams.first().id
        val payload = buildJsonObject {
            put("app", JsonPrimitive(APP_NAME))
            put("schemaVersion", JsonPrimitive(SCHEMA_VERSION))
            put("exportedAt", JsonPrimitive(exportedAt))
            put("activeExamId", JsonPrimitive(activeId))
            put("tasks", buildJsonArray {
                snapshot.tasks.forEach { task ->
                    add(buildJsonObject {
                        put("id", JsonPrimitive(task.id))
                        put("title", JsonPrimitive(task.title))
                        put("subject", JsonPrimitive(task.subject))
                        put("done", JsonPrimitive(task.done))
                        putNullable("dueDate", task.dueDate)
                    })
                }
            })
            put("studySessions", buildJsonArray {
                snapshot.studySessions.forEach { session ->
                    add(buildJsonObject {
                        put("id", JsonPrimitive(session.id))
                        put("title", JsonPrimitive(session.title))
                        put("subject", JsonPrimitive(session.subject))
                        put("weekday", JsonPrimitive(session.weekday))
                        put("startMinutes", JsonPrimitive(session.startMinutes))
                        put("durationMinutes", JsonPrimitive(session.durationMinutes))
                        put("completed", JsonPrimitive(session.completed))
                        putNullable("scheduledDate", session.scheduledDate)
                    })
                }
            })
            put("exams", buildJsonArray {
                snapshot.exams.forEach { exam ->
                    add(buildJsonObject {
                        put("id", JsonPrimitive(exam.id))
                        put("name", JsonPrimitive(exam.name))
                        put("questionCount", JsonPrimitive(exam.questionCount))
                        put("durationSeconds", JsonPrimitive(exam.durationSeconds))
                        put("negativeMarking", JsonPrimitive(exam.negativeMarking))
                        put("isCompleted", JsonPrimitive(exam.isCompleted))
                        put("answers", exam.answers.toJsonObject())
                        put("answerKey", exam.answerKey.toJsonObject())
                        put("marked", buildJsonArray {
                            exam.marked.sorted().forEach { add(JsonPrimitive(it)) }
                        })
                    })
                }
            })
            put("results", buildJsonArray {
                snapshot.results.forEach { result ->
                    add(buildJsonObject {
                        put("id", JsonPrimitive(result.id))
                        putNullable("examId", result.examId)
                        put("examName", JsonPrimitive(result.examName))
                        put("completedAt", JsonPrimitive(result.completedAt))
                        put("questionCount", JsonPrimitive(result.questionCount))
                        put("correct", JsonPrimitive(result.correct))
                        put("wrong", JsonPrimitive(result.wrong))
                        put("unanswered", JsonPrimitive(result.unanswered))
                        put("keyedQuestions", JsonPrimitive(result.keyedQuestions))
                        put("percentage", result.percentage?.let(::JsonPrimitive) ?: JsonNull)
                        put("negativeMarking", JsonPrimitive(result.negativeMarking))
                        put("answers", result.answers.toJsonObject())
                        put("answerKey", result.answerKey.toJsonObject())
                    })
                }
            })
        }
        return json.encodeToString(JsonElement.serializer(), payload)
    }

    fun decode(raw: String): DarsYarSnapshot {
        val root = try {
            json.parseToJsonElement(raw).jsonObject
        } catch (exception: Exception) {
            throw BackupFormatException("Malformed backup JSON.", exception)
        }

        if (root["app"].stringValue("app") != APP_NAME ||
            root["schemaVersion"].intValue("schemaVersion") != SCHEMA_VERSION
        ) {
            throw BackupFormatException("Unsupported backup format or schema version.")
        }

        val tasks = root.requiredArray("tasks").mapIndexed { index, element ->
            val item = element.objectValue("tasks[$index]")
            StudyTask(
                id = item.requiredString("id", "tasks[$index]"),
                title = item.requiredString("title", "tasks[$index]"),
                subject = item.optionalString("subject", "tasks[$index]") ?: "عمومی",
                done = item.optionalBoolean("done", "tasks[$index]") ?: false,
                dueDate = item.optionalString("dueDate", "tasks[$index]").also {
                    validateDate(it, "tasks[$index].dueDate")
                },
            )
        }
        validateUniqueIds(tasks.map { it.id }, "tasks")

        val sessions = root.requiredArray("studySessions").mapIndexed { index, element ->
            val item = element.objectValue("studySessions[$index]")
            val weekday = item.optionalInt("weekday", "studySessions[$index]") ?: 0
            val start = item.optionalInt("startMinutes", "studySessions[$index]") ?: 960
            val duration = item.optionalInt("durationMinutes", "studySessions[$index]") ?: 55
            if (weekday !in 0..6) invalid("studySessions[$index].weekday")
            if (start !in 0 until 1440) invalid("studySessions[$index].startMinutes")
            if (duration < 1 || duration > 1440 - start) {
                invalid("studySessions[$index].durationMinutes")
            }
            val date = item.optionalString("scheduledDate", "studySessions[$index]")
            validateDate(date, "studySessions[$index].scheduledDate")
            StudySession(
                id = item.requiredString("id", "studySessions[$index]"),
                title = item.requiredString("title", "studySessions[$index]"),
                subject = item.optionalString("subject", "studySessions[$index]") ?: "عمومی",
                weekday = weekday,
                startMinutes = start,
                durationMinutes = duration,
                completed = item.optionalBoolean("completed", "studySessions[$index]") ?: false,
                scheduledDate = date,
            )
        }
        validateUniqueIds(sessions.map { it.id }, "studySessions")

        val exams = root.requiredArray("exams").mapIndexed { index, element ->
            val item = element.objectValue("exams[$index]")
            val count = item.optionalInt("questionCount", "exams[$index]") ?: 20
            val duration = item.optionalInt("durationSeconds", "exams[$index]") ?: 1800
            if (count !in 1..200) invalid("exams[$index].questionCount")
            if (duration !in 1..86400) invalid("exams[$index].durationSeconds")
            val answers = item.optionalQuestionMap("answers", count, "exams[$index]")
            val answerKey = item.optionalQuestionMap("answerKey", count, "exams[$index]")
            val marked = item.optionalQuestionSet("marked", count, "exams[$index]")
            ExamSheet(
                id = item.requiredString("id", "exams[$index]"),
                name = item.requiredString("name", "exams[$index]"),
                questionCount = count,
                durationSeconds = duration,
                negativeMarking = item.optionalBoolean("negativeMarking", "exams[$index]") ?: false,
                isCompleted = item.optionalBoolean("isCompleted", "exams[$index]") ?: false,
                answers = answers,
                answerKey = answerKey,
                marked = marked,
            )
        }
        if (exams.isEmpty()) throw BackupFormatException("Backup has no exam sheets.")
        validateUniqueIds(exams.map { it.id }, "exams")

        val results = root.requiredArray("results").mapIndexed { index, element ->
            val item = element.objectValue("results[$index]")
            val count = item.optionalInt("questionCount", "results[$index]") ?: 0
            val keyed = item.optionalInt("keyedQuestions", "results[$index]") ?: 0
            val correct = item.optionalInt("correct", "results[$index]") ?: 0
            val wrong = item.optionalInt("wrong", "results[$index]") ?: 0
            val unanswered = item.optionalInt("unanswered", "results[$index]") ?: 0
            if (count !in 0..200 || keyed !in 0..count ||
                correct !in 0..keyed || wrong !in 0..(keyed - correct) ||
                unanswered !in 0..count
            ) invalid("results[$index].score")
            val percentage = item.optionalDouble("percentage", "results[$index]")
            if (percentage != null && percentage !in 0.0..100.0) {
                invalid("results[$index].percentage")
            }
            ExamResult(
                id = item.optionalString("id", "results[$index]") ?: "legacy-result-$index",
                examId = item.optionalString("examId", "results[$index]"),
                examName = item.optionalString("examName", "results[$index]") ?: "آزمون",
                completedAt = item.optionalString("completedAt", "results[$index]") ?: "",
                questionCount = count,
                correct = correct,
                wrong = wrong,
                unanswered = unanswered,
                keyedQuestions = keyed,
                percentage = percentage,
                negativeMarking = item.optionalBoolean("negativeMarking", "results[$index]") ?: false,
                answers = item.optionalQuestionMap("answers", count, "results[$index]"),
                answerKey = item.optionalQuestionMap("answerKey", count, "results[$index]"),
            )
        }
        validateUniqueIds(results.map { it.id }, "results")

        val activeId = root.requiredString("activeExamId")
            .takeIf { requested -> exams.any { it.id == requested } }
            ?: exams.first().id

        return DarsYarSnapshot(
            tasks = tasks,
            studySessions = sessions,
            exams = exams,
            results = results,
            activeExamId = activeId,
        )
    }

    private fun JsonObject.requiredArray(key: String): JsonArray =
        this[key]?.let { element ->
            element as? JsonArray ?: invalid(key)
        } ?: invalid(key)

    private fun JsonElement?.intValue(field: String): Int {
        val primitive = this as? JsonPrimitive ?: invalid(field)
        if (primitive.isString) invalid(field)
        return primitive.intOrNull ?: invalid(field)
    }

    private fun JsonElement?.stringValue(field: String): String =
        this?.jsonPrimitive?.takeIf { it.isString }?.content ?: invalid(field)

    private fun JsonObject.requiredString(key: String, scope: String = ""): String =
        optionalString(key, scope)?.takeIf { it.isNotBlank() } ?: invalid("$scope.$key")

    private fun JsonObject.optionalString(key: String, scope: String): String? {
        val element = this[key] ?: return null
        if (element === JsonNull) return null
        val primitive = element as? JsonPrimitive ?: invalid("$scope.$key")
        if (!primitive.isString) invalid("$scope.$key")
        return primitive.content
    }

    private fun JsonObject.optionalBoolean(key: String, scope: String): Boolean? {
        val element = this[key] ?: return null
        if (element === JsonNull) return null
        return (element as? JsonPrimitive)?.booleanOrNull ?: invalid("$scope.$key")
    }

    private fun JsonObject.optionalInt(key: String, scope: String): Int? {
        val element = this[key] ?: return null
        if (element === JsonNull) return null
        return element.intValue("$scope.$key")
    }

    private fun JsonObject.optionalDouble(key: String, scope: String): Double? {
        val element = this[key] ?: return null
        if (element === JsonNull) return null
        val value = (element as? JsonPrimitive)?.doubleOrNull ?: invalid("$scope.$key")
        if (!value.isFinite()) invalid("$scope.$key")
        return value
    }

    private fun JsonObject.optionalQuestionMap(
        key: String,
        questionCount: Int,
        scope: String,
    ): Map<Int, Int> {
        val element = this[key] ?: return emptyMap()
        if (element === JsonNull) return emptyMap()
        val source = element as? JsonObject ?: invalid("$scope.$key")
        return buildMap {
            source.forEach { (rawQuestion, rawAnswer) ->
                val question = rawQuestion.toIntOrNull() ?: invalid("$scope.$key")
                val answer = rawAnswer.intValue("$scope.$key")
                if (question !in 1..questionCount || answer !in 0..3) {
                    invalid("$scope.$key")
                }
                put(question, answer)
            }
        }
    }

    private fun JsonObject.optionalQuestionSet(
        key: String,
        questionCount: Int,
        scope: String,
    ): Set<Int> {
        val element = this[key] ?: return emptySet()
        if (element === JsonNull) return emptySet()
        val source = element as? JsonArray ?: invalid("$scope.$key")
        return buildSet {
            source.forEach { raw ->
                val question = raw.intValue("$scope.$key")
                if (question !in 1..questionCount || !add(question)) invalid("$scope.$key")
            }
        }
    }

    private fun JsonObject.toJsonObject(): JsonObject = buildJsonObject {
        this@toJsonObject.toSortedMap().forEach { (question, answer) ->
            put(question.toString(), answer)
        }
    }

    private fun Map<Int, Int>.toJsonObject(): JsonObject = buildJsonObject {
        this@toJsonObject.toSortedMap().forEach { (question, answer) ->
            put(question.toString(), JsonPrimitive(answer))
        }
    }

    private fun JsonObjectBuilder.putNullable(key: String, value: String?) {
        if (value == null) {
            put(key, JsonNull)
        } else {
            put(key, JsonPrimitive(value))
        }
    }

    private fun validateUniqueIds(ids: List<String>, collection: String) {
        if (ids.any(String::isBlank) || ids.size != ids.toSet().size) {
            invalid("$collection IDs")
        }
    }

    private fun validateDate(value: String?, field: String) {
        if (value == null) return
        try {
            if (LocalDate.parse(value).toString() != value) invalid(field)
        } catch (exception: DateTimeParseException) {
            invalid(field)
        }
    }

    private fun invalid(field: String): Nothing =
        throw BackupFormatException("Invalid backup field: $field.")

    private fun JsonElement.objectValue(field: String): JsonObject =
        this as? JsonObject ?: invalid(field)
}

class BackupFormatException(
    message: String,
    cause: Throwable? = null,
) : IllegalArgumentException(message, cause)
