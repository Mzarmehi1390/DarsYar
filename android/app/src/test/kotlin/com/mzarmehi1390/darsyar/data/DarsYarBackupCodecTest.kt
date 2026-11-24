package com.mzarmehi1390.darsyar.data

import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class DarsYarBackupCodecTest {
    @Test
    fun roundTrip_preservesAllPortableCollectionsAndActiveExam() {
        val snapshot = DarsYarSnapshot(
            tasks = listOf(StudyTask("task-1", "مرور ریاضی", "ریاضی", true, "2026-11-25")),
            studySessions = listOf(
                StudySession("session-1", "فیزیک", "فیزیک", 2, 600, 45, true, "2026-11-24"),
                StudySession("session-legacy", "مرور", "عمومی", 4, 960, 55),
            ),
            exams = listOf(
                ExamSheet(
                    id = "exam-1",
                    name = "آزمون اول",
                    questionCount = 3,
                    durationSeconds = 900,
                    negativeMarking = true,
                    isCompleted = true,
                    answers = mapOf(1 to 2, 3 to 0),
                    answerKey = mapOf(1 to 2, 2 to 1),
                    marked = setOf(2, 3),
                ),
            ),
            results = listOf(
                ExamResult(
                    id = "result-1",
                    examId = "exam-1",
                    examName = "آزمون اول",
                    completedAt = "2026-11-23T12:00:00Z",
                    questionCount = 3,
                    correct = 1,
                    wrong = 1,
                    unanswered = 1,
                    keyedQuestions = 2,
                    percentage = 33.333,
                    negativeMarking = true,
                    answers = mapOf(1 to 2, 2 to 0),
                    answerKey = mapOf(1 to 2, 2 to 1),
                ),
            ),
            activeExamId = "exam-1",
        )

        val encoded = DarsYarBackupCodec.encode(snapshot, "2026-11-24T12:00:00Z")
        val restored = DarsYarBackupCodec.decode(encoded)

        assertEquals(snapshot, restored)
    }

    @Test
    fun decode_rejectsMalformedJsonAndUnsupportedVersions() {
        assertThrows(BackupFormatException::class.java) {
            DarsYarBackupCodec.decode("{broken")
        }
        assertThrows(BackupFormatException::class.java) {
            DarsYarBackupCodec.decode("""{"app":"DarsYar","schemaVersion":99}""")
        }
    }

    @Test
    fun decode_rejectsDuplicateIdsAndInvalidExamAnswers() {
        val duplicateIds = validBackup().replace(
            """"tasks": []""",
            """"tasks": [{"id":"t","title":"A"},{"id":"t","title":"B"}]""",
        )
        assertThrows(BackupFormatException::class.java) {
            DarsYarBackupCodec.decode(duplicateIds)
        }

        val invalidAnswer = validBackup().replace(
            """"answers": {}""",
            """"answers": {"1": 4}""",
        )
        assertThrows(BackupFormatException::class.java) {
            DarsYarBackupCodec.decode(invalidAnswer)
        }
    }

    @Test
    fun decode_rejectsInvalidDatesAndSessionRanges() {
        val invalidDate = validBackup().replace(
            """"dueDate": null""",
            """"dueDate": "2026-02-30"""",
        )
        assertThrows(BackupFormatException::class.java) {
            DarsYarBackupCodec.decode(invalidDate)
        }

        val invalidSession = validBackup().replace(
            """"studySessions": []""",
            """"studySessions": [{"id":"s","title":"S","weekday":7}]""",
        )
        assertThrows(BackupFormatException::class.java) {
            DarsYarBackupCodec.decode(invalidSession)
        }
    }

    @Test
    fun decode_fallsBackToFirstExamWhenActiveIdIsStale() {
        val restored = DarsYarBackupCodec.decode(
            validBackup().replace(""""activeExamId": "exam-1"""", """"activeExamId": "missing""""),
        )
        assertEquals("exam-1", restored.activeExamId)
        assertTrue(restored.exams.isNotEmpty())
    }

    @Test
    fun decode_rejectsNonNumericSchemaVersion() {
        val invalidVersion = validBackup().replace(
            """\"schemaVersion\": 1""",
            """\"schemaVersion\": "1"""",
        )
        assertThrows(BackupFormatException::class.java) {
            DarsYarBackupCodec.decode(invalidVersion)
        }
    }

    private fun validBackup() = """
        {
          "app": "DarsYar",
          "schemaVersion": 1,
          "exportedAt": "2026-11-24T12:00:00Z",
          "activeExamId": "exam-1",
          "tasks": [],
          "studySessions": [],
          "exams": [{
            "id": "exam-1",
            "name": "آزمون",
            "questionCount": 2,
            "durationSeconds": 600,
            "answers": {},
            "answerKey": {},
            "marked": []
          }],
          "results": []
        }
    """.trimIndent()
}
