package __modelPackage__

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.time.Duration

class ScreenWait(
    private val scope: CoroutineScope,
    private val sleep: suspend (Duration) -> Unit,
) {
    fun after(
        duration: Duration,
        action: () -> Unit,
    ): Job = scope.launch {
        sleep(duration)
        action()
    }

    companion object {
        val system = ScreenWait(
            scope = CoroutineScope(SupervisorJob() + Dispatchers.Main),
            sleep = { delay(it) },
        )
    }
}
