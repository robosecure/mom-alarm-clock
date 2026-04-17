import SwiftUI
import UserNotifications

/// Interactive onboarding checklist that guides the parent through
/// creating a child profile, configuring the first alarm, and pairing a device.
struct SetupWizardView: View {
    @Environment(ParentViewModel.self) private var parentVM
    @State private var vm = SetupWizardViewModel()
    @State private var wizardAlarmDate = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? .now
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
            Text("Add your child, set their wake-up time, and pair their device. It takes under 2 minutes.")
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

            Text("By adding a child, you confirm you are their parent or legal guardian and consent to the collection of their data as described in our Privacy Policy.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
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

            DatePicker("Wake-up time", selection: $wizardAlarmDate, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 150)

            // Defaults summary
            VStack(spacing: 8) {
                Label("Weekdays (Mon–Fri)", systemImage: "calendar")
                Label("Quiz verification", systemImage: "brain.head.profile")
                Label("Auto-completes when verified", systemImage: "checkmark.circle")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text("You can customize verification, difficulty, and snooze rules later in alarm settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
            nextButton {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: wizardAlarmDate)
                vm.alarmHour = comps.hour ?? 7
                vm.alarmMinute = comps.minute ?? 0
                vm.completeParentStep(.configureAlarm)
            }
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
                .symbolEffect(.pulse, options: .repeating)

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
            Text("The alarm will fire at the configured time. Your child verifies, and the alarm clears based on your confirmation policy. By default, you'll only be notified if something needs your attention.")
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
