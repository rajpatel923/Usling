import SwiftUI

struct InboxView: View {
    @Environment(\.dismiss) private var dismiss
    var messageManager: MessageManager
    var wsManager: WebSocketManager

    @State private var replyText = ""
    @State private var isSending = false
    @FocusState private var replyFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Messages list
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(messageManager.pendingMessages) { msg in
                        Text(msg.content)
                            .font(.body)
                            .padding(10)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 200)

            Divider()

            // Reply bar
            HStack(spacing: 8) {
                TextField("Reply…", text: $replyText)
                    .textFieldStyle(.plain)
                    .focused($replyFocused)
                    .onChange(of: replyText) {
                        if replyText.count > 140 {
                            replyText = String(replyText.prefix(140))
                        }
                    }
                    .onSubmit { Task { await sendReply() } }

                Button("Send") {
                    Task { await sendReply() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(replyText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            }
            .padding(12)
        }
        .frame(width: 280)
        .onAppear {
            // ACK all displayed messages immediately — they're gone once seen
            messageManager.ackAll(via: wsManager)
            replyFocused = true
        }
    }

    private func sendReply() async {
        let trimmed = replyText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSending = true
        replyText = ""
        await messageManager.sendMessage(trimmed)
        isSending = false
        dismiss()
    }
}
