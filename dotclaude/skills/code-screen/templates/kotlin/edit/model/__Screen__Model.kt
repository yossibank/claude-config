package __modelPackage__

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import __core__.__Item__
import __draft__.__Item__Draft
import __base__.ScreenClock
import __base__.ScreenOutcome
import __base__.ScreenPerforming
import __store__.AppDatabase
import kotlinx.coroutines.CancellationException

class __Screen__Model(
    database: AppDatabase,
    clock: ScreenClock,
    editing: __Item__?,
) : ScreenPerforming {
    val state = State(name = editing?.name.orEmpty())
    val input = Input(editing)
    val output = Output(input, state)

    private val dependencies = Dependencies(database, clock)

    class State(
        name: String,
    ) {
        val outcome = ScreenOutcome<__Item__>()

        var name: String by mutableStateOf(name)
        var failureMessage: String? by mutableStateOf(null)
        var isConfirmingDiscard: Boolean by mutableStateOf(false)
    }

    class Input(
        val editing: __Item__?,
    ) {
        internal val baseline = __Item__Draft(name = editing?.name.orEmpty())
    }

    class Output(
        private val input: Input,
        private val state: State,
    ) {
        val draft: __Item__Draft
            get() = __Item__Draft(name = state.name)

        val canSave: Boolean
            get() = draft.problems.isEmpty()

        val isChanged: Boolean
            get() = draft != input.baseline
    }

    private class Dependencies(
        val database: AppDatabase,
        val clock: ScreenClock,
    )

    suspend fun save() {
        if (!output.canSave) {
            return
        }

        try {
            val saved = dependencies.database.save__Item__(
                draft = output.draft,
                editing = input.editing,
                at = dependencies.clock.now,
            )

            state.outcome.send(saved)
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            state.failureMessage = saveFailed
        }
    }
}

private const val saveFailed = "保存できませんでした"
