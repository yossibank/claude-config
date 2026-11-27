package __modelPackage__

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.Job
import kotlin.time.Duration.Companion.seconds

class ErrorNotice(
    private val wait: ScreenWait,
) {
    var message: String? by mutableStateOf(null)
        private set

    private var count = 0
    private var timer: Job? = null

    fun show(message: String) {
        this.message = message
        count += 1

        val shown = count

        timer?.cancel()

        timer = wait.after(duration) {
            if (count == shown) {
                timer = null
                this.message = null
            }
        }
    }

    fun clear() {
        timer?.cancel()
        timer = null
        message = null
    }

    companion object {
        val duration = 6.seconds
    }
}
