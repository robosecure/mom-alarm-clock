import Foundation

/// Merged verification configuration for a session.
///
/// Precedence (highest wins):
///   1. Tomorrow overrides (guardian set for next morning only)
///   2. Explicit guardian alarm/schedule settings
///   3. Age band defaults (derived from child's age)
///   4. Hardcoded fallback defaults
///
/// This is the single merge point for all verification parameters.
struct EffectiveVerificationConfig: Equatable, Sendable {
    let method: VerificationMethod
    let tier: VerificationTier
    let maxAttempts: Int
    let timerSeconds: Int
    let calmMode: Bool
    let quizQuestionCount: Int
    let quizDifficulty: String
    let encouragementStyle: AgeContentProfile.EncouragementStyle

    /// Derived from tier (not age-influenced).
    var requiredSteps: Int { tier.requiredSteps }

    /// Merges schedule defaults with optional guardian overrides and age band defaults.
    /// Overrides > schedule > ageBand > hardcoded fallback.
    static func merge(
        schedule: AlarmSchedule?,
        overrides: ChildProfile.NextMorningOverrides?,
        pendingTierEscalation: Bool,
        ageBand: AgeBand? = nil
    ) -> EffectiveVerificationConfig {
        let baseTier = schedule?.verificationTier ?? .medium
        let effectiveTier = pendingTierEscalation ? baseTier.escalated : baseTier
        let resolvedTier = overrides?.tier ?? effectiveTier

        // Age content profile provides softer defaults when no guardian setting overrides.
        let ageProfile = ageBand?.contentProfile

        // Timer: overrides > schedule tier > age band > tier default
        let timerSeconds = overrides?.timerSeconds
            ?? (schedule != nil ? effectiveTier.quizTimeLimitSeconds : nil)
            ?? ageProfile?.verificationTimeoutSeconds
            ?? resolvedTier.quizTimeLimitSeconds

        // Quiz count: overrides > schedule tier > age band > tier default
        let quizCount = (schedule != nil ? effectiveTier.quizQuestionCount : nil)
            ?? ageProfile?.quizCount
            ?? resolvedTier.quizQuestionCount

        // Quiz difficulty: overrides > schedule tier > age band > tier default
        let quizDiff = (schedule != nil ? effectiveTier.quizDifficulty : nil)
            ?? ageProfile?.quizDifficulty.rawValue
            ?? resolvedTier.quizDifficulty

        return EffectiveVerificationConfig(
            method: overrides?.verificationMethod ?? schedule?.primaryVerification ?? .quiz,
            tier: resolvedTier,
            maxAttempts: overrides?.maxAttempts ?? 3,
            timerSeconds: timerSeconds,
            calmMode: overrides?.calmMode ?? false,
            quizQuestionCount: quizCount,
            quizDifficulty: quizDiff,
            encouragementStyle: ageProfile?.encouragementStyle ?? .supportive
        )
    }
}
