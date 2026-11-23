package com.mzarmehi1390.darsyar.di

import com.mzarmehi1390.darsyar.data.LegacyDataMigration
import com.mzarmehi1390.darsyar.data.LegacyPreferencesImporter
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class MigrationModule {
    @Binds
    @Singleton
    abstract fun bindLegacyDataMigration(
        importer: LegacyPreferencesImporter,
    ): LegacyDataMigration
}
