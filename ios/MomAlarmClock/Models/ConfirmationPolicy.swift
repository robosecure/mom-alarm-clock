import Foundation

/// Determines how a morning session is confirmed after the child completes verification.
/// Set per-alarm by the parent.
enum ConfirmationPolicy: Codable, Sendable, Equatable {
    /// Session auto-completes once verification passes. Parent is notified but no action required.
    case autoAcknowledge

    /// Session stays in `.pendingParentReview` until the parent explicitly approves or denies.
    case requireParentApproval

    /// Session auto-completes, but parent has a window (in minutes) to retroactively flag or escalate.
    case hybrid(windowMinutes: Int)

    /// Default policy for new alarms.
    static let `default`: ConfirmationPolicy = .hybrid(windowMinutes: 30)

    /// Human-readable name for UI display.
    var displayName: String {
        switch self {
        case .autoAcknowledge:
            "Trust Mode"
        case .requireParentApproval:
            "Approval Required"
        case .hybrid(let minutes):
            "Auto + \(minutes)min Review"
        }
    }

    var description: String {
        switch self {
        case .autoAcknowledge:
            "Alarm clears when your child verifies. You get notified but don't need to act."
        case .requireParentApproval:
            "Your child waits until you approve. Best for building the habit."
        case .hybrid(let minutes):
            "Clears automatically, but you can review and deny within \(minutes) minutes."
        }
    }
}
