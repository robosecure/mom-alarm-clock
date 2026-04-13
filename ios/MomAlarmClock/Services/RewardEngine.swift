import Foundation

/// Centralized, testable reward calculation.
/// All point/streak changes flow through here for consistency.
/// Rubric version 1 — stored on each session for future migration.
enum RewardEngine {

    static let rubricVersion = 1

    /// Outcome of a single session's reward calculation.
    struct SessionReward: Equatable, Sendable {
        let pointsDelta: Int
        let streakDelta: Int
        let reasonCodes: [String]
        let reason: String

        static let zero = SessionReward(pointsDelta: 0, streakDelta: 0, reasonCodes: [], reason: "No change")
    }

    // MARK: - Rubric Constants

    static let onTimeFirstTryPoints = 15
    static let onTimeWithRetriesPoints = 10
    static let lateVerifiedPoints = 5
    static let noSnoozeBonus = 5
    static let escalatedPointsPenalty = -25
    static let streakBonus3 = 25
    static let streakBonus7 = 75
    static let streakBonus14 = 150

    // MARK: - Session Reward Calculation

    /// Calculates the reward for a completed session.
    /// Uses verificationAttempts (not denialCount) to determine first-try.
    static func calculate(session: MorningSession) -> SessionReward {
        switch session.state {
        case .verified:
            let isFirstTry = session.verificationAttempts <= 1
            let wasOnTime = session.wasOnTime
            let noSnooze = session.snoozeCount == 0

            var points = 0
            var reasons: [String] = []
            var codes: [String] = []

            if wasOnTime && isFirstTry {
                points += onTimeFirstTryPoints
                reasons.append("+\(onTimeFirstTryPoints) on-time first try")
                codes.append("on_time_first_try")
            } else if wasOnTime {
                points += onTimeWithRetriesPoints
                reasons.append("+\(onTimeWithRetriesPoints) on-time after retries")
                codes.append("on_time_retries")
            } else {
                points += lateVerifiedPoints
                reasons.append("+\(lateVerifiedPoints) verified (late)")
                codes.append("late_verified")
            }

            if noSnooze {
                points += noSnoozeBonus
                reasons.append("+\(noSnoozeBonus) no-snooze bonus")
                codes.append("no_snooze_bonus")
            }

            if wasOnTime {
                codes.append("streak_eligible")
            }

            return SessionReward(
                pointsDelta: points,
                streakDelta: wasOnTime ? 1 : 0,
                reasonCodes: codes,
                reason: reasons.joined(separator: ", ")
            )

        case .failed:
            if case .escalated = session.parentAction {
                return SessionReward(
                    pointsDelta: escalatedPointsPenalty,
                    streakDelta: 0,
                    reasonCodes: ["escalated"],
                    reason: "\(escalatedPointsPenalty) escalated"
                )
            }
            return SessionReward(pointsDelta: 0, streakDelta: 0, reasonCodes: ["failed"], reason: "Session failed")

        default:
            return .zero
        }
    }

    /// Calculates streak bonus points for reaching milestones.
    static func streakBonus(currentStreak: Int) -> Int {
        var bonus = 0
        if currentStreak == 3 { bonus += streakBonus3 }
        if currentStreak == 7 { bonus += streakBonus7 }
        if currentStreak == 14 { bonus += streakBonus14 }
        return bonus
    }

    /// Applies a session reward to a child profile's stats in place.
    static func apply(_ reward: SessionReward, to stats: inout ChildProfile.Stats, currentStreak: Int) {
        stats.rewardPoints = max(0, stats.rewardPoints + reward.pointsDelta)

        if reward.streakDelta > 0 {
            stats.currentStreak += reward.streakDelta
            stats.bestStreak = max(stats.bestStreak, stats.currentStreak)
            let bonus = streakBonus(currentStreak: stats.currentStreak)
            if bonus > 0 {
                stats.rewardPoints += bonus
            }
        }
    }
}
