package com.mzarmehi1390.darsyar.features.settings.presentation

import java.io.InputStream

data class BackupSettingsSummary(
    val taskCount: Int,
    val studySessionCount: Int,
    val examCount: Int,
    val resultCount: Int,
)

data class ValidatedBackup(
    val json: String,
    val summary: BackupSettingsSummary,
)

/** Boundary between the settings feature and the app's backup implementation. */
interface BackupSettingsGateway {
    suspend fun exportBackup(): String
    suspend fun readAndValidateBackup(input: InputStream): ValidatedBackup
    suspend fun restoreBackup(json: String)
}
