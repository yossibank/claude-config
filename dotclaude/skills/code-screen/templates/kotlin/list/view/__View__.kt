package __viewPackage__

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import __core__.__Item__
import __modelPackage__.__Screen__Model
import __base__.perform
import __viewBase__.OnOutcome
import __store__.AppDatabase

@Composable
fun __View__(
    database: AppDatabase,
    onRemove: (__Item__) -> Unit,
    modifier: Modifier = Modifier,
) {
    val model = remember(database) { __Screen__Model(database = database) }
    val layout = remember { Layout() }
    val density = LocalDensity.current

    LaunchedEffect(model) {
        model.run()
    }

    OnOutcome(model.state.outcome, onRemove)

    Box(modifier = modifier) {
        LazyColumn(
            contentPadding = PaddingValues(top = layout.headerHeight),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(model.output.items) { item ->
                ItemRow(
                    item = item,
                    onOpen = { model.state.editing = item },
                    onRemove = { model.perform { it.remove(item) } },
                )
            }
        }

        Text(
            text = model.state.failureMessage.orEmpty(),
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .onSizeChanged { size ->
                    layout.headerHeight = with(density) { size.height.toDp() }
                },
        )
    }
}

@Composable
private fun ItemRow(
    item: __Item__,
    onOpen: () -> Unit,
    onRemove: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = item.name,
            modifier = Modifier.clickable(onClick = onOpen),
        )

        TextButton(onClick = onRemove) {
            Text(text = "消す")
        }
    }
}

private class Layout {
    var headerHeight: Dp by mutableStateOf(0.dp)
}
