package __modelPackage__

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

class ScreenOutcome<Value : Any> {
    var value: Value? by mutableStateOf(null)
        private set

    var count: Int by mutableIntStateOf(0)
        private set

    internal fun send(value: Value) {
        this.value = value
        count += 1
    }
}
