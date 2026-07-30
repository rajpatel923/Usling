import SwiftUI

/// Two-tab UI for sharing/accepting an invite code.
struct PairingView: View {
    @Environment(PairingManager.self) private var pairing

    @State private var selectedTab = 0
    @State private var generatedCode: String?
    @State private var enteredCode = ""
    @State private var codeCopied = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Connect with your partner")
                        .font(.title3.bold())
                    Text("One person shares a code, the other enters it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Picker("", selection: $selectedTab) {
                    Text("Share code").tag(0)
                    Text("Enter code").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Group {
                    if selectedTab == 0 {
                        shareCodeTab
                    } else {
                        enterCodeTab
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(32)

            Spacer()
        }
        .frame(width: 380, height: 300)
        .background(.ultraThinMaterial)
    }

    // MARK: - Tabs

    private var shareCodeTab: some View {
        VStack(spacing: 16) {
            if let code = generatedCode {
                HStack(spacing: 12) {
                    Text(code)
                        .font(.system(.title, design: .monospaced).bold())
                        .tracking(6)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                        codeCopied = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            codeCopied = false
                        }
                    } label: {
                        Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                Text("Share this code with your partner.\nExpires in 7 days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Button(action: generateCode) {
                    HStack {
                        if pairing.isLoading { ProgressView().scaleEffect(0.7) }
                        Text("Generate code")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(pairing.isLoading)
            }
        }
    }

    private var enterCodeTab: some View {
        VStack(spacing: 12) {
            TextField("XXXXXX", text: $enteredCode)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.center)
                .textContentType(.oneTimeCode)
                .onChange(of: enteredCode) { _, new in
                    enteredCode = new.uppercased().filter { $0.isLetter || $0.isNumber }
                    if enteredCode.count > 6 { enteredCode = String(enteredCode.prefix(6)) }
                }

            if let error = pairing.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button(action: acceptCode) {
                HStack {
                    if pairing.isLoading { ProgressView().scaleEffect(0.7) }
                    Text("Connect")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(enteredCode.count < 6 || pairing.isLoading)
        }
    }

    // MARK: - Actions

    private func generateCode() {
        Task {
            generatedCode = await pairing.generateInviteCode()
        }
    }

    private func acceptCode() {
        Task {
            await pairing.acceptInvite(code: enteredCode)
        }
    }
}
