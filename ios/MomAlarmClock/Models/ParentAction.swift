import Foundation

/// Action taken by the parent on a child's morning session after verification.
/// Part of the two-way confirmation protocol.
enum ParentAction: Codable, Sendable, Equatable {
    /// Parent approved the verification.
    case approved

    /// Parent denied the verification (child must re-verify or session escalates).
    case denied(reason: String)

    /// Parent manually escalated consequences.
    case escalated(reason: String)

    /// System auto-acknowledged (no parent action was required by policy).
    case autoAcknowledged

    var displayName: String {
        switch self {
        case .approved:         "Approved"
        case .denied:           "Denied"
        case .escalated:        "Escalated"
        case .autoAcknowledged: "Auto-Acknowledged"
        }
    }

    var isApproval: Bool {
        switch self {
        case .approved, .autoAcknowledged: true
        case .denied, .escalated: false
        }
    }
}
