package __viewPackage__

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.snapshotFlow
import __modelPackage__.ScreenOutcome
import kotlinx.coroutines.flow.filter

@Composable
fun <Value : Any> OnOutcome(
    outcome: ScreenOutcome<Value>,
    action: (Value) -> Unit,
) {
    val current by rememberUpdatedState(action)
    val start = remember(outcome) { outcome.count }

    LaunchedEffect(outcome) {
        snapshotFlow { outcome.count }
            .filter { it != start }
            .collect { outcome.value?.let(current) }
    }
}
