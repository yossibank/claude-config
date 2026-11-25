package __modelPackage__

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

interface ScreenPerforming

fun <Model : ScreenPerforming> Model.perform(work: suspend (Model) -> Unit): Job {
    val model = this
    return performing.launch { work(model) }
}

private val performing = CoroutineScope(SupervisorJob() + Dispatchers.Main)
