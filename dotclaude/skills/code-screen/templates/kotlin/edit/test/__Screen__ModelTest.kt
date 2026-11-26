package __testPackage__

import __core__.__Item__
import __draft__.__Item__Draft
import __base__.ScreenClock
import __modelPackage__.__Screen__Model
import __store__.AppDatabase
import kotlinx.coroutines.test.runTest
import org.junit.Test
import java.time.Instant
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class __Screen__ModelTest {
    @Test
    fun refusesToSaveWithoutName() = runTest {
        val database = AppDatabase.inMemory()
        val model = database.editModel(editing = null)

        model.save()

        assertFalse(model.output.canSave)
        assertNull(model.state.outcome.value)
        assertTrue(database.__item__List().isEmpty())
    }

    @Test
    fun savesAndSendsOutcome() = runTest {
        val database = AppDatabase.inMemory()
        val model = database.editModel(editing = null)
        model.state.rename("見本")

        model.save()

        assertEquals("見本", model.state.outcome.value?.name)
        assertEquals(listOf("見本"), database.__item__List().map { it.name })
        assertNull(model.state.failureMessage)
    }

    @Test
    fun savesOnceWhenSavedTwice() = runTest {
        val database = AppDatabase.inMemory()
        val model = database.editModel(editing = null)
        model.state.rename("見本")

        model.save()
        model.save()

        assertEquals(listOf("見本"), database.__item__List().map { it.name })
        assertFalse(model.output.canSave)
    }

    @Test
    fun savesEditedItemInPlace() = runTest {
        val database = AppDatabase.inMemory()
        val saved = database.save(name = "見本")
        val model = database.editModel(editing = saved)
        model.state.rename("直した見本")

        model.save()

        assertEquals(listOf("直した見本"), database.__item__List().map { it.name })
    }

    @Test
    fun reportsChangeAgainstOpenedDraft() = runTest {
        val database = AppDatabase.inMemory()
        val saved = database.save(name = "見本")
        val model = database.editModel(editing = saved)

        val opened = model.output.isChanged
        model.state.rename("直した見本")
        val typed = model.output.isChanged
        model.state.rename("見本")

        assertFalse(opened)
        assertTrue(typed)
        assertFalse(model.output.isChanged)
    }
}

private val now: Instant = Instant.ofEpochSecond(1_791_000_000)

private fun AppDatabase.editModel(editing: __Item__?) = __Screen__Model(
    database = this,
    clock = ScreenClock.fixed(now),
    editing = editing,
)

private suspend fun AppDatabase.save(name: String): __Item__ = save__Item__(
    draft = __Item__Draft(name = name),
    editing = null,
    at = now,
)
