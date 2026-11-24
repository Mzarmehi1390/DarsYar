package com.mzarmehi1390.darsyar.data

import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Coordinates portable backup creation and restoration.
 *
 * Validation is intentionally separate from restoration so the UI can inspect
 * a selected file and ask for confirmation before replacing local data.
 */
@Singleton
class DarsYarBackupService @Inject constructor(
    private val repository: DarsYarRepository,
) {
    suspend fun exportBackup(): String {
        val snapshot = repository.createBackupSnapshot()
        return DarsYarBackupCodec.encode(
            snapshot = snapshot,
            exportedAt = Instant.now().toString(),
        )
    }

    fun validateBackup(raw: String): DarsYarBackupSummary {
        val snapshot = DarsYarBackupCodec.decode(raw)
        return DarsYarBackupSummary(
            taskCount = snapshot.tasks.size,
            studySessionCount = snapshot.studySessions.size,
            examCount = snapshot.exams.size,
            resultCount = snapshot.results.size,
        )
    }

    suspend fun restoreBackup(raw: String) {
        // Decode and validate the complete document before the transaction
        // starts; malformed input can never partially replace existing data.
        val snapshot = DarsYarBackupCodec.decode(raw)
        repository.replaceAll(snapshot)
    }
}

data class DarsYarBackupSummary(
    val taskCount: Int,
    val studySessionCount: Int,
    val examCount: Int,
    val resultCount: Int,
)
