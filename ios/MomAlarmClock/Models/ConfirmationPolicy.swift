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
            "Auto-Acknowledge"
        case .requireParentApproval:
            "Require Parent Approval"
        case .hybrid(let minutes):
            "Auto + \(minutes)min Review Window"
        }
    }

    var description: String {
        switch self {
        case .autoAcknowledge:
            "The alarm clears as soon as your child completes verification. You'll be notified but don't need to act."
        case .requireParentApproval:
            "Your child's device stays locked until you review and approve their verification."
        case .hybrid(let minutes):
            "The alarm clears automatically, but you have \(minutes) minutes to review and flag if needed."
        }
    }
}
