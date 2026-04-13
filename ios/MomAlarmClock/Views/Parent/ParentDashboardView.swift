import SwiftUI

/// Main parent screen showing child selector, live alarm status, configuration summary,
/// streaks/stats, and quick actions.
struct ParentDashboardView: View {
    @Environment(ParentViewModel.self) private var vm
    @State private var showMessageSheet = false
    @State private var messageText = ""

    var body: some View {
        @Bindable var vm = vm

        NavigationStack {
            if vm.isLoading && vm.children.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                }
            }
            ScrollView {
                VStack(spacing: 20) {
                    if !BetaDiagnostics.shared.pushPermissionGranted {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.slash.fill")
                                .foregroundStyle(.white)
                            Text("Push notifications disabled. You'll only see pending reviews when the app is open.")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 10))
                    }
                    if vm.children.isEmpty {
                        emptyFamilyState
                    } else {
                        childSelector
                        liveStatusCard
                        alarmSummarySection
                        statsSection
                        quickActionsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        FamilySettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        NavigationLink {
                            HistoryView()
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        #if DEBUG
                        NavigationLink {
                            DiagnosticsView()
                        } label: {
                            Image(systemName: "wrench.and.screwdriver")
                        }
                        #endif
                    }
                }
            }
            .refreshable {
                await vm.loadAllData()
            }
            .task {
                await vm.loadAllData()
                await BetaDiagnostics.shared.refreshPushState()
            }
            .task {
                await vm.observeActiveSessions()
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .sheet(isPresented: $showMessageSheet) {
                messageComposerSheet
            }
        }
    }

    // MARK: - Message Composer

    private var messageComposerSheet: some View {
        NavigationStack {
            Form {
                Section("Send a message to your child") {
                    TextField("Type a message...", text: $messageText)
                }
                Section {
                    Button("Send") {
                        guard let session = vm.selectedChildActiveSessions.first else { return }
                        Task {
                            await vm.sendMessage(messageText, toSession: session.id)
                            messageText = ""
                            showMessageSheet = false
                        }
                    }
                    .disabled(messageText.isEmpty)
                    .bold()
                }
            }
            .navigationTitle("Message Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showMessageSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Empty State

    private var emptyFamilyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "person.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.blue.opacity(0.6))
            Text("Welcome!")
                .font(.title.bold())
            Text("Add your first child to get started. You'll get a join code to pair their device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                showAddChild = true
            } label: {
                Label("Add Child", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Child Selector

    @State private var showAddChild = false
    @State private var showChildEditor = false
    @State private var showFamilySettings = false

    private static let childColors: [Color] = [.blue, .purple, .green, .orange]

    private var childSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(vm.children.enumerated()), id: \.element.id) { index, child in
                    childTab(child, color: Self.childColors[index % Self.childColors.count])
                        .contextMenu {
                            Button { showChildEditor = true } label: {
                                Label("Edit Profile", systemImage: "pencil")
                            }
                        }
                }
                // Add child button
                if vm.children.count < 4 {
                    Button { showAddChild = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.gray)
                            Text("Add")
                                .font(.caption.bold())
                                .foregroundStyle(.gray)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showAddChild) {
            NavigationStack { AddChildView() }
        }
        .sheet(isPresented: $showChildEditor) {
            if let child = vm.selectedChild {
                NavigationStack { ChildProfileEditorView(child: child) }
            }
        }
    }

    private func childTab(_ child: ChildProfile, color: Color) -> some View {
        Button {
            vm.selectedChildID = child.id
            Task { try? await vm.loadChildData(child.id) }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Text(String(child.name.prefix(1)).uppercased())
                        .font(.headline.bold())
                        .foregroundStyle(color)
                }
                HStack(spacing: 2) {
                    Text(child.name)
                        .font(.caption.bold())
                    if child.voiceAlarm != nil {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.pink)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                vm.selectedChildID == child.id ? color.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(vm.selectedChildID == child.id ? color.opacity(0.3) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Live Status

    @ViewBuilder
    private var liveStatusCard: some View {
        if let session = vm.selectedChildActiveSessions.first {
            VStack(alignment: .leading, spacing: 8) {
                if session.isAwaitingParent {
                    Label("Awaiting Your Review", systemImage: "hourglass.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                } else {
                    Label("Active Alarm", systemImage: "bell.and.waves.left.and.right.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                }

                Text("State: \(session.state.rawValue.capitalized)")
                    .font(.subheadline)

                Text("Elapsed: \(session.minutesSinceAlarm) min")
                    .font(.subheadline.monospacedDigit())

                if session.snoozeCount > 0 {
                    Text("Snoozed \(session.snoozeCount) time(s)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let result = session.verificationResult {
                    Label(result.proofSummary, systemImage: result.method.systemImage)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                if let childMessage = session.childMessage {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundStyle(.blue)
                        Text(childMessage)
                    }
                    .font(.caption)
                }

                HStack {
                    if session.isAwaitingParent {
                        NavigationLink {
                            VerificationReviewView(session: session)
                        } label: {
                            Label("Review", systemImage: "checkmark.shield")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }

                    Button("Send Message") {
                        showMessageSheet = true
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
            .background(session.isAwaitingParent ? .orange.opacity(0.08) : .red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
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
                NavigationLink {
                    AlarmControlsView()
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.subheadline)
                }
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
        NavigationLink {
            AlarmControlsView(existingSchedule: schedule)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    HStack(spacing: 6) {
                        Text(schedule.alarmTime.formatted)
                            .font(.title2.monospacedDigit().bold())
                            .foregroundStyle(schedule.isEffectivelyEnabled ? .primary : .secondary)
                        if schedule.skipUntil != nil {
                            Text("SKIP")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.2), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }
                    HStack(spacing: 4) {
                        Text(schedule.label)
                        Text("·")
                        Text(schedule.primaryVerification.displayName)
                    }
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
        .swipeActions(edge: .trailing) {
            if schedule.skipUntil != nil {
                Button("Unskip") {
                    Task { await vm.clearAlarmSkip(schedule.id) }
                }
                .tint(.green)
            } else {
                Button("Skip\nTomorrow") {
                    Task { await vm.skipAlarmTomorrow(schedule.id) }
                }
                .tint(.orange)
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)

            if let stats = vm.selectedChildStats {
                HStack(spacing: 12) {
                    statBadge(value: "\(stats.currentStreak)", label: "Streak", icon: "flame.fill", color: .orange)
                    statBadge(value: "\(stats.onTimeCount)", label: "On Time", icon: "checkmark.circle", color: .green)
                    statBadge(value: "\(stats.rewardPoints)", label: "Points", icon: "star.fill", color: .purple)
                    if stats.bestStreak > 0 {
                        statBadge(value: "\(stats.bestStreak)", label: "Best", icon: "trophy.fill", color: .yellow)
                    }
                }
            } else {
                Text("Stats will appear after the first morning session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    NextMorningSettingsView()
                } label: {
                    quickActionButton(title: "Tomorrow", icon: "sunrise.fill", color: .orange)
                }

                NavigationLink {
                    VoiceAlarmRecorderView()
                } label: {
                    quickActionButton(title: "Voice", icon: "mic.fill", color: .pink)
                }

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
