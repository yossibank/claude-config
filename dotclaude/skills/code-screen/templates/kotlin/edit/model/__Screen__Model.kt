package __modelPackage__

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import __core__.__Item__
import __draft__.__Item__Draft
import __base__.ErrorNotice
import __base__.ModelTask
import __base__.ScreenClock
import __base__.ScreenEditable
import __base__.ScreenOutcome
import __base__.ScreenPerforming
import __base__.ScreenWait
import __base__.Shown
import __store__.AppDatabase
import kotlinx.coroutines.CancellationException

class __Screen__Model(
    database: AppDatabase,
    clock: ScreenClock,
    wait: ScreenWait,
    editing: __Item__?,
) : ScreenPerforming {
    val state = State(name = editing?.name.orEmpty(), wait = wait)
    val input = Input(editing)
    val output = Output(input, state)

    private val dependencies = Dependencies(database, clock)

    class State(
        name: String,
        wait: ScreenWait,
    ) {
        val presented = Presented()
        val notices = Notices(wait)
        val task = ModelTask()
        val outcome = ScreenOutcome<__Item__>()

        var fields: Fields by mutableStateOf(Fields(name = name))
            private set

        fun updateFields(change: Fields.() -> Fields) {
            fields = fields.change()
        }
    }

    data class Fields(
        val name: String,
    ) : ScreenEditable

    class Presented : ScreenEditable {
        val prompt = Shown<Prompt>()
    }

    enum class Prompt {
        Discard,
    }

    class Notices(
        wait: ScreenWait,
    ) {
        val error = ErrorNotice(wait)
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
            get() = __Item__Draft(name = state.fields.name)

        val canSave: Boolean
            get() = draft.problems.isEmpty() && !state.task.isRunning && state.outcome.value == null

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
            val saved = state.task.attempt {
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
            state.notices.error.show(saveFailed)
        }
    }
}

private const val saveFailed = "保存できませんでした"
