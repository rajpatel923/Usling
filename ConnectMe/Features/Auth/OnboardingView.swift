import SwiftUI

/// Entry point for unauthenticated users. Guides them through email magic link.
struct OnboardingView: View {
    @Environment(AuthManager.self) private var auth

    @State private var email = ""
    @State private var step: Step = .enterEmail

    enum Step { case enterEmail, checkEmail }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Group {
                switch step {
                case .enterEmail: emailEntryView
                case .checkEmail: checkEmailView
                }
            }

            Spacer()
        }
        .frame(width: 380, height: 260)
        .background(.ultraThinMaterial)
        .onChange(of: auth.isAuthenticated) { _, isAuth in
            if isAuth { step = .enterEmail }
        }
    }

    // MARK: - Steps

    private var emailEntryView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("ConnectMe")
                    .font(.title2.bold())
                Text("A quiet presence layer for two people.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                TextField("your@email.com", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .disableAutocorrection(true)
                    .onSubmit { sendLink() }

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button(action: sendLink) {
                    HStack {
                        if auth.isLoading {
                            ProgressView().scaleEffect(0.7)
                        }
                        Text("Send magic link")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || auth.isLoading)
            }
        }
        .padding(32)
    }

    private var checkEmailView: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 44))
                .symbolRenderingMode(.multicolor)

            VStack(spacing: 6) {
                Text("Check your email")
                    .font(.headline)
                Text("We sent a link to \(email).\nClick it to sign in.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Resend") { sendLink() }
                .buttonStyle(.bordered)
                .disabled(auth.isLoading)
        }
        .padding(32)
    }

    // MARK: - Actions

    private func sendLink() {
        guard !email.isEmpty else { return }
        Task {
            await auth.sendMagicLink(to: email)
            if auth.errorMessage == nil {
                step = .checkEmail
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AuthManager.shared)
}
