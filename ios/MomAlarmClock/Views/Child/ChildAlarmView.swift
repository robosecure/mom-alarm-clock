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
                    if let session = vm.activeSession, session.isActive {
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
            .task { await vm.loadData() }
        }
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
                Text("Next escalation in \(Int(remaining / 60)) min")
                    .font(.caption)
                    .foregroundStyle(.red)
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
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

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

    private var idleContent: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 64))
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
                Text("Waiting for parent to configure an alarm.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if let stats = vm.profile?.stats, stats.currentStreak > 0 {
                Label("\(stats.currentStreak)-day streak!", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .padding()
                    .background(.orange.opacity(0.1), in: Capsule())
            }
        }
    }
}
