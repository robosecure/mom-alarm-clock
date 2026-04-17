import SwiftUI

/// Root view that gates the app behind authentication.
/// Replaces the old RoleSelectionView. Role is determined by server-validated auth state,
/// not a local @AppStorage toggle.
struct AuthGateView: View {
    @Environment(AuthService.self) private var auth
    @Environment(ParentViewModel.self) private var parentVM
    @Environment(ChildViewModel.self) private var childVM

    var body: some View {
        Group {
            if auth.isLoading {
                loadingView
            } else if auth.awaitingEmailVerification {
                EmailVerificationView()
            } else if !auth.isAuthenticated {
                VStack(spacing: 0) {
                    if let error = auth.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(.orange)
                    }
                    AuthLandingView()
                }
            } else if let user = auth.currentUser {
                switch user.role {
                case .parent:
                    ParentDashboardView()
                case .child:
                    ChildAlarmView()
                }
            }
        }
        .task {
            await auth.restoreSession()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Mom Alarm Clock")
                .font(.title2.bold())
            ProgressView()
                .controlSize(.regular)
        }
    }
}

/// Landing page for unauthenticated users. Choose parent or child flow.
/// Remembers the last role used — auto-opens the sign-in form on return.
struct AuthLandingView: View {
    @State private var showParentAuth = false
    @State private var showChildPairing = false
    @AppStorage("lastSignedInRole") private var lastRole: String?

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Mom Alarm Clock")
                    .font(.largeTitle.bold())

                Text(lastRole != nil ? "Welcome back" : "Who is using this device?")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                Button {
                    showParentAuth = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "person.badge.shield.checkmark.fill")
                            .font(.title)
                            .foregroundStyle(.blue)
                            .frame(width: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("I'm the Guardian")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Create account, set alarms, monitor wake-ups")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button {
                    showChildPairing = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "person.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                            .frame(width: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("I'm the Child")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Enter family code to pair with guardian")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .onAppear {
            // Auto-open the sign-in form for returning users
            if let role = lastRole {
                if role == "parent" { showParentAuth = true }
                else if role == "child" { showChildPairing = true }
            }
        }
        .sheet(isPresented: $showParentAuth) {
            NavigationStack {
                ParentAuthView()
            }
        }
        .sheet(isPresented: $showChildPairing) {
            NavigationStack {
                ChildPairingView()
            }
        }
    }
}
