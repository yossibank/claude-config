package __modelPackage__

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

class Shown<Value : Any>(
    current: Value? = null,
) : ScreenEditable {
    var current: Value? by mutableStateOf(current)
        private set

    fun isShowing(value: Value): Boolean = current == value

    fun show(value: Value) {
        current = value
    }

    fun close(value: Value) {
        if (current == value) {
            current = null
        }
    }

    fun closeAll() {
        current = null
    }
}
