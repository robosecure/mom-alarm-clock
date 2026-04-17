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

    /// Default policy for new alarms — low-friction: child verifies, alarm clears, guardian
    /// is only pulled in when something goes wrong. Strict/hybrid available in Advanced settings.
    static let `default`: ConfirmationPolicy = .autoAcknowledge

    /// Human-readable name for UI display.
    var displayName: String {
        switch self {
        case .autoAcknowledge:
            "Trust Mode"
        case .requireParentApproval:
            "Strict Mode"
        case .hybrid(let minutes):
            "Review Window (\(minutes)min)"
        }
    }

    var description: String {
        switch self {
        case .autoAcknowledge:
            "Your child verifies and the alarm clears. You're only notified when something needs attention."
        case .requireParentApproval:
            "Your child waits for your approval every morning. Use if you want direct involvement."
        case .hybrid(let minutes):
            "Clears automatically, but you can review and override within \(minutes) minutes."
        }
    }
}
