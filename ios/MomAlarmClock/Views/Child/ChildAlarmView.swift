import SwiftUI

/// Main child screen showing the alarm countdown, current escalation state,
/// and entry point to verification. When no alarm is active, shows the next alarm time.
struct ChildAlarmView: View {
    @Environment(ChildViewModel.self) private var vm
    @State private var currentTime = Date()

    /// Timer to update the display every second.
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                VStack(spacing: 24) {
                    if vm.isAwaitingParentReview {
                        PendingReviewView()
                    } else if let session = vm.activeSession, session.isActive {
                        activeAlarmContent(session)
                    } else {
                        idleContent
                    }
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(timer) { currentTime = $0 }
            .onReceive(NotificationCenter.default.publisher(for: .alarmNotificationTapped)) { notif in
                if let alarmID = notif.userInfo?["alarmID"] as? String,
                   let uuid = UUID(uuidString: alarmID) {
                    Task { await vm.alarmDidFire(scheduleID: uuid) }
                }
            }
            .task { await vm.loadData() }
            .task { await vm.observeAlarmChanges() }
            .alert("Something went wrong", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .overlay(alignment: .top) {
                VStack(spacing: 4) {
                    if !NetworkMonitor.shared.isConnected {
                        bannerView("Offline: actions will sync when online", color: .gray)
                    }
                    if let msg = vm.connectivityBanner {
                        bannerView(msg, color: .orange)
                    }
                    if let msg = vm.syncConflictMessage {
                        bannerView(msg, color: .yellow)
                            .onAppear {
                                Task {
                                    try? await Task.sleep(for: .seconds(4))
                                    vm.syncConflictMessage = nil
                                }
                            }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func bannerView(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(.black)
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityLabel(text)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let isActive = vm.activeSession?.isActive ?? false
        return LinearGradient(
            colors: isActive ? [.red.opacity(0.3), .orange.opacity(0.1)] : [.blue.opacity(0.1), .purple.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Active Alarm

    @ViewBuilder
    private func activeAlarmContent(_ session: MorningSession) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // Pulsing alarm icon
            Image(systemName: "alarm.fill")
                .font(.system(size: 80))
                .foregroundStyle(.red)
                .symbolEffect(.pulse, options: .repeating)

            Text("Wake Up!")
                .font(.largeTitle.bold())

            Text(morningMotivation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("\(session.minutesSinceAlarm) min elapsed")
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)

            // Escalation progress
            if let level = vm.currentEscalationLevel {
                Label(level.action.displayName, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .padding(8)
                    .background(.orange.opacity(0.15), in: Capsule())
            }

            if let remaining = vm.timeUntilNextEscalation {
                Text("Reminder in \(Int(remaining / 60)) min")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Show denial reason if child was sent back to re-verify
            if case .denied(let reason) = session.parentAction {
                VStack(spacing: 4) {
                    Label("Verification Denied", systemImage: "xmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                    if !reason.isEmpty {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Please verify again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }

            // Parent message
            if let message = session.parentMessage {
                HStack {
                    Image(systemName: "message.fill")
                    Text(message)
                }
                .font(.subheadline)
                .padding()
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                NavigationLink {
                    VerificationView()
                } label: {
                    Label("I'm Awake — Verify", systemImage: "checkmark.circle.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel("Start wake-up verification")
                .accessibilityHint("Opens the verification screen to prove you're awake")
                .sensoryFeedback(.impact(weight: .medium), trigger: vm.activeSession?.state)

                if let schedule = vm.alarmSchedules.first(where: { $0.id == session.alarmScheduleID }),
                   schedule.snoozeRules.allowed,
                   session.snoozeCount < schedule.snoozeRules.maxCount {
                    Button {
                        Task { await vm.snooze() }
                    } label: {
                        Label(
                            "Snooze (\(session.snoozeCount)/\(schedule.snoozeRules.maxCount))",
                            systemImage: "zzz"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityLabel("Snooze alarm, \(session.snoozeCount) of \(schedule.snoozeRules.maxCount) used")
                }
            }

            NavigationLink {
                PhoneHomeView()
            } label: {
                Label("Message Parent", systemImage: "message")
                    .font(.subheadline)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Idle (No Active Alarm)

    private static let motivations = [
        "Today is going to be a great day!",
        "Rise and shine! You've got this.",
        "A new day, a new adventure!",
        "Your streak is counting on you!",
        "The early bird gets the worm!",
        "Time to make today awesome.",
        "You're stronger than the snooze button!",
    ]

    private var morningMotivation: String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return Self.motivations[day % Self.motivations.count]
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var idleContent: some View {
        VStack(spacing: 20) {
            Spacer()

            // Greeting
            if let name = vm.profile?.name {
                Text("\(greeting), \(name)")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }

            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 56))
                .foregroundStyle(.purple.opacity(0.6))

            if let nextAlarm = vm.nextAlarm,
               let nextDate = nextAlarm.alarmTime.nextOccurrence() {
                Text(nextAlarm.alarmTime.formatted)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text(nextDate.formatted(.relative(presentation: .named)))
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(nextAlarm.label)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                Text("No Alarm Set")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Waiting for your guardian to set an alarm.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Stats bar
            if let stats = vm.profile?.stats {
                HStack(spacing: 20) {
                    if stats.currentStreak > 0 {
                        Label("\(stats.currentStreak)-day streak", systemImage: "flame.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                    }
                    if stats.rewardPoints > 0 {
                        Label("\(stats.rewardPoints) pts", systemImage: "star.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.purple)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }
}
