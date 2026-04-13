import Foundation
import UserNotifications

/// Tracks onboarding progress for both parent and child setup flows.
/// Each step must be completed (or explicitly skipped) before the user can proceed.
@Observable
final class SetupWizardViewModel {
    // MARK: - Steps

    enum ParentStep: Int, CaseIterable, Identifiable {
        case welcome
        case createChild
        case configureAlarm
        case chooseVerification
        case setEscalation
        case pairDevice
        case testAlarm
        case complete

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .welcome:            "Welcome"
            case .createChild:        "Add Your Child"
            case .configureAlarm:     "Set Alarm Time"
            case .chooseVerification: "Verification Method"
            case .setEscalation:      "Escalation Rules"
            case .pairDevice:         "Pair Child's Device"
            case .testAlarm:          "Test Alarm"
            case .complete:           "All Set!"
            }
        }

        var description: String {
            switch self {
            case .welcome:            "Learn how Mom Alarm Clock keeps your family on schedule."
            case .createChild:        "Enter your child's name and age."
            case .configureAlarm:     "Set the wake-up time and which days the alarm is active."
            case .chooseVerification: "Pick how your child proves they're out of bed."
            case .setEscalation:      "Configure what happens if they don't get up on time."
            case .pairDevice:         "Enter the pairing code on your child's device."
            case .testAlarm:          "Send a test alarm to make sure everything works."
            case .complete:           "You're ready to go. The alarm will fire tomorrow morning."
            }
        }
    }

    enum ChildStep: Int, CaseIterable, Identifiable {
        case welcome
        case enterPairingCode
        case grantNotifications
        case grantFamilyControls
        case grantLocation
        case grantMotion
        case testAlarm
        case complete

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .welcome:              "Welcome"
            case .enterPairingCode:     "Pair with Parent"
            case .grantNotifications:   "Allow Notifications"
            case .grantFamilyControls:  "Screen Time Access"
            case .grantLocation:        "Location Access"
            case .grantMotion:          "Motion Access"
            case .testAlarm:            "Test Alarm"
            case .complete:             "All Set!"
            }
        }

        var isPermissionStep: Bool {
            switch self {
            case .grantNotifications, .grantFamilyControls, .grantLocation, .grantMotion:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - State

    var currentParentStep: ParentStep = .welcome
    var currentChildStep: ChildStep = .welcome
    var completedParentSteps: Set<ParentStep> = []
    var completedChildSteps: Set<ChildStep> = []

    /// Temporary state for data collected during the wizard.
    var childName: String = ""
    var childAge: Int = 10
    var pairingCode: String = ""
    var selectedVerification: VerificationMethod = .qr
    var alarmHour: Int = 7
    var alarmMinute: Int = 0
    var selectedDays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri

    // MARK: - Navigation

    var parentProgress: Double {
        guard !ParentStep.allCases.isEmpty else { return 0 }
        return Double(completedParentSteps.count) / Double(ParentStep.allCases.count)
    }

    var childProgress: Double {
        guard !ChildStep.allCases.isEmpty else { return 0 }
        return Double(completedChildSteps.count) / Double(ChildStep.allCases.count)
    }

    func completeParentStep(_ step: ParentStep) {
        completedParentSteps.insert(step)
        if let next = ParentStep(rawValue: step.rawValue + 1) {
            currentParentStep = next
        }
    }

    func completeChildStep(_ step: ChildStep) {
        completedChildSteps.insert(step)
        if let next = ChildStep(rawValue: step.rawValue + 1) {
            currentChildStep = next
        }
    }

    func goBackParent() {
        if let prev = ParentStep(rawValue: currentParentStep.rawValue - 1) {
            currentParentStep = prev
        }
    }

    func goBackChild() {
        if let prev = ChildStep(rawValue: currentChildStep.rawValue - 1) {
            currentChildStep = prev
        }
    }

    var isParentComplete: Bool {
        completedParentSteps.contains(.complete)
    }

    var isChildComplete: Bool {
        completedChildSteps.contains(.complete)
    }

    // MARK: - Child Pairing Actions

    /// Pair the child device with the parent's family using the entered code.
    func pairChild(auth: AuthService) async throws {
        guard !pairingCode.isEmpty else { return }
        try await auth.pairAsChild(familyCode: pairingCode, displayName: childName)
    }

    /// Request notification permission (critical for alarms).
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(
            options: [.alert, .sound, .badge, .criticalAlert]
        )
        return granted ?? false
    }
}
