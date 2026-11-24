package com.mzarmehi1390.darsyar.di

import com.mzarmehi1390.darsyar.data.DarsYarRepository
import com.mzarmehi1390.darsyar.data.AppBackupSettingsGateway
import com.mzarmehi1390.darsyar.features.settings.presentation.BackupSettingsGateway
import com.mzarmehi1390.darsyar.features.exams.domain.ExamRepository
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class FeatureRepositoryModule {
    @Binds
    @Singleton
    abstract fun bindPlannerRepository(repository: DarsYarRepository): PlannerRepository

    @Binds
    @Singleton
    abstract fun bindExamRepository(repository: DarsYarRepository): ExamRepository

    @Binds
    @Singleton
    abstract fun bindBackupSettingsGateway(gateway: AppBackupSettingsGateway): BackupSettingsGateway
}
