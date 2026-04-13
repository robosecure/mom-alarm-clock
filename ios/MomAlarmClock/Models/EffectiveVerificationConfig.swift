import Foundation

/// Merged verification configuration for a session.
/// Combines alarm schedule defaults with guardian's nextMorningOverrides.
/// Overrides win when present; schedule defaults fill the rest.
struct EffectiveVerificationConfig: Equatable, Sendable {
    let method: VerificationMethod
    let tier: VerificationTier
    let maxAttempts: Int
    let timerSeconds: Int
    let calmMode: Bool

    /// Derived quiz parameters from tier (can be overridden by timerSeconds).
    var quizQuestionCount: Int { tier.quizQuestionCount }
    var quizDifficulty: String { tier.quizDifficulty }
    var requiredSteps: Int { tier.requiredSteps }

    /// Merges schedule defaults with optional guardian overrides.
    /// Overrides take precedence when non-nil.
    static func merge(
        schedule: AlarmSchedule?,
        overrides: ChildProfile.NextMorningOverrides?,
        pendingTierEscalation: Bool
    ) -> EffectiveVerificationConfig {
        let baseTier = schedule?.verificationTier ?? .medium
        let effectiveTier = pendingTierEscalation ? baseTier.escalated : baseTier

        return EffectiveVerificationConfig(
            method: overrides?.verificationMethod ?? schedule?.primaryVerification ?? .quiz,
            tier: overrides?.tier ?? effectiveTier,
            maxAttempts: overrides?.maxAttempts ?? 3,
            timerSeconds: overrides?.timerSeconds ?? effectiveTier.quizTimeLimitSeconds,
            calmMode: overrides?.calmMode ?? false
        )
    }
}
