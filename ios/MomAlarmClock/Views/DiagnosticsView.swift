import SwiftUI
import FirebaseAuth
import FirebaseCore

/// Developer diagnostics screen for troubleshooting sync, auth, alarm, and push state.
struct DiagnosticsView: View {
    @Environment(AuthService.self) private var auth
    @State private var pendingNotifications = 0
    @State private var queuedActions = 0
    @State private var proofLog: [String] = []
    @State private var isRunningProof = false
    @State private var showRegenerateCode = false
    @State private var newJoinCode: String?
    @State private var cachedScheduleCount = 0
    @State private var nextFireDate: Date?
    @State private var notificationPermissionGranted = false

    var body: some View {
        List {
            Section("Auth") {
                row("User ID", auth.currentUser?.userID ?? "None")
                row("Role", auth.currentUser?.role.rawValue ?? "None")
                row("Family ID", auth.currentUser?.familyID ?? "None")
                row("Firebase UID", Auth.auth().currentUser?.uid ?? "No Firebase user")
                row("Firebase Configured", FirebaseApp.app() != nil ? "Yes" : "No (local mode)")
                row("Parent PIN Set", auth.hasParentPIN ? "Yes" : "No")
            }

            Section("App Check") {
                readinessRow("Enabled", BetaDiagnostics.shared.appCheckEnabled)
                row("Provider", BetaDiagnostics.shared.appCheckProvider)
                row("Last Result", BetaDiagnostics.shared.appCheckLastResult ?? "Not tested")
            }

            Section("Push Notifications") {
                readinessRow("Permission Granted", BetaDiagnostics.shared.pushPermissionGranted)
                row("FCM Token", BetaDiagnostics.shared.fcmToken ?? "Not registered")
                row("Token Registered", BetaDiagnostics.shared.fcmTokenRegisteredAt?.formatted(date: .omitted, time: .standard) ?? "Never")
                row("Last Push Received", BetaDiagnostics.shared.lastPushReceivedAt?.formatted(date: .omitted, time: .standard) ?? "Never")
                row("Last Push Type", BetaDiagnostics.shared.lastPushType ?? "N/A")
                if !BetaDiagnostics.shared.pushPermissionGranted {
                    Label("Push disabled: pending reviews only visible when app is open.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Sync") {
                row("Network", NetworkMonitor.shared.isConnected ? "Connected" : "Offline")
                row("Queued Actions", "\(queuedActions)")
                row("Sync Service", FirebaseApp.app() != nil ? "Firestore" : "Local")
            }

            Section("Sync Health") {
                row("Last Drain", NetworkMonitor.shared.lastDrainTime?.formatted(date: .omitted, time: .standard) ?? "Never")
                row("Succeeded", "\(NetworkMonitor.shared.lastDrainSucceeded)")
                row("Rules Rejected", "\(NetworkMonitor.shared.lastDrainRulesRejected)")
                row("Auth Expired", "\(NetworkMonitor.shared.lastDrainAuthExpired)")
                row("Transient (retry)", "\(NetworkMonitor.shared.lastDrainTransient)")
                if let err = NetworkMonitor.shared.lastDrainError {
                    row("Error", err)
                }
                if !NetworkMonitor.shared.rejectedSessionIDs.isEmpty {
                    row("Rejected Sessions", NetworkMonitor.shared.rejectedSessionIDs.joined(separator: ", "))
                }
            }

            Section("Alarms") {
                row("Scheduled Notifications", "\(pendingNotifications)")
                row("Cached Schedules", "\(cachedScheduleCount)")
                if let nextFire = nextFireDate {
                    row("Next Fire", nextFire.formatted(date: .abbreviated, time: .shortened))
                }
                readinessRow("Notification Permission", notificationPermissionGranted)
            }

            Section("Launch Readiness") {
                readinessRow("Firebase Configured", FirebaseApp.app() != nil)
                readinessRow("App Check", BetaDiagnostics.shared.appCheckEnabled)
                readinessRow("Auth Valid", auth.isAuthenticated && auth.currentUser != nil)
                readinessRow("Role Set", auth.currentUser?.role != nil)
                readinessRow("Family ID Set", auth.currentUser?.familyID != nil)
                readinessRow("Push Enabled", BetaDiagnostics.shared.pushPermissionGranted)
                readinessRow("FCM Token", BetaDiagnostics.shared.fcmToken != nil)
                readinessRow("Network Connected", NetworkMonitor.shared.isConnected)
                readinessRow("Queue Empty", queuedActions == 0)
                readinessRow("Alarms Scheduled", pendingNotifications > 0)
            }

            #if DEBUG
            Section("Beta Proof Script") {
                Button {
                    Task { await runBetaProofChecks() }
                } label: {
                    Label(isRunningProof ? "Running..." : "Run Beta Proof Checks", systemImage: "checkmark.shield")
                }
                .disabled(isRunningProof)

                ForEach(proofLog, id: \.self) { entry in
                    Text(entry)
                        .font(.caption.monospaced())
                        .foregroundStyle(entry.contains("FAIL") ? .red : entry.contains("PASS") ? .green : .secondary)
                }
            }
            #endif

            Section("Support Tools") {
                Button {
                    Task { await exportDiagnostics() }
                } label: {
                    Label("Copy Diagnostics to Clipboard", systemImage: "doc.on.clipboard")
                }

                if auth.currentUser?.role == .parent {
                    Button {
                        showRegenerateCode = true
                    } label: {
                        Label("Regenerate Join Code", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }

            Section("Device") {
                row("iOS", UIDevice.current.systemVersion)
                row("Model", UIDevice.current.model)
                row("Timezone", TimeZone.current.identifier)
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refresh()
            await BetaDiagnostics.shared.refreshPushState()
            await BetaDiagnostics.shared.refreshAppCheckState()
        }
        .refreshable {
            await refresh()
            await BetaDiagnostics.shared.refreshPushState()
            await BetaDiagnostics.shared.refreshAppCheckState()
        }
        .alert("Regenerate Join Code", isPresented: $showRegenerateCode) {
            Button("Cancel", role: .cancel) {}
            Button("Regenerate") {
                newJoinCode = ChildProfile.generatePairingCode()
            }
        } message: {
            Text("This generates a new 10-character join code. The old code is not invalidated — use Firestore Console to delete it if needed.")
        }
        .alert("New Join Code", isPresented: Binding(
            get: { newJoinCode != nil },
            set: { if !$0 { newJoinCode = nil } }
        )) {
            Button("Copy") {
                UIPasteboard.general.string = newJoinCode
                newJoinCode = nil
            }
            Button("OK") { newJoinCode = nil }
        } message: {
            Text(newJoinCode ?? "")
                .font(.system(.body, design: .monospaced))
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    private func readinessRow(_ label: String, _ ok: Bool) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red)
            Text(label)
            Spacer()
            Text(ok ? "OK" : "FAIL")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(ok ? .green : .red)
        }
    }

    private func refresh() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        pendingNotifications = requests.count
        queuedActions = await LocalStore.shared.pendingQueue().count
        cachedScheduleCount = await LocalStore.shared.alarmSchedules().count

        // Find the next alarm fire date
        let alarmRequests = requests.filter { $0.identifier.hasPrefix("com.momclock.alarm.") }
        let nextDates = alarmRequests.compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }
        nextFireDate = nextDates.min()

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationPermissionGranted = settings.authorizationStatus == .authorized
    }

    private func exportDiagnostics() async {
        let json = await BetaDiagnostics.shared.exportDiagnostics(auth: auth)
        UIPasteboard.general.string = json
    }

    // MARK: - Beta Proof Script

    private func runBetaProofChecks() async {
        isRunningProof = true
        proofLog = []
        defer { isRunningProof = false }

        check("Auth: authenticated", auth.isAuthenticated)
        check("Auth: role is set", auth.currentUser?.role != nil)
        check("Auth: familyID is set", auth.currentUser?.familyID != nil)
        check("Firebase: configured", FirebaseApp.app() != nil)
        check("Firebase: Auth user exists", Auth.auth().currentUser != nil)

        await BetaDiagnostics.shared.refreshPushState()
        check("Push: permission granted", BetaDiagnostics.shared.pushPermissionGranted)
        check("Push: FCM token registered", BetaDiagnostics.shared.fcmToken != nil)

        check("Sync: network connected", NetworkMonitor.shared.isConnected)
        let qCount = await LocalStore.shared.pendingQueue().count
        check("Sync: queue empty", qCount == 0)
        check("Sync: no rules rejections", NetworkMonitor.shared.lastDrainRulesRejected == 0)

        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        check("Alarms: at least 1 scheduled", !requests.isEmpty)

        let schedules = await LocalStore.shared.alarmSchedules()
        check("Local: alarm schedules cached", !schedules.isEmpty)

        // Alarm-to-session wiring: verify notification IDs exist
        let alarmNotifs = requests.filter { $0.identifier.hasPrefix("com.momclock.alarm.") }
        check("Alarm: notification IDs have alarmID in userInfo",
              alarmNotifs.allSatisfy { $0.content.userInfo["alarmID"] != nil })

        // Notification permission
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        check("Notifications: permission authorized", settings.authorizationStatus == .authorized)

        let passed = proofLog.filter { $0.contains("PASS") }.count
        let failed = proofLog.filter { $0.contains("FAIL") }.count
        proofLog.append("--- Done: \(passed) passed, \(failed) failed ---")

        // Auto-copy to clipboard for easy sharing
        UIPasteboard.general.string = proofLog.joined(separator: "\n")
    }

    private func check(_ label: String, _ condition: Bool) {
        proofLog.append("\(condition ? "PASS" : "FAIL") \(label)")
    }
}
