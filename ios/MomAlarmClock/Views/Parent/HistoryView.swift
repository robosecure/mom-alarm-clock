import SwiftUI

/// Shows morning session history and tamper event log for the selected child.
struct HistoryView: View {
    @Environment(ParentViewModel.self) private var vm
    @State private var selectedTab = 0

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
            Image(systemName: session.state == .verified ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(session.state == .verified ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.alarmFiredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)

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
                Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
