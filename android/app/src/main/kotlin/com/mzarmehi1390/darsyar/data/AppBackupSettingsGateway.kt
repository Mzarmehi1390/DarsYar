package com.mzarmehi1390.darsyar.data

import com.mzarmehi1390.darsyar.features.settings.presentation.BackupSettingsGateway
import com.mzarmehi1390.darsyar.features.settings.presentation.BackupSettingsSummary
import com.mzarmehi1390.darsyar.features.settings.presentation.ValidatedBackup
import java.io.InputStream
import javax.inject.Inject

class AppBackupSettingsGateway @Inject constructor(
    private val backupService: DarsYarBackupService,
) : BackupSettingsGateway {
    override suspend fun exportBackup(): String = backupService.exportBackup()

    override suspend fun readAndValidateBackup(input: InputStream): ValidatedBackup {
        val json = DarsYarBackupFileReader.read(input)
        val summary = backupService.validateBackup(json)
        return ValidatedBackup(
            json = json,
            summary = BackupSettingsSummary(
                taskCount = summary.taskCount,
                studySessionCount = summary.studySessionCount,
                examCount = summary.examCount,
                resultCount = summary.resultCount,
            ),
        )
    }

    override suspend fun restoreBackup(json: String) {
        backupService.restoreBackup(json)
    }
}
