package __viewPackage__

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.unit.dp
import __core__.__Item__
import __modelPackage__.__Screen__Model
import __base__.ScreenClock
import __base__.perform
import __viewBase__.OnOutcome
import __store__.AppDatabase

@Composable
fun __View__(
    database: AppDatabase,
    editing: __Item__?,
    onSave: (__Item__) -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val model = remember(database, editing) {
        __Screen__Model(
            database = database,
            clock = ScreenClock.system,
            editing = editing,
        )
    }

    val focus = LocalFocusManager.current

    OnOutcome(model.state.outcome, onSave)

    Column(
        modifier = modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        TextField(
            value = model.state.name,
            onValueChange = { model.state.name = it },
        )

        Text(text = model.state.failureMessage.orEmpty())

        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            TextButton(
                onClick = {
                    if (model.output.isChanged) {
                        model.state.isConfirmingDiscard = true
                    } else {
                        onClose()
                    }
                },
            ) {
                Text(text = "閉じる")
            }

            TextButton(
                onClick = {
                    focus.clearFocus()
                    model.perform { it.save() }
                },
                enabled = model.output.canSave,
            ) {
                Text(text = "保存")
            }
        }
    }

    if (model.state.isConfirmingDiscard) {
        DiscardDialog(
            onKeep = { model.state.isConfirmingDiscard = false },
            onDiscard = onClose,
        )
    }
}

@Composable
private fun DiscardDialog(
    onKeep: () -> Unit,
    onDiscard: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onKeep,
        confirmButton = {
            TextButton(onClick = onDiscard) {
                Text(text = "保存せずに閉じる")
            }
        },
        dismissButton = {
            TextButton(onClick = onKeep) {
                Text(text = "入力に戻る")
            }
        },
        title = { Text(text = "保存せずに閉じますか") },
    )
}
