import SwiftUI
import UserNotifications

/// Interactive onboarding checklist that guides the parent through
/// creating a child profile, configuring the first alarm, and pairing a device.
struct SetupWizardView: View {
    @Environment(ParentViewModel.self) private var parentVM
    @State private var vm = SetupWizardViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: vm.parentProgress)
                .padding(.horizontal)
                .padding(.top)

            TabView(selection: Binding(
                get: { vm.currentParentStep },
                set: { vm.currentParentStep = $0 }
            )) {
                welcomeStep.tag(SetupWizardViewModel.ParentStep.welcome)
                createChildStep.tag(SetupWizardViewModel.ParentStep.createChild)
                configureAlarmStep.tag(SetupWizardViewModel.ParentStep.configureAlarm)
                verificationStep.tag(SetupWizardViewModel.ParentStep.chooseVerification)
                escalationStep.tag(SetupWizardViewModel.ParentStep.setEscalation)
                pairDeviceStep.tag(SetupWizardViewModel.ParentStep.pairDevice)
                testAlarmStep.tag(SetupWizardViewModel.ParentStep.testAlarm)
                completeStep.tag(SetupWizardViewModel.ParentStep.complete)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "alarm.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            Text("Let's Set Up Your Child's Alarm")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("This wizard will walk you through creating a profile, setting an alarm, and pairing your child's device.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            nextButton { vm.completeParentStep(.welcome) }
        }
        .padding()
    }

    private var createChildStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Add Your Child")
                .font(.title2.bold())

            TextField("Child's Name", text: $vm.childName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Stepper("Age: \(vm.childAge)", value: $vm.childAge, in: 4...18)
                .padding(.horizontal)

            Spacer()
            nextButton(disabled: vm.childName.isEmpty) {
                Task {
                    await parentVM.addChild(name: vm.childName, age: vm.childAge)
                    vm.completeParentStep(.createChild)
                }
            }
        }
        .padding()
    }

    private var configureAlarmStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Set Wake-Up Time")
                .font(.title2.bold())

            HStack {
                Picker("Hour", selection: $vm.alarmHour) {
                    ForEach(4..<12, id: \.self) { h in
                        Text("\(h):00 AM").tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 150)

                Picker("Minute", selection: $vm.alarmMinute) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                        Text(String(format: ":%02d", m)).tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 100)
            }
            .frame(height: 150)

            Spacer()
            nextButton { vm.completeParentStep(.configureAlarm) }
        }
        .padding()
    }

    private var verificationStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("How Should They Verify?")
                .font(.title2.bold())

            ForEach(VerificationMethod.allCases) { method in
                Button {
                    vm.selectedVerification = method
                } label: {
                    HStack {
                        Image(systemName: method.systemImage)
                            .frame(width: 32)
                        VStack(alignment: .leading) {
                            Text(method.displayName).font(.subheadline.bold())
                            Text(method.description).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if vm.selectedVerification == method {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            Spacer()
            nextButton { vm.completeParentStep(.chooseVerification) }
        }
        .padding()
    }

    private var escalationStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Escalation Rules")
                .font(.title2.bold())

            Text("If your child doesn't get up, the app will gradually increase consequences:")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(EscalationProfile.default.levels) { level in
                    HStack(spacing: 12) {
                        Text("+\(level.minutesAfterAlarm) min")
                            .font(.caption.monospacedDigit())
                            .frame(width: 60, alignment: .leading)
                            .foregroundStyle(.orange)
                        Image(systemName: level.action.systemImage)
                            .frame(width: 24)
                            .foregroundStyle(.red)
                        Text(level.action.displayName)
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            Text("You can customize these later in alarm settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
            nextButton { vm.completeParentStep(.setEscalation) }
        }
        .padding()
    }

    private var pairDeviceStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Pair Child's Device")
                .font(.title2.bold())

            if let child = parentVM.children.last, let code = child.pairingCode {
                Text("Enter this code on your child's device:")
                    .foregroundStyle(.secondary)

                Text(code)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .tracking(8)
                    .padding()
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            }

            Spacer()
            nextButton(label: "Done Pairing") { vm.completeParentStep(.pairDevice) }
        }
        .padding()
    }

    private var testAlarmStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.and.waves.left.and.right")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .symbolEffect(.bounce, options: .repeating)

            Text("Test the Alarm")
                .font(.title2.bold())

            Text("Send a test notification to your child's device to make sure everything is working.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                // Fire a local test notification
                let content = UNMutableNotificationContent()
                content.title = "Test Alarm"
                content.body = "This is a test! Your alarm is configured and ready."
                content.sound = .defaultCritical
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
                let request = UNNotificationRequest(identifier: "test-alarm", content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request)
            } label: {
                Label("Send Test Notification", systemImage: "bell.badge")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Spacer()
            nextButton(label: "Continue") { vm.completeParentStep(.testAlarm) }
        }
        .padding()
    }

    private var completeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            Text("All Set!")
                .font(.title.bold())
            Text("The alarm will fire at the configured time. You'll receive notifications about your child's progress.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Go to Dashboard") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
    }

    // MARK: - Helpers

    private func nextButton(label: String = "Next", disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(disabled)
    }
}
