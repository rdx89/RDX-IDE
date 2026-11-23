package ai.rdx.ide

import androidx.compose.runtime.Composable
import ai.rdx.ide.ui.chat.ChatScreen
import ai.rdx.ide.ui.chat.ChatViewModel

@Composable
fun MainNavigation(viewModel: ChatViewModel? = null) {
    if (viewModel != null) {
        ChatScreen(viewModel = viewModel)
    } else {
        ChatScreen()
    }
}
