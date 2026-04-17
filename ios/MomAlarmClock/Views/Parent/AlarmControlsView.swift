import SwiftUI

/// Full alarm configuration form for parents.
/// Allows setting time, days, verification method, snooze rules, and escalation profile.
struct AlarmControlsView: View {
    @Environment(ParentViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing schedule to edit; nil = create new.
    var existingSchedule: AlarmSchedule?

    @State private var label = "School Days"
    @State private var alarmDate = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? .now
    @State private var selectedDays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri
    @State private var primaryVerification: VerificationMethod = .quiz // Most popular default
    @State private var fallbackVerification: VerificationMethod? = .motion // Fallback if quiz fails
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

                DatePicker("Time", selection: $alarmDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
            }

            Section("Active Days") {
                HStack(spacing: 8) {
                    ForEach(1...7, id: \.self) { day in
                        dayToggle(day: day)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("How They Prove They're Up") {
                Picker("Primary Method", selection: $primaryVerification) {
                    ForEach(VerificationMethod.allCases.filter(\.isAvailableForLaunch)) { method in
                        Label(method.displayName, systemImage: method.systemImage)
                            .tag(method)
                    }
                }

                Picker("Fallback Method", selection: $fallbackVerification) {
                    Text("None").tag(nil as VerificationMethod?)
                    ForEach(VerificationMethod.allCases.filter(\.isAvailableForLaunch)) { method in
                        Label(method.displayName, systemImage: method.systemImage)
                            .tag(method as VerificationMethod?)
                    }
                }
            }

            Section {
                Button {
                    confirmationPolicy = .autoAcknowledge
                } label: {
                    policyRow(.autoAcknowledge, recommended: true)
                }
                .buttonStyle(.plain)

                DisclosureGroup("Other options") {
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
            } header: {
                Text("After Verification")
            } footer: {
                Text("Most families use Trust Mode. You'll only hear from us when something needs attention.")
            }

            Section {
                DisclosureGroup("Difficulty") {
                    Picker("Tier", selection: $verificationTier) {
                        ForEach(VerificationTier.allCases) { tier in
                            Text(tier.displayName).tag(tier)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Automatically set based on your child's age. Override here if needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                DisclosureGroup("Snooze") {
                    Toggle("Allow Snooze", isOn: $snoozeAllowed)

                    if snoozeAllowed {
                        Stepper("Max Snoozes: \(maxSnoozes)", value: $maxSnoozes, in: 1...5)
                        Stepper("Duration: \(snoozeDuration) min", value: $snoozeDuration, in: 1...15)
                    }
                }

                DisclosureGroup("If They Don't Get Up") {
                    Toggle("Use Default Reminders", isOn: $useDefaultEscalation)
                    if useDefaultEscalation {
                        ForEach(EscalationProfile.default.levels) { level in
                            HStack {
                                Text("+\(level.minutesAfterAlarm) min")
                                    .font(.caption.monospacedDigit())
                                    .frame(width: 60, alignment: .leading)
                                Image(systemName: level.action.systemImage)
                                    .frame(width: 20)
                                    .foregroundStyle(level.action.isLaunchReady ? .primary : .tertiary)
                                Text(level.action.displayName)
                                    .font(.subheadline)
                                    .foregroundStyle(level.action.isLaunchReady ? .primary : .tertiary)
                            }
                        }
                        if !FamilyControlsService.shared.isAuthorized {
                            Label("App lock requires Screen Time permission on the child's device. Other escalation steps work without it.", systemImage: "info.circle")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Advanced")
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
        alarmDate = Calendar.current.date(from: DateComponents(hour: s.alarmTime.hour, minute: s.alarmTime.minute)) ?? .now
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

        let components = Calendar.current.dateComponents([.hour, .minute], from: alarmDate)
        var schedule = AlarmSchedule(
            alarmTime: AlarmSchedule.AlarmTime(hour: components.hour ?? 7, minute: components.minute ?? 0),
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

    private func policyRow(_ policy: ConfirmationPolicy, recommended: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(policy.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    if recommended {
                        Text("Recommended")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue, in: Capsule())
                    }
                }
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
