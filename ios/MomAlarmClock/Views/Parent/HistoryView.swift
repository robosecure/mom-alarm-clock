import SwiftUI

/// Shows morning session history and tamper event log for the selected child.
struct HistoryView: View {
    @Environment(ParentViewModel.self) private var vm
    @State private var selectedTab = 0
    @State private var showClearConfirmation = false

    var body: some View {
        VStack {
            Picker("View", selection: $selectedTab) {
                Text("Mornings").tag(0)
                Text("Tamper Log").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if selectedTab == 0 {
                morningHistoryList
            } else {
                tamperEventList
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog("Clear History", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear Local History", role: .destructive) {
                Task { await vm.clearLocalHistory() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears session and tamper history from this device. Cloud data is not affected.")
        }
    }

    private var morningHistoryList: some View {
        List {
            if vm.recentSessions.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "calendar",
                    description: Text("Morning sessions will appear here after the first alarm.")
                )
            } else {
                ForEach(vm.recentSessions) { session in
                    morningRow(session)
                }
            }
        }
        .listStyle(.plain)
    }

    private func morningRow(_ session: MorningSession) -> some View {
        HStack {
            Image(systemName: sessionIcon(session))
                .foregroundStyle(sessionColor(session))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.alarmFiredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)

                if let result = session.verificationResult {
                    Label(result.method.displayName, systemImage: result.method.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let duration = session.wakeUpDuration {
                    Text("Verified in \(Int(duration / 60)) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if session.snoozeCount > 0 {
                    Text("Snoozed \(session.snoozeCount)x")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if session.verificationAttempts > 1 {
                    Text("Verification attempts: \(session.verificationAttempts)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if session.tamperCount > 0 {
                    Label("\(session.tamperCount) tamper event\(session.tamperCount > 1 ? "s" : "")", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let action = session.parentAction {
                    Text(parentActionLabel(action))
                        .font(.caption)
                        .foregroundStyle(action.isApproval ? .green : .red)
                }
            }

            Spacer()

            if session.wasOnTime {
                Label("On Time", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private func sessionIcon(_ session: MorningSession) -> String {
        switch session.state {
        case .verified: "checkmark.circle.fill"
        case .pendingParentReview: "hourglass.circle.fill"
        case .failed: "xmark.circle.fill"
        default: "circle.fill"
        }
    }

    private func sessionColor(_ session: MorningSession) -> Color {
        switch session.state {
        case .verified: .green
        case .pendingParentReview: .orange
        case .failed: .red
        default: .gray
        }
    }

    private func parentActionLabel(_ action: ParentAction) -> String {
        switch action {
        case .approved: "Guardian approved"
        case .autoAcknowledged: "Auto-acknowledged"
        case .denied(let reason): reason.isEmpty ? "Guardian denied" : "Denied: \(reason)"
        case .escalated(let reason): reason.isEmpty ? "Escalated" : "Escalated: \(reason)"
        }
    }

    private var tamperEventList: some View {
        List {
            if vm.tamperEvents.isEmpty {
                ContentUnavailableView(
                    "No Tamper Events",
                    systemImage: "shield.checkmark",
                    description: Text("No tampering has been detected.")
                )
            } else {
                ForEach(vm.tamperEvents) { event in
                    tamperRow(event)
                }
            }
        }
        .listStyle(.plain)
    }

    private func tamperRow(_ event: TamperEvent) -> some View {
        HStack {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(event.severity >= .high ? .red : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.type.displayName)
                    .font(.subheadline.bold())
                Text(event.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                let consequence = event.effectiveConsequence
                if consequence.pointsImpact != 0 || consequence.escalateVerificationTier {
                    HStack(spacing: 8) {
                        if consequence.pointsImpact != 0 {
                            Text("\(consequence.pointsImpact) pts")
                                .foregroundStyle(.red)
                        }
                        if consequence.escalateVerificationTier {
                            Text("Tier ↑")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.caption2.bold())
                }

                Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
