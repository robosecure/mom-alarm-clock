import SwiftUI

/// Main parent screen showing child selector, live alarm status, configuration summary,
/// streaks/stats, and quick actions.
struct ParentDashboardView: View {
    @Environment(ParentViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm

        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    childSelector
                    liveStatusCard
                    alarmSummarySection
                    statsSection
                    quickActionsSection
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SetupWizardView()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
            .refreshable {
                await vm.loadAllData()
            }
            .task {
                await vm.loadAllData()
            }
        }
    }

    // MARK: - Child Selector

    @ViewBuilder
    private var childSelector: some View {
        if vm.children.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.children) { child in
                        childTab(child)
                    }
                }
            }
        }
    }

    private func childTab(_ child: ChildProfile) -> some View {
        Button {
            vm.selectedChildID = child.id
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                Text(child.name)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                vm.selectedChildID == child.id ? Color.blue.opacity(0.15) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Live Status

    @ViewBuilder
    private var liveStatusCard: some View {
        if let session = vm.selectedChildActiveSessions.first {
            VStack(alignment: .leading, spacing: 8) {
                Label("Active Alarm", systemImage: "bell.and.waves.left.and.right.fill")
                    .font(.headline)
                    .foregroundStyle(.red)

                Text("State: \(session.state.rawValue.capitalized)")
                    .font(.subheadline)

                Text("Elapsed: \(session.minutesSinceAlarm) min")
                    .font(.subheadline.monospacedDigit())

                if session.snoozeCount > 0 {
                    Text("Snoozed \(session.snoozeCount) time(s)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                HStack {
                    Button("Send Message") {
                        // TODO: Present message composer sheet
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Cancel Alarm", role: .destructive) {
                        Task { await vm.cancelSession(session.id) }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        } else if let child = vm.selectedChild {
            HStack {
                Image(systemName: HeartbeatService.isDeviceOffline(lastHeartbeat: child.lastHeartbeat)
                       ? "wifi.slash" : "checkmark.circle.fill")
                    .foregroundStyle(HeartbeatService.isDeviceOffline(lastHeartbeat: child.lastHeartbeat)
                                     ? .red : .green)
                VStack(alignment: .leading) {
                    Text("No active alarm")
                        .font(.subheadline)
                    Text("Last seen: \(HeartbeatService.lastSeenDescription(lastHeartbeat: child.lastHeartbeat))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Alarm Summary

    private var alarmSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Alarms")
                    .font(.headline)
                Spacer()
                NavigationLink("Edit") {
                    AlarmControlsView()
                }
                .font(.subheadline)
            }

            if vm.selectedChildSchedules.isEmpty {
                Text("No alarms configured yet.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(vm.selectedChildSchedules) { schedule in
                    alarmRow(schedule)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func alarmRow(_ schedule: AlarmSchedule) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(schedule.alarmTime.formatted)
                    .font(.title2.monospacedDigit().bold())
                Text(schedule.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { _ in Task { await vm.toggleAlarm(schedule.id) } }
            ))
            .labelsHidden()
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)

            if let stats = vm.selectedChild?.stats {
                HStack(spacing: 16) {
                    statBadge(value: "\(stats.currentStreak)", label: "Streak", icon: "flame.fill", color: .orange)
                    statBadge(value: "\(stats.onTimeCount)", label: "On Time", icon: "checkmark.circle", color: .green)
                    statBadge(value: "\(stats.lateCount)", label: "Late", icon: "exclamationmark.triangle", color: .yellow)
                    statBadge(value: "\(stats.rewardPoints)", label: "Points", icon: "star.fill", color: .purple)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statBadge(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                NavigationLink {
                    RewardStoreView()
                } label: {
                    quickActionButton(title: "Rewards", icon: "gift.fill", color: .purple)
                }

                NavigationLink {
                    HistoryView()
                } label: {
                    quickActionButton(title: "History", icon: "calendar", color: .blue)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func quickActionButton(title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
