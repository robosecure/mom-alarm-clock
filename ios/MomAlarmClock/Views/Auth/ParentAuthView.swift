import SwiftUI

/// Parent sign-up and sign-in form.
/// Creates a Firebase Auth account and a family with join code.
struct ParentAuthView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    /// Defaults to sign-in if the user has signed in before (returning user).
    @State private var isSignUp = UserDefaults.standard.string(forKey: "lastSignedInRole") == nil
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var showValidationErrors = false

    var body: some View {
        Form {
            Section {
                if isSignUp {
                    TextField("First Name", text: $displayName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                    if let err = InputValidation.validateName(displayName).errorMessage,
                       !displayName.isEmpty || showValidationErrors {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                }
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if let err = InputValidation.validateEmail(email).errorMessage,
                   !email.isEmpty || showValidationErrors {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
                if isSignUp && !password.isEmpty {
                    // Show strength indicator while typing
                    HStack(spacing: 4) {
                        Text("Strength:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(InputValidation.passwordStrength(password).label)
                            .font(.caption.bold())
                            .foregroundStyle(strengthColor)
                    }
                    // Show specific requirement errors below strength
                    if let err = InputValidation.validatePassword(password).errorMessage {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                }
                if isSignUp && password.isEmpty && showValidationErrors {
                    Text("Password is required.")
                        .font(.caption).foregroundStyle(.red)
                }
            } header: {
                Text(isSignUp ? "Create Guardian Account" : "Sign In")
            }

            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    if isFormValid {
                        Task { await submit() }
                    } else {
                        withAnimation { showValidationErrors = true }
                    }
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
                .disabled(isLoading)
            }

            Section {
                Button(isSignUp ? "Already have an account? Sign in" : "Need an account? Sign up") {
                    isSignUp.toggle()
                    error = nil
                    // Reset validation state so the other mode starts clean
                    showValidationErrors = false
                }
                .font(.subheadline)
            }
        }
        .navigationTitle(isSignUp ? "Guardian Setup" : "Guardian Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            }
        }
    }

    private var isFormValid: Bool {
        if isSignUp {
            return InputValidation.validateName(displayName).isValid
                && InputValidation.validateEmail(email).isValid
                && InputValidation.validatePassword(password).isValid
        } else {
            // Sign-in: just need non-empty email + password (server validates)
            return !email.isEmpty && !password.isEmpty
        }
    }

    private var strengthColor: Color {
        switch InputValidation.passwordStrength(password) {
        case .weak: .red
        case .medium: .orange
        case .strong: .green
        }
    }

    private func submit() async {
        isLoading = true
        error = nil

        do {
            if isSignUp {
                try await auth.signUpAsParent(email: email, password: password, displayName: displayName)
                // Auth state change triggers AuthGateView to switch to dashboard.
                // Join code is shown later when the guardian adds a child via AddChildView.
            } else {
                try await auth.signInAsParent(email: email, password: password)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
