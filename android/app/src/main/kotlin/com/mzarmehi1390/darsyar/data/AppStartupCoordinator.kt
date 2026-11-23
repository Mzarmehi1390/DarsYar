package com.mzarmehi1390.darsyar.data

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import javax.inject.Inject
import javax.inject.Singleton

sealed interface AppStartupState {
    data object NotStarted : AppStartupState
    data object Migrating : AppStartupState
    data object Ready : AppStartupState
    data class Failed(val message: String?) : AppStartupState
}

/**
 * Serializes startup migration across Activity recreation and concurrent callers.
 * Cancellation is not treated as a migration failure: Room can roll back its
 * transaction and a later launch can safely retry.
 */
@Singleton
class AppStartupCoordinator @Inject constructor(
    private val migration: LegacyDataMigration,
) {
    private val mutex = Mutex()
    private val mutableState = MutableStateFlow<AppStartupState>(AppStartupState.NotStarted)

    val state: StateFlow<AppStartupState> = mutableState.asStateFlow()

    suspend fun ensureReady() {
        mutex.withLock {
            if (mutableState.value == AppStartupState.Ready) return

            mutableState.value = AppStartupState.Migrating
            try {
                migration.importIfNeeded()
                mutableState.value = AppStartupState.Ready
            } catch (cancelled: CancellationException) {
                mutableState.value = AppStartupState.NotStarted
                throw cancelled
            } catch (exception: Exception) {
                mutableState.value = AppStartupState.Failed(exception.message)
            }
        }
    }
}
