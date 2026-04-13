import SwiftUI

/// Full alarm configuration form for parents.
/// Allows setting time, days, verification method, snooze rules, and escalation profile.
struct AlarmControlsView: View {
    @Environment(ParentViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing schedule to edit; nil = create new.
    var existingSchedule: AlarmSchedule?

    @State private var label = "School Days"
    @State private var hour = 7
    @State private var minute = 0
    @State private var selectedDays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri
    @State private var primaryVerification: VerificationMethod = .quiz
    @State private var fallbackVerification: VerificationMethod? = .motion
    @State private var snoozeAllowed = true
    @State private var maxSnoozes = 2
    @State private var snoozeDuration = 5
    @State private var useDefaultEscalation = true
    @State private var verificationTier: VerificationTier = .medium
    @State private var confirmationPolicy: ConfirmationPolicy = .default

    private var isEditing: Bool { existingSchedule != nil }

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        Form {
            Section("Alarm") {
                TextField("Label", text: $label)

                HStack {
                    Picker("Hour", selection: $hour) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(String(format: "%d %@", h % 12 == 0 ? 12 : h % 12, h < 12 ? "AM" : "PM"))
                                .tag(h)
                        }
                    }
                    Picker("Minute", selection: $minute) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                            Text(String(format: ":%02d", m)).tag(m)
                        }
                    }
                }
            }

            Section("Active Days") {
                HStack(spacing: 8) {
                    ForEach(1...7, id: \.self) { day in
                        dayToggle(day: day)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Verification") {
                Picker("Primary Method", selection: $primaryVerification) {
                    ForEach(VerificationMethod.allCases) { method in
                        Label(method.displayName, systemImage: method.systemImage)
                            .tag(method)
                    }
                }

                Picker("Fallback Method", selection: $fallbackVerification) {
                    Text("None").tag(nil as VerificationMethod?)
                    ForEach(VerificationMethod.allCases) { method in
                        Label(method.displayName, systemImage: method.systemImage)
                            .tag(method as VerificationMethod?)
                    }
                }
            }

            Section("Verification Difficulty") {
                Picker("Tier", selection: $verificationTier) {
                    ForEach(VerificationTier.allCases) { tier in
                        Text(tier.displayName).tag(tier)
                    }
                }
                .pickerStyle(.segmented)

                Text(verificationTier.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Confirmation Policy") {
                Button {
                    confirmationPolicy = .autoAcknowledge
                } label: {
                    policyRow(.autoAcknowledge)
                }
                .buttonStyle(.plain)

                Button {
                    confirmationPolicy = .requireParentApproval
                } label: {
                    policyRow(.requireParentApproval)
                }
                .buttonStyle(.plain)

                Button {
                    confirmationPolicy = .hybrid(windowMinutes: 30)
                } label: {
                    policyRow(.hybrid(windowMinutes: 30))
                }
                .buttonStyle(.plain)
            }

            Section("Snooze Rules") {
                Toggle("Allow Snooze", isOn: $snoozeAllowed)

                if snoozeAllowed {
                    Stepper("Max Snoozes: \(maxSnoozes)", value: $maxSnoozes, in: 1...5)
                    Stepper("Duration: \(snoozeDuration) min", value: $snoozeDuration, in: 1...15)
                }
            }

            Section("Escalation") {
                Toggle("Use Default Escalation", isOn: $useDefaultEscalation)
                if useDefaultEscalation {
                    ForEach(EscalationProfile.default.levels) { level in
                        HStack {
                            Text("+\(level.minutesAfterAlarm) min")
                                .font(.caption.monospacedDigit())
                                .frame(width: 60, alignment: .leading)
                            Text(level.action.displayName)
                                .font(.subheadline)
                        }
                    }
                }
            }

            Section {
                Button(isEditing ? "Save Changes" : "Create Alarm") {
                    Task { await saveAlarm() }
                }
                .bold()
                .frame(maxWidth: .infinity)
            }

            if isEditing, let existing = existingSchedule {
                Section {
                    Button("Delete Alarm", role: .destructive) {
                        Task {
                            await vm.deleteAlarmSchedule(existing.id)
                            dismiss()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Alarm" : "New Alarm")
        .onAppear { loadExisting() }
    }

    private func dayToggle(day: Int) -> some View {
        let index = day - 1
        let isSelected = selectedDays.contains(day)
        return Button {
            if isSelected { selectedDays.remove(day) } else { selectedDays.insert(day) }
        } label: {
            Text(dayNames[index].prefix(1))
                .font(.caption.bold())
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2), in: Circle())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func loadExisting() {
        guard let s = existingSchedule else { return }
        label = s.label
        hour = s.alarmTime.hour
        minute = s.alarmTime.minute
        selectedDays = s.activeDays
        primaryVerification = s.primaryVerification
        fallbackVerification = s.fallbackVerification
        snoozeAllowed = s.snoozeRules.allowed
        maxSnoozes = s.snoozeRules.maxCount
        snoozeDuration = s.snoozeRules.durationMinutes
        verificationTier = s.verificationTier
        confirmationPolicy = s.confirmationPolicy
    }

    private func saveAlarm() async {
        guard let childID = vm.selectedChildID else { return }

        var schedule = AlarmSchedule(
            alarmTime: AlarmSchedule.AlarmTime(hour: hour, minute: minute),
            activeDays: selectedDays,
            primaryVerification: primaryVerification,
            fallbackVerification: fallbackVerification,
            escalation: existingSchedule?.escalation ?? .default,
            verificationTier: verificationTier,
            confirmationPolicy: confirmationPolicy,
            snoozeRules: AlarmSchedule.SnoozeRules(
                allowed: snoozeAllowed,
                maxCount: maxSnoozes,
                durationMinutes: snoozeDuration
            ),
            label: label,
            childProfileID: childID
        )

        // Reuse existing ID when editing (so Firestore overwrites, not creates duplicate)
        if let existing = existingSchedule {
            schedule.id = existing.id
        }

        await vm.saveAlarmSchedule(schedule)
        dismiss()
    }

    private func policyRow(_ policy: ConfirmationPolicy) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(policy.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text(policy.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if policyMatches(confirmationPolicy, policy) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 2)
    }

    private func policyMatches(_ a: ConfirmationPolicy, _ b: ConfirmationPolicy) -> Bool {
        switch (a, b) {
        case (.autoAcknowledge, .autoAcknowledge): true
        case (.requireParentApproval, .requireParentApproval): true
        case (.hybrid, .hybrid): true
        default: false
        }
    }
}
