package com.mzarmehi1390.darsyar.data

/** Boundary for the one-time migration required before the native UI is exposed. */
interface LegacyDataMigration {
    suspend fun importIfNeeded(): LegacyImportOutcome
}
