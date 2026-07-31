import SwiftUI

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    var messageManager: MessageManager
    var wsManager: WebSocketManager

    @State private var text = ""
    @State private var isSending = false
    @FocusState private var focused: Bool

    private var remaining: Int { 140 - text.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Send a note")
                .font(.headline)

            TextEditor(text: $text)
                .frame(height: 80)
                .font(.body)
                .focused($focused)
                .onChange(of: text) {
                    if text.count > 140 {
                        text = String(text.prefix(140))
                    }
                }

            HStack {
                Text("\(remaining)")
                    .font(.caption)
                    .foregroundStyle(remaining < 20 ? .red : .secondary)
                Spacer()
                Button("Send") {
                    Task { await send() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(16)
        .frame(width: 280)
        .onAppear { focused = true }
    }

    private func send() async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSending = true
        await messageManager.sendMessage(trimmed)
        isSending = false
        dismiss()
    }
}
