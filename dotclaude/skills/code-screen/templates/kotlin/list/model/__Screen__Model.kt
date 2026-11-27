package __modelPackage__

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import __core__.__Item__
import __base__.ErrorNotice
import __base__.Loadable
import __base__.ScreenEditable
import __base__.ScreenOutcome
import __base__.ScreenPerforming
import __base__.ScreenWait
import __base__.Shown
import __store__.AppDatabase
import kotlinx.coroutines.CancellationException

class __Screen__Model(
    database: AppDatabase,
    wait: ScreenWait,
) : ScreenPerforming {
    val state = State(wait)
    val input = Input()
    val output = Output(input)

    private val dependencies = Dependencies(database)

    class State(
        wait: ScreenWait,
    ) {
        val presented = Presented()
        val notices = Notices(wait)
        val outcome = ScreenOutcome<__Item__>()
    }

    class Presented : ScreenEditable {
        val editing = Shown<__Item__>()
    }

    class Notices(
        wait: ScreenWait,
    ) {
        val error = ErrorNotice(wait)
    }

    class Input {
        var items: Loadable<List<__Item__>> by mutableStateOf(Loadable.Loading)
            internal set
    }

    class Output(
        private val input: Input,
    ) {
        val items: List<__Item__>
            get() = input.items.value ?: emptyList()

        val isLoaded: Boolean
            get() = input.items.isLoaded

        val statusMessage: String?
            get() = if (input.items.isFailed) loadFailed else null
    }

    private class Dependencies(
        val database: AppDatabase,
    )

    suspend fun run() {
        load()
        observe()
    }

    suspend fun load() {
        attempt(failure = loadFailed, onFailure = { input.items = Loadable.Failed }) {
            input.items = Loadable.Loaded(dependencies.database.__item__List())
        }
    }

    suspend fun remove(item: __Item__) {
        attempt(failure = removeFailed) {
            dependencies.database.delete__Item__(item)
            state.outcome.send(item)
        }
    }

    private suspend fun observe() {
        attempt(failure = loadFailed) {
            dependencies.database.__item__ListUpdates().collect { input.items = Loadable.Loaded(it) }
        }
    }

    private suspend fun attempt(
        failure: String,
        onFailure: () -> Unit = {},
        action: suspend () -> Unit,
    ) {
        try {
            action()
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            onFailure()
            state.notices.error.show(failure)
        }
    }
}

private const val loadFailed = "読み込めませんでした"
private const val removeFailed = "消せませんでした"
