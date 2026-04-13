import Foundation

/// Consequence applied when a tamper event is detected.
/// Consequences carry forward to the next morning's alarm session.
struct TamperConsequence: Codable, Sendable, Equatable {
    /// How many days the current streak is reduced (negative = reduce, 0 = no change).
    var streakImpact: Int

    /// Points added or removed (negative = penalty).
    var pointsImpact: Int

    /// Whether the next morning's verification tier is escalated one level.
    var escalateVerificationTier: Bool

    /// Human-readable explanation shown to the parent.
    var description: String

    // MARK: - Presets by Tamper Type

    static func defaultConsequence(for type: TamperEvent.TamperType) -> TamperConsequence {
        switch type {
        case .volumeLowered:
            TamperConsequence(
                streakImpact: 0,
                pointsImpact: -5,
                escalateVerificationTier: false,
                description: "Volume was lowered during alarm. Minor penalty applied."
            )
        case .notificationsDisabled:
            TamperConsequence(
                streakImpact: -1,
                pointsImpact: -15,
                escalateVerificationTier: true,
                description: "Notification permissions were revoked. Streak reduced, harder verification tomorrow."
            )
        case .networkLost:
            TamperConsequence(
                streakImpact: 0,
                pointsImpact: -10,
                escalateVerificationTier: false,
                description: "Network connectivity was lost during alarm. Points penalty applied."
            )
        case .timeZoneChanged:
            TamperConsequence(
                streakImpact: -1,
                pointsImpact: -15,
                escalateVerificationTier: true,
                description: "System time was changed. Streak reduced, harder verification tomorrow."
            )
        }
    }
}
