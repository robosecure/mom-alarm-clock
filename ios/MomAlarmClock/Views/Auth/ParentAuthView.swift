import SwiftUI

/// Parent sign-up and sign-in form.
/// Creates a Firebase Auth account (or local dev account) and a family with join code.
struct ParentAuthView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var isSignUp = true
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var familyCode: String?

    var body: some View {
        Form {
            Section {
                if isSignUp {
                    TextField("Your Name", text: $displayName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                }
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
            } header: {
                Text(isSignUp ? "Create Guardian Account" : "Sign In")
            }

            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            if let familyCode {
                Section {
                    VStack(spacing: 8) {
                        Text("Family Code")
                            .font(.headline)
                        Text(familyCode)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .tracking(6)
                        Text("Give this code to your child to pair their device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                }
                .disabled(isLoading || !isFormValid)

                if familyCode != nil {
                    Button("Go to Dashboard") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .bold()
                }
            }

            Section {
                Button(isSignUp ? "Already have an account? Sign in" : "Need an account? Sign up") {
                    isSignUp.toggle()
                    error = nil
                }
                .font(.subheadline)
            }
        }
        .navigationTitle(isSignUp ? "Guardian Setup" : "Guardian Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && (!isSignUp || !displayName.isEmpty)
    }

    private func submit() async {
        isLoading = true
        error = nil

        do {
            if isSignUp {
                try await auth.signUpAsParent(email: email, password: password, displayName: displayName)
                // The join code was generated during family creation
                familyCode = auth._lastJoinCode
            } else {
                try await auth.signInAsParent(email: email, password: password)
                dismiss()
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
