package com.mzarmehi1390.darsyar.data

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AppStartupCoordinatorTest {
    @Test
    fun repeatedAndConcurrentStartupCallsRunMigrationOnlyOnce() = runBlocking {
        val migration = FakeMigration {
            yield()
            LegacyImportOutcome.IMPORTED
        }
        val coordinator = AppStartupCoordinator(migration)

        val first = async { coordinator.ensureReady() }
        val second = async { coordinator.ensureReady() }
        first.await()
        second.await()

        assertEquals(1, migration.calls)
        assertEquals(AppStartupState.Ready, coordinator.state.value)
    }

    @Test
    fun failedMigrationCanBeRetriedSuccessfully() = runBlocking {
        var shouldFail = true
        val migration = FakeMigration {
            if (shouldFail) {
                shouldFail = false
                throw IllegalStateException("temporary failure")
            }
            LegacyImportOutcome.IMPORTED
        }
        val coordinator = AppStartupCoordinator(migration)

        coordinator.ensureReady()
        assertTrue(coordinator.state.value is AppStartupState.Failed)

        coordinator.ensureReady()
        assertEquals(AppStartupState.Ready, coordinator.state.value)
        assertEquals(2, migration.calls)
    }

    @Test
    fun cancellationResetsStateAndPropagatesToCaller() = runBlocking {
        val migration = FakeMigration {
            throw CancellationException("activity stopped")
        }
        val coordinator = AppStartupCoordinator(migration)

        var cancellationObserved = false
        try {
            coordinator.ensureReady()
        } catch (_: CancellationException) {
            cancellationObserved = true
        }

        assertTrue(cancellationObserved)
        assertEquals(AppStartupState.NotStarted, coordinator.state.value)
    }

    private class FakeMigration(
        private val action: suspend () -> LegacyImportOutcome,
    ) : LegacyDataMigration {
        var calls: Int = 0
            private set

        override suspend fun importIfNeeded(): LegacyImportOutcome {
            calls++
            return action()
        }
    }
}
