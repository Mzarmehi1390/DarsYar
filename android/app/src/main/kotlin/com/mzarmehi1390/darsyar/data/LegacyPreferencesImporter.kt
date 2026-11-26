package com.mzarmehi1390.darsyar.data

import android.content.Context
import androidx.room.withTransaction
import com.mzarmehi1390.darsyar.core.database.DarsYarDatabase
import com.mzarmehi1390.darsyar.core.database.entity.AppStateEntity
import com.mzarmehi1390.darsyar.core.database.entity.ExamResultEntity
import com.mzarmehi1390.darsyar.core.database.entity.ExamSheetEntity
import com.mzarmehi1390.darsyar.core.database.entity.StudySessionEntity
import com.mzarmehi1390.darsyar.core.database.entity.StudyTaskEntity
import dagger.hilt.android.qualifiers.ApplicationContext
import org.json.JSONArray
import org.json.JSONObject
import javax.inject.Inject
import javax.inject.Singleton

/**
 * One-time, non-destructive import from Flutter's legacy SharedPreferences file.
 *
 * Flutter's Android plugin stores keys in "FlutterSharedPreferences" with a
 * "flutter." prefix. The old store is deliberately read-only: a successful
 * import never removes or rewrites the source values. Missing or invalid result percentages are recalculated using the legacy scoring rule.
 */
@Singleton
class LegacyPreferencesImporter @Inject constructor(
    @ApplicationContext context: Context,
    private val database: DarsYarDatabase,
) : LegacyDataMigration {
    private val preferences = context.getSharedPreferences(
        LEGACY_PREFERENCES_FILE,
        Context.MODE_PRIVATE,
    )

    override suspend fun importIfNeeded(): LegacyImportOutcome = database.withTransaction {
        val current = database.appStateDao().get()
        if (current?.legacyImportCompleted == true) {
            return@withTransaction LegacyImportOutcome.ALREADY_IMPORTED
        }

        // Never merge legacy data into a database that already contains native
        // records. Marking the decision prevents a later launch from replacing
        // data created after this first check.
        val hasNativeData = database.studyTaskDao().count() > 0 ||
            database.studySessionDao().count() > 0 ||
            database.examSheetDao().count() > 0 ||
            database.examResultDao().count() > 0 ||
            current?.activeExamId != null
        if (hasNativeData) {
            database.appStateDao().upsert(
                AppStateEntity(
                    activeExamId = current?.activeExamId,
                    legacyImportCompleted = true,
                    updatedAtEpochMillis = System.currentTimeMillis(),
                ),
            )
            return@withTransaction LegacyImportOutcome.SKIPPED_NATIVE_DATA
        }

        val tasks = readCollection(TASKS_KEY, ::parseTask)
        val sessions = readCollection(SESSIONS_KEY, ::parseSession)
        val results = readCollection(RESULTS_KEY, ::parseResult)
        val examsKeyExists = preferences.contains(prefKey(EXAMS_KEY))
        val exams = if (examsKeyExists) {
            readCollection(EXAMS_KEY, ::parseExam)
        } else {
            listOf(parseLegacySingleExam())
        }.ifEmpty { listOf(defaultExam()) }

        val uniqueExams = exams.distinctBy { it.id }
        val safeExams = uniqueExams.ifEmpty { listOf(defaultExam()) }
        val requestedActiveId = readString(ACTIVE_EXAM_KEY)
        val activeExamId = requestedActiveId
            ?.takeIf { requested -> safeExams.any { it.id == requested } }
            ?: safeExams.first().id

        database.studyTaskDao().upsertAll(tasks)
        database.studySessionDao().upsertAll(sessions)
        database.examSheetDao().upsertAll(safeExams)
        database.examResultDao().upsertAll(results)

        database.appStateDao().upsert(
            AppStateEntity(
                activeExamId = activeExamId,
                legacyImportCompleted = true,
                updatedAtEpochMillis = System.currentTimeMillis(),
            ),
        )
        LegacyImportOutcome.IMPORTED
    }

    private fun prefKey(key: String) = FLUTTER_KEY_PREFIX + key

    private fun readString(key: String): String? {
        val fullKey = prefKey(key)
        if (!preferences.contains(fullKey)) return null
        return preferences.getString(fullKey, null)
            ?: throw IllegalStateException("Legacy preference '$key' is not a string.")
    }

    private fun readInt(key: String, fallback: Int): Int =
        runCatching { preferences.getInt(prefKey(key), fallback) }.getOrDefault(fallback)

    private fun <T : Any> readCollection(
        key: String,
        parser: (JSONObject, Int) -> T?,
    ): List<T> {
        val raw = readString(key) ?: return emptyList()
        val array = try {
            JSONArray(raw)
        } catch (exception: Exception) {
            throw IllegalStateException("Unable to parse legacy collection '$key'.", exception)
        }
        val parsed = ArrayList<T>(array.length())
        val seenIds = mutableSetOf<String>()
        // Flutter's backup/import model retains historical results even when old
        // records have missing or colliding IDs. Room requires unique primary
        // keys, so reserve explicit IDs up front and normalize only result IDs.
        val reservedResultIds = if (key == RESULTS_KEY) {
            (0 until array.length()).mapNotNull { index ->
                (array.optJSONObject(index)?.opt("id") as? String)?.takeIf(String::isNotBlank)
            }.toSet()
        } else {
            emptySet()
        }
        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index)
                ?: throw IllegalStateException(
                    "Legacy collection '$key' contains a non-object item at index $index.",
                )
            val parsedValue = try {
                parser(item, index)
            } catch (exception: Exception) {
                throw IllegalStateException(
                    "Unable to import item $index from legacy collection '$key'.",
                    exception,
                )
            } ?: throw IllegalStateException(
                "Legacy collection '$key' contains an invalid item at index $index.",
            )
            val value: T = if (parsedValue is ExamResultEntity) {
                val rawId = (item.opt("id") as? String)?.takeIf(String::isNotBlank)
                val needsGeneratedId = parsedValue.id in seenIds ||
                    (rawId == null && parsedValue.id in reservedResultIds)
                if (needsGeneratedId) {
                    parsedValue.copy(
                        id = generateUniqueLegacyResultId(index, reservedResultIds, seenIds),
                    ) as T
                } else {
                    parsedValue
                }
            } else {
                parsedValue
            }
            val id = when (value) {
                is StudyTaskEntity -> value.id
                is StudySessionEntity -> value.id
                is ExamSheetEntity -> value.id
                is ExamResultEntity -> value.id
                else -> null
            }
            if (id != null && !seenIds.add(id)) {
                throw IllegalStateException(
                    "Legacy collection '$key' contains duplicate identifier '$id'.",
                )
            }
            parsed += value
        }
        return parsed
    }

    private fun generateUniqueLegacyResultId(
        index: Int,
        reservedIds: Set<String>,
        assignedIds: Set<String>,
    ): String {
        val base = "legacy-result-$index"
        var candidate = base
        var suffix = 1
        while (candidate in reservedIds || candidate in assignedIds) {
            candidate = "$base-$suffix"
            suffix++
        }
        return candidate
    }

    private fun parseTask(json: JSONObject, index: Int): StudyTaskEntity? {
        val id = json.stringOrNull("id")?.takeIf(String::isNotBlank) ?: return null
        val title = json.stringOrNull("title")?.takeIf(String::isNotBlank) ?: return null
        return StudyTaskEntity(
            id = id,
            title = title,
            subject = json.stringOrNull("subject") ?: "عمومی",
            isDone = json.booleanOrDefault("done", false),
            dueDate = json.stringIfString("dueDate")?.let(::parseDateOnly),
        )
    }

    private fun parseSession(json: JSONObject, index: Int): StudySessionEntity? {
        val id = json.stringOrNull("id")?.takeIf(String::isNotBlank) ?: return null
        val title = json.stringOrNull("title")?.takeIf(String::isNotBlank) ?: return null
        val start = json.intFromNumber("startMinutes", 960).coerceIn(0, 1439)
        val duration = json.intFromNumber("durationMinutes", 55).coerceIn(1, 1440 - start)
        val date = json.stringIfString("scheduledDate")?.let(::parseDateOnly)
        val weekday = if (date != null) {
            runCatching {
                val parts = date.split("-").map(String::toInt)
                java.time.LocalDate.of(parts[0], parts[1], parts[2]).dayOfWeek.value % 7
            }.getOrDefault(json.intFromNumber("weekday", 0).coerceIn(0, 6))
        } else {
            json.intFromNumber("weekday", 0).coerceIn(0, 6)
        }
        return StudySessionEntity(
            id = id,
            title = title,
            subject = json.stringOrNull("subject") ?: "عمومی",
            weekday = weekday,
            startMinutes = start,
            durationMinutes = duration,
            completed = json.booleanOrDefault("completed", false),
            scheduledDate = date,
        )
    }

    private fun parseExam(json: JSONObject, index: Int): ExamSheetEntity? {
        // Match ExamSheet.fromJson: nullable/missing IDs and names use defaults;
        // empty strings remain valid strings rather than being silently rewritten.
        val id = json.stringOrNull("id") ?: "default"
        val name = json.stringOrNull("name") ?: "آزمون"
        val count = json.intFromNumber("questionCount", 20).coerceIn(1, 200)
        return ExamSheetEntity(
            id = id,
            name = name,
            questionCount = count,
            durationSeconds = json.intFromNumber("durationSeconds", 1800).coerceIn(1, 86400),
            negativeMarking = json.opt("negativeMarking") == true,
            isCompleted = json.opt("isCompleted") == true,
            answersJson = filteredAnswers(json.optJSONObject("answers"), count).toJson(),
            answerKeyJson = filteredAnswers(json.optJSONObject("answerKey"), count).toJson(),
            markedJson = filteredMarked(json.optJSONArray("marked"), count).toJson(),
        )
    }

    private fun parseLegacySingleExam(): ExamSheetEntity {
        val count = readInt("darsyar.count", 20).coerceIn(1, 200)
        val answers = readJsonObject("darsyar.answers")
        val answerKey = readJsonObject("darsyar.answerKey")
        val marked = readJsonArray("darsyar.marked")
        return ExamSheetEntity(
            id = "default",
            name = "آزمون اول",
            questionCount = count,
            durationSeconds = 1800,
            negativeMarking = false,
            isCompleted = false,
            answersJson = filteredAnswers(answers, count).toJson(),
            answerKeyJson = filteredAnswers(answerKey, count).toJson(),
            markedJson = filteredMarked(marked, count).toJson(),
        )
    }

    private fun defaultExam() = ExamSheetEntity(
        id = "default",
        name = "آزمون اول",
        questionCount = 20,
        durationSeconds = 1800,
        negativeMarking = false,
        isCompleted = false,
        answersJson = "{}",
        answerKeyJson = "{}",
        markedJson = "[]",
    )

    private fun parseResult(json: JSONObject, index: Int): ExamResultEntity? {
        val rawId = (json.opt("id") as? String)?.takeIf(String::isNotBlank)
        val id = rawId ?: "legacy-result-$index"
        val questionCount = json.intFromNumber("questionCount", 0).coerceIn(0, 200)
        val keyed = json.intFromNumber("keyedQuestions", 0).coerceIn(0, questionCount)
        val correct = json.intFromNumber("correct", 0).coerceIn(0, keyed)
        val wrong = json.intFromNumber("wrong", 0).coerceIn(0, keyed - correct)
        val negativeMarking = json.opt("negativeMarking") == true
        // Match Dart's ExamResult.fromJson: numeric values are clamped,
        // while missing, null, non-numeric and non-finite values are recalculated.
        val storedPercentage = (json.opt("percentage") as? Number)
            ?.toDouble()
            ?.takeIf(Double::isFinite)
            ?.coerceIn(0.0, 100.0)
        // Match the legacy Dart model: preserve a valid stored percentage,
        // otherwise recalculate it from the keyed-question score.
        val rawPercentage = storedPercentage ?: if (keyed == 0) {
            null
        } else {
            ((correct - if (negativeMarking) wrong / 3.0 else 0.0) *
                100.0 / keyed).coerceIn(0.0, 100.0)
        }
        return ExamResultEntity(
            id = id,
            examId = json.opt("examId") as? String,
            examName = (json.opt("examName") as? String)?.takeIf(String::isNotBlank) ?: "آزمون",
            completedAt = json.opt("completedAt") as? String ?: "",
            questionCount = questionCount,
            correct = correct,
            wrong = wrong,
            unanswered = json.intFromNumber("unanswered", 0).coerceIn(0, questionCount),
            keyedQuestions = keyed,
            percentage = rawPercentage,
            negativeMarking = negativeMarking,
            answersJson = filteredAnswers(json.optJSONObject("answers"), questionCount).toJson(),
            answerKeyJson = filteredAnswers(json.optJSONObject("answerKey"), questionCount).toJson(),
        )
    }

    private fun readJsonObject(key: String) = readString(key)?.let { raw ->
        try {
            JSONObject(raw)
        } catch (exception: Exception) {
            throw IllegalStateException("Unable to parse legacy object '$key'.", exception)
        }
    }

    private fun readJsonArray(key: String) = readString(key)?.let { raw ->
        try {
            JSONArray(raw)
        } catch (exception: Exception) {
            throw IllegalStateException("Unable to parse legacy array '$key'.", exception)
        }
    }

    private fun filteredAnswers(source: JSONObject?, questionCount: Int): Map<Int, Int> {
        if (source == null) return emptyMap()
        val result = linkedMapOf<Int, Int>()
        val keys = source.keys()
        while (keys.hasNext()) {
            val rawQuestion = keys.next()
            val question = rawQuestion.toIntOrNull() ?: continue
            val answer = (source.opt(rawQuestion) as? Number)?.toInt() ?: -1
            if (question in 1..questionCount && answer in 0..3) result[question] = answer
        }
        return result
    }

    private fun filteredMarked(source: JSONArray?, questionCount: Int): Set<Int> {
        if (source == null) return emptySet()
        return buildSet {
            for (index in 0 until source.length()) {
                val question = (source.opt(index) as? Number)?.toInt() ?: -1
                if (question in 1..questionCount) add(question)
            }
        }
    }

    private fun Map<Int, Int>.toJson() = JSONObject().apply {
        for ((question, answer) in this@toJson) put(question.toString(), answer)
    }.toString()

    private fun Set<Int>.toJson() = JSONArray().apply {
        sorted().forEach { put(it) }
    }.toString()

    /** Dart's num? casts reject numeric strings but accept JSON numbers. */
    private fun JSONObject.intFromNumber(key: String, fallback: Int): Int =
        (opt(key) as? Number)?.toInt() ?: fallback

    /** Mirrors nullable bool casts used by task/session models. */
    private fun JSONObject.booleanOrDefault(key: String, fallback: Boolean): Boolean {
        if (!has(key) || isNull(key)) return fallback
        return opt(key) as? Boolean
            ?: throw IllegalStateException("Legacy field '$key' must be a boolean.")
    }

    private fun JSONObject.stringOrNull(key: String): String? {
        if (!has(key) || isNull(key)) return null
        return opt(key) as? String
            ?: throw IllegalStateException("Legacy field '$key' must be a string.")
    }

    /** Mirrors Dart fields that intentionally ignore non-string optional values. */
    private fun JSONObject.stringIfString(key: String): String? = opt(key) as? String

    /**
     * Mirrors DateTime.tryParse followed by dateOnly in the Flutter models.
     * ISO timestamps are accepted as well as date-only values; offset timestamps
     * are normalized to UTC before extracting the calendar date, as Dart does.
     */
    private fun parseDateOnly(value: String): String? {
        // Dart DateTime.tryParse accepts a space separator, lowercase z and
        // numeric offsets both with and without the colon (for example +02:00
        // and +0200). Normalize those spellings before using java.time.
        val normalized = value.trim()
            .replace(' ', 'T')
            .replace(Regex("([+-]\\d{2})(\\d{2})$")) { match ->
                "${match.groupValues[1]}:${match.groupValues[2]}"
            }
            .let { if (it.endsWith('z')) it.dropLast(1) + "Z" else it }
        val date = runCatching {
            java.time.OffsetDateTime.parse(normalized)
                .withOffsetSameInstant(java.time.ZoneOffset.UTC)
                .toLocalDate()
        }.getOrNull()
            ?: runCatching { java.time.LocalDateTime.parse(normalized).toLocalDate() }.getOrNull()
            ?: runCatching { java.time.LocalDate.parse(value) }.getOrNull()
            ?: runCatching {
                java.time.LocalDate.parse(value, java.time.format.DateTimeFormatter.BASIC_ISO_DATE)
            }.getOrNull()
            ?: return null
        return date.toString()
    }

    companion object {
        const val LEGACY_PREFERENCES_FILE = "FlutterSharedPreferences"
        const val FLUTTER_KEY_PREFIX = "flutter."
        private const val TASKS_KEY = "darsyar.tasks"
        private const val SESSIONS_KEY = "darsyar.studySessions"
        private const val RESULTS_KEY = "darsyar.results"
        private const val EXAMS_KEY = "darsyar.exams"
        private const val ACTIVE_EXAM_KEY = "darsyar.activeExamId"
    }
}

enum class LegacyImportOutcome {
    IMPORTED,
    ALREADY_IMPORTED,
    SKIPPED_NATIVE_DATA,
}
