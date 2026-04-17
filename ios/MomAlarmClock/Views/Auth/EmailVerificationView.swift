import SwiftUI
import FirebaseAuth

/// Shown after guardian signup while waiting for email verification.
/// The user must click the link in their email before the account activates.
struct EmailVerificationView: View {
    @Environment(AuthService.self) private var auth
    @State private var isChecking = false
    @State private var resent = false
    @State private var checkFailed = false
    @State private var isAbandoning = false
    @State private var cachedEmail: String?
    @State private var resendResetTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "envelope.badge")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Check Your Email")
                .font(.title2.bold())

            if let email = cachedEmail {
                Text("We sent a verification link to:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(email)
                    .font(.subheadline.bold())
            }

            Text("Tap the link in the email to activate your account, then come back here and tap the button below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Check verification button
            Button {
                Task { await checkVerification() }
            } label: {
                if isChecking {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 24)
                } else {
                    Text("I've Verified My Email")
                        .frame(maxWidth: .infinity)
                        .bold()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isChecking)

            if checkFailed {
                Text("Email not yet verified. Check your inbox and try again.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            // Resend button
            Button {
                Task { await resendEmail() }
            } label: {
                if resent {
                    Label("Verification email resent", systemImage: "checkmark")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                } else {
                    Text("Resend Verification Email")
                        .font(.subheadline)
                }
            }
            .disabled(resent)
            .padding(.bottom, 8)

            // Sign out / start over
            Button {
                Task {
                    isAbandoning = true
                    await auth.abandonUnverifiedSignup()
                    isAbandoning = false
                }
            } label: {
                if isAbandoning {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Cleaning up...")
                    }
                } else {
                    Text("Use a Different Email")
                }
            }
            .disabled(isAbandoning)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear {
            cachedEmail = Auth.auth().currentUser?.email
        }
        .onDisappear {
            resendResetTask?.cancel()
            resendResetTask = nil
        }
    }

    private func checkVerification() async {
        isChecking = true
        checkFailed = false
        let verified = await auth.checkEmailVerification()
        if !verified {
            checkFailed = true
        }
        isChecking = false
    }

    private func resendEmail() async {
        try? await auth.resendVerificationEmail()
        resent = true
        resendResetTask?.cancel()
        resendResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            resent = false
        }
    }
}
