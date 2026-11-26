package com.mzarmehi1390.darsyar.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.mzarmehi1390.darsyar.core.database.DarsYarDatabase
import com.mzarmehi1390.darsyar.core.database.entity.StudyTaskEntity
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class LegacyPreferencesImporterTest {
    private lateinit var database: DarsYarDatabase
    private lateinit var preferences: android.content.SharedPreferences
    private lateinit var importer: LegacyPreferencesImporter

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        preferences = context.getSharedPreferences(
            LegacyPreferencesImporter.LEGACY_PREFERENCES_FILE,
            Context.MODE_PRIVATE,
        )
        preferences.edit().clear().commit()
        database = Room.inMemoryDatabaseBuilder(
            context,
            DarsYarDatabase::class.java,
        ).allowMainThreadQueries().build()
        importer = LegacyPreferencesImporter(context, database)
    }

    @After
    fun tearDown() {
        preferences.edit().clear().commit()
        database.close()
    }

    @Test
    fun importsAllCurrentCollectionsAndPreservesLegacySource() = runBlocking {
        preferences.edit()
            .putString(
                "flutter.darsyar.tasks",
                """[{"id":"task-1","title":"مرور ریاضی","subject":"ریاضی","done":true,"dueDate":"2026-11-24"}]""",
            )
            .putString(
                "flutter.darsyar.studySessions",
                """[{"id":"session-1","title":"فیزیک","subject":"فیزیک","weekday":1,"startMinutes":600,"durationMinutes":55,"completed":false,"scheduledDate":"2026-11-23"}]""",
            )
            .putString(
                "flutter.darsyar.exams",
                """[{"id":"exam-1","name":"آزمون اول","questionCount":2,"durationSeconds":1800,"answers":{"1":2},"answerKey":{"1":2,"2":0},"marked":[2]}]""",
            )
            .putString(
                "flutter.darsyar.results",
                """[{"id":"result-1","examId":"exam-1","examName":"آزمون اول","completedAt":"2026-11-23T10:00:00Z","questionCount":2,"correct":1,"wrong":0,"unanswered":1,"keyedQuestions":2,"percentage":50.0,"answers":{"1":2},"answerKey":{"1":2,"2":0}}]""",
            )
            .putString("flutter.darsyar.activeExamId", "exam-1")
            .commit()

        assertEquals(LegacyImportOutcome.IMPORTED, importer.importIfNeeded())
        assertEquals(1, database.studyTaskDao().count())
        assertEquals(1, database.studySessionDao().count())
        assertEquals(1, database.examSheetDao().count())
        assertEquals(1, database.examResultDao().getAll().size)

        val task = database.studyTaskDao().findById("task-1")
        assertEquals("مرور ریاضی", task?.title)
        assertEquals("2026-11-24", task?.dueDate)

        val session = database.studySessionDao().findById("session-1")
        assertEquals("2026-11-23", session?.scheduledDate)
        assertEquals(1, session?.weekday)

        val exam = database.examSheetDao().findById("exam-1")
        assertEquals("{\"1\":2,\"2\":0}", exam?.answerKeyJson)
        assertEquals("[2]", exam?.markedJson)
        assertEquals("exam-1", database.appStateDao().get()?.activeExamId)

        // Import must be read-only with respect to the Flutter source file.
        assertTrue(preferences.contains("flutter.darsyar.tasks"))
        assertEquals(
            LegacyImportOutcome.ALREADY_IMPORTED,
            importer.importIfNeeded(),
        )
    }

    @Test
    fun malformedLegacyCollectionDoesNotCompleteImportAndCanBeRetried() = runBlocking {
        preferences.edit()
            .putString("flutter.darsyar.tasks", """[{invalid-json]""")
            .commit()

        try {
            importer.importIfNeeded()
            throw AssertionError("Malformed legacy JSON must fail the import.")
        } catch (expected: IllegalStateException) {
            assertTrue(expected.message.orEmpty().contains("darsyar.tasks"))
        }

        assertEquals(null, database.appStateDao().get())
        assertEquals(0, database.studyTaskDao().count())

        preferences.edit()
            .putString(
                "flutter.darsyar.tasks",
                """[{"id":"recovered-task","title":"Recovered task"}]""",
            )
            .commit()

        assertEquals(LegacyImportOutcome.IMPORTED, importer.importIfNeeded())
        assertEquals("Recovered task", database.studyTaskDao().findById("recovered-task")?.title)
        assertTrue(database.appStateDao().get()?.legacyImportCompleted == true)
    }

    @Test
    fun malformedLegacySingleExamPayloadRollsBackAndCanBeRetried() = runBlocking {
        preferences.edit()
            .putInt("flutter.darsyar.count", 3)
            .putString("flutter.darsyar.answers", """{"1":1""")
            .putString("flutter.darsyar.answerKey", """{"1":1}""")
            .commit()

        try {
            importer.importIfNeeded()
            throw AssertionError("Malformed legacy exam answers must fail the import.")
        } catch (expected: IllegalStateException) {
            assertTrue(expected.message.orEmpty().contains("darsyar.answers"))
        }

        assertEquals(null, database.appStateDao().get())
        assertEquals(0, database.examSheetDao().count())

        preferences.edit()
            .putString("flutter.darsyar.answers", """{"1":1,"2":0}""")
            .commit()

        assertEquals(LegacyImportOutcome.IMPORTED, importer.importIfNeeded())
        assertEquals("""{"1":1,"2":0}""", database.examSheetDao().findById("default")?.answersJson)
        assertTrue(database.appStateDao().get()?.legacyImportCompleted == true)
    }

    @Test
    fun importsLegacySingleSheetWhenMultiSheetKeyWasNeverCreated() = runBlocking {
        preferences.edit()
            .putInt("flutter.darsyar.count", 3)
            .putString("flutter.darsyar.answers", """{"1":1,"3":2}""")
            .putString("flutter.darsyar.answerKey", """{"1":1,"2":0}""")
            .putString("flutter.darsyar.marked", """[2,3]""")
            .commit()

        assertEquals(LegacyImportOutcome.IMPORTED, importer.importIfNeeded())
        val sheet = database.examSheetDao().findById("default")
        assertEquals(3, sheet?.questionCount)
        assertEquals("{\"1\":1,\"2\":0}", sheet?.answerKeyJson)
        assertEquals("{\"1\":1,\"3\":2}", sheet?.answersJson)
        assertEquals("[2,3]", sheet?.markedJson)
    }

    @Test
    fun invalidRecordAfterValidRecordRollsBackEntireImportAndCanBeRetried() = runBlocking {
        preferences.edit()
            .putString(
                "flutter.darsyar.tasks",
                """[{"id":"valid-task","title":"Valid task"},{"id":"invalid-task"}]""",
            )
            .commit()

        try {
            importer.importIfNeeded()
            throw AssertionError("An invalid record must fail the entire import.")
        } catch (expected: IllegalStateException) {
            assertTrue(expected.message.orEmpty().contains("index 1"))
        }

        assertEquals(0, database.studyTaskDao().count())
        assertEquals(null, database.appStateDao().get())

        preferences.edit()
            .putString(
                "flutter.darsyar.tasks",
                """[{"id":"valid-task","title":"Valid task"},{"id":"repaired-task","title":"Repaired task"}]""",
            )
            .commit()

        assertEquals(LegacyImportOutcome.IMPORTED, importer.importIfNeeded())
        assertEquals(2, database.studyTaskDao().count())
        assertTrue(database.appStateDao().get()?.legacyImportCompleted == true)
    }

    @Test
    fun duplicateLegacyIdentifiersRejectImportWithoutDroppingRecords() = runBlocking {
        preferences.edit()
            .putString(
                "flutter.darsyar.tasks",
                """[{"id":"duplicate","title":"First"},{"id":"duplicate","title":"Second"}]""",
            )
            .commit()

        try {
            importer.importIfNeeded()
            throw AssertionError("Duplicate identifiers must fail the import.")
        } catch (expected: IllegalStateException) {
            assertTrue(expected.message.orEmpty().contains("duplicate"))
        }

        assertEquals(0, database.studyTaskDao().count())
        assertEquals(null, database.appStateDao().get())
    }


    @Test
    fun importsEveryHistoricalResultAndNormalizesOnlyCollidingLegacyIds() = runBlocking {
        preferences.edit()
            .putString(
                "flutter.darsyar.results",
                """[
                    {"id":"duplicate","examName":"نتیجهٔ اول"},
                    {"id":"duplicate","examName":"نتیجهٔ دوم"},
                    {"id":"legacy-result-1","examName":"شناسهٔ رزروشده"},
                    {"examName":"بدون شناسه"}
                ]""".trimIndent(),
            )
            .commit()

        assertEquals(LegacyImportOutcome.IMPORTED, importer.importIfNeeded())
        val results = database.examResultDao().getAll()
        assertEquals(4, results.size)
        assertEquals(4, results.map { it.id }.toSet().size)
        assertEquals(
            setOf("نتیجهٔ اول", "نتیجهٔ دوم", "شناسهٔ رزروشده", "بدون شناسه"),
            results.map { it.examName }.toSet(),
        )
        assertEquals("duplicate", results.single { it.examName == "نتیجهٔ اول" }.id)
        assertEquals("legacy-result-1-1", results.single { it.examName == "نتیجهٔ دوم" }.id)
        assertEquals("legacy-result-1", results.single { it.examName == "شناسهٔ رزروشده" }.id)
        assertEquals("legacy-result-3", results.single { it.examName == "بدون شناسه" }.id)
    }

    @Test
    fun reservesEveryExplicitResultIdBeforeGeneratingMissingAndBlankIds() = runBlocking {
        preferences.edit()
            .putString(
                "flutter.darsyar.results",
                """[
                    {"examName":"شناسهٔ خالی اول"},
                    {"id":"","examName":"شناسهٔ خالی دوم"},
                    {"id":"duplicate","examName":"شناسهٔ تکراری اول"},
                    {"id":"duplicate","examName":"شناسهٔ تکراری دوم"},
                    {"id":"legacy-result-0","examName":"رزرو صفر"},
                    {"id":"legacy-result-1","examName":"رزرو یک"}
                ]""".trimIndent(),
            )
            .commit()

        assertEquals(LegacyImportOutcome.IMPORTED, importer.importIfNeeded())
        val results = database.examResultDao().getAll().associateBy { it.examName }

        assertEquals(6, results.size)
        assertEquals(6, results.values.map { it.id }.toSet().size)
        assertEquals("legacy-result-0-1", results["شناسهٔ خالی اول"]?.id)
        assertEquals("legacy-result-1-1", results["شناسهٔ خالی دوم"]?.id)
        assertEquals("duplicate", results["شناسهٔ تکراری اول"]?.id)
        assertEquals("legacy-result-3", results["شناسهٔ تکراری دوم"]?.id)
        assertEquals("legacy-result-0", results["رزرو صفر"]?.id)
        assertEquals("legacy-result-1", results["رزرو یک"]?.id)
    }

    @Test
    fun skipsImportWhenNativeDataAlreadyExists() = runBlocking {
        database.studyTaskDao().upsertAll(
            listOf(
                StudyTaskEntity(
                    id = "native-task",
                    title = "Native",
                    subject = "ریاضی",
                    isDone = false,
                    dueDate = null,
                ),
            ),
        )
        preferences.edit()
            .putString(
                "flutter.darsyar.tasks",
                """[{"id":"legacy-task","title":"Legacy"}]""",
            )
            .commit()

        assertEquals(
            LegacyImportOutcome.SKIPPED_NATIVE_DATA,
            importer.importIfNeeded(),
        )
        assertEquals(1, database.studyTaskDao().count())
        assertEquals(null, database.studyTaskDao().findById("legacy-task"))
        assertTrue(database.appStateDao().get()?.legacyImportCompleted == true)
    }
    @Test
    fun recalculatesPercentageWhenLegacyValueIsMissingOrInvalid() = runBlocking {
        preferences.edit()
            .putString(
                "flutter.darsyar.results",
                """[{"id":"missing-percentage","questionCount":3,"keyedQuestions":3,"correct":2,"wrong":1,"unanswered":0},{"id":"invalid-percentage","questionCount":3,"keyedQuestions":3,"correct":2,"wrong":1,"unanswered":0,"percentage":"invalid","negativeMarking":true}]""",
            )
            .commit()

        assertEquals(LegacyImportOutcome.IMPORTED, importer.importIfNeeded())
        val results = database.examResultDao().getAll().associateBy { it.id }
        assertEquals(200.0 / 3.0, results["missing-percentage"]?.percentage!!, 0.0001)
        assertEquals(500.0 / 9.0, results["invalid-percentage"]?.percentage!!, 0.0001)
    }

}
