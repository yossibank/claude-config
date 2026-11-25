package __modelPackage__

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import __core__.__Item__
import __base__.ScreenOutcome
import __base__.ScreenPerforming
import __store__.AppDatabase
import kotlinx.coroutines.CancellationException

class __Screen__Model(
    database: AppDatabase,
) : ScreenPerforming {
    val state = State()
    val input = Input()
    val output = Output(input)

    private val dependencies = Dependencies(database)

    class State {
        val outcome = ScreenOutcome<__Item__>()

        var failureMessage: String? by mutableStateOf(null)
        var editing: __Item__? by mutableStateOf(null)
    }

    class Input {
        var items: List<__Item__>? by mutableStateOf(null)
            internal set
    }

    class Output(
        private val input: Input,
    ) {
        val items: List<__Item__>
            get() = input.items ?: emptyList()

        val isLoaded: Boolean
            get() = input.items != null
    }

    private class Dependencies(
        val database: AppDatabase,
    )

    suspend fun run() {
        load()
        observe()
    }

    suspend fun load() {
        attempt(failure = loadFailed) {
            input.items = dependencies.database.__item__List()
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
            dependencies.database.__item__ListUpdates().collect { input.items = it }
        }
    }

    private suspend fun attempt(
        failure: String,
        action: suspend () -> Unit,
    ) {
        try {
            action()
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            state.failureMessage = failure
        }
    }
}

private const val loadFailed = "読み込めませんでした"
private const val removeFailed = "消せませんでした"
