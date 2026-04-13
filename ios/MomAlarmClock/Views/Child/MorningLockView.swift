import SwiftUI

/// Lock screen overlay shown when the device is in app-lock mode during escalation.
/// Displays the escalation state, a message from the parent, and the list of allowed apps.
struct MorningLockView: View {
    @Environment(ChildViewModel.self) private var vm

    /// Apps that remain accessible even during full lock.
    private let allowedApps = [
        AllowedApp(name: "Phone", icon: "phone.fill", color: .green),
        AllowedApp(name: "Messages", icon: "message.fill", color: .green),
        AllowedApp(name: "Emergency", icon: "sos", color: .red),
        AllowedApp(name: "Mom Alarm Clock", icon: "alarm.fill", color: .blue),
    ]

    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)

                Text("Device Locked")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("Complete your alarm verification to unlock your device.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let message = vm.activeSession?.parentMessage {
                    HStack {
                        Image(systemName: "quote.opening")
                            .foregroundStyle(.blue)
                        Text(message)
                            .foregroundStyle(.white)
                        Image(systemName: "quote.closing")
                            .foregroundStyle(.blue)
                    }
                    .padding()
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }

                // Allowed apps
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Apps")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.6))

                    ForEach(allowedApps) { app in
                        HStack(spacing: 12) {
                            Image(systemName: app.icon)
                                .foregroundStyle(app.color)
                                .frame(width: 32)
                            Text(app.name)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Spacer()

                NavigationLink {
                    VerificationView()
                } label: {
                    Label("Verify Now", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - AllowedApp

private struct AllowedApp: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
}
