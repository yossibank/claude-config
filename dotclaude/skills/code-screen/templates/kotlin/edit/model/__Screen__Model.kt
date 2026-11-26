package __modelPackage__

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import __core__.__Item__
import __draft__.__Item__Draft
import __base__.ModelTask
import __base__.ScreenClock
import __base__.ScreenOutcome
import __base__.ScreenPerforming
import __base__.Shown
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
        val prompt = Shown<Prompt>()
        val saving = ModelTask()

        var name: String by mutableStateOf(name)
            private set

        var failureMessage: String? by mutableStateOf(null)
            internal set

        fun rename(name: String) {
            this.name = name
        }
    }

    enum class Prompt {
        Discard,
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
            get() = draft.problems.isEmpty() && !state.saving.isRunning && state.outcome.value == null

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
            val saved = state.saving.attempt {
                dependencies.database.save__Item__(
                    draft = output.draft,
                    editing = input.editing,
                    at = dependencies.clock.now,
                )
            }

            state.outcome.send(saved)
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            state.failureMessage = saveFailed
        }
    }
}

private const val saveFailed = "保存できませんでした"
