package __modelPackage__

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue

class ModelTask {
    private var running: Int by mutableIntStateOf(0)

    val isRunning: Boolean
        get() = running > 0

    suspend fun <Value> attempt(action: suspend () -> Value): Value {
        running += 1

        try {
            return action()
        } finally {
            running -= 1
        }
    }
}
