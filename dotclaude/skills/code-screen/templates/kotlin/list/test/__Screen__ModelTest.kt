package __testPackage__

import androidx.compose.runtime.snapshots.Snapshot
import __core__.__Item__
import __draft__.__Item__Draft
import __modelPackage__.__Screen__Model
import __store__.AppDatabase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import org.junit.Test
import java.time.Instant
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class __Screen__ModelTest {
    @Test
    fun showsNothingBeforeLoading() = runTest {
        val model = __Screen__Model(database = AppDatabase.inMemory())

        assertTrue(model.output.items.isEmpty())
        assertFalse(model.output.isLoaded)
    }

    @Test
    fun loadsSavedItems() = runTest {
        val database = AppDatabase.inMemory()
        database.save(name = "見本")
        val model = __Screen__Model(database = database)

        model.load()

        assertEquals(listOf("見本"), model.output.items.map { it.name })
        assertTrue(model.output.isLoaded)
        assertNull(model.state.failureMessage)
    }

    @Test
    fun followsChanges() = runTest {
        val database = AppDatabase.inMemory()
        val model = __Screen__Model(database = database)

        backgroundScope.launch { model.run() }
        database.save(name = "見本")
        waitUntil { model.output.items.size == 1 }

        assertEquals(listOf("見本"), model.output.items.map { it.name })
    }

    @Test
    fun removesAndSendsOutcome() = runTest {
        val database = AppDatabase.inMemory()
        val saved = database.save(name = "見本")
        val model = __Screen__Model(database = database)
        model.load()

        model.remove(saved)
        model.load()

        assertEquals(saved, model.state.outcome.value)
        assertTrue(model.output.items.isEmpty())
    }
}

private const val waitMillis = 5L
private const val waitRounds = 1_000

private val now: Instant = Instant.ofEpochSecond(1_791_000_000)

private suspend fun AppDatabase.save(name: String): __Item__ = save__Item__(
    draft = __Item__Draft(name = name),
    editing = null,
    at = now,
)

private suspend fun waitUntil(condition: () -> Boolean) {
    repeat(waitRounds) {
        Snapshot.sendApplyNotifications()

        if (condition()) {
            return
        }

        withContext(Dispatchers.Default) {
            delay(waitMillis)
        }
    }
}
