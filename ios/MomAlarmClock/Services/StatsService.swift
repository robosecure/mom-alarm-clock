import Foundation

/// Computes real statistics from session and tamper event history.
/// Replaces the placeholder zeros in ChildProfile.Stats.
enum StatsService {

    /// Recomputes all stats from session and tamper event history.
    static func computeStats(
        sessions: [MorningSession],
        tamperEvents: [TamperEvent]
    ) -> ChildProfile.Stats {
        let completedSessions = sessions.filter { $0.state == .verified }
        let onTimeSessions = completedSessions.filter(\.wasOnTime)
        let failedSessions = sessions.filter { $0.state == .failed }

        let streak = computeStreak(sessions: completedSessions)
        let bestStreak = computeBestStreak(sessions: completedSessions)
        let averageMinutes = computeAverageWakeMinutes(sessions: completedSessions)
        let points = computeRewardPoints(sessions: sessions, tamperEvents: tamperEvents)

        return ChildProfile.Stats(
            currentStreak: streak,
            bestStreak: max(bestStreak, streak),
            onTimeCount: onTimeSessions.count,
            lateCount: failedSessions.count + completedSessions.filter({ !$0.wasOnTime }).count,
            tamperEventCount: tamperEvents.count,
            averageWakeMinutes: averageMinutes,
            rewardPoints: points
        )
    }

    /// Consecutive days ending today where the child verified on time.
    static func computeStreak(sessions: [MorningSession]) -> Int {
        let calendar = Calendar.current
        let sorted = sessions
            .filter(\.wasOnTime)
            .sorted { $0.alarmFiredAt > $1.alarmFiredAt }

        var streak = 0
        var expectedDate = calendar.startOfDay(for: .now)

        for session in sorted {
            let sessionDay = calendar.startOfDay(for: session.alarmFiredAt)
            if sessionDay == expectedDate {
                streak += 1
                guard let nextDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) else {
                    // Calendar math edge case — stop walking backwards rather than crash
                    break
                }
                expectedDate = nextDate
            } else if sessionDay < expectedDate {
                break
            }
            // Skip multiple sessions on the same day
        }
        return streak
    }

    /// Best-ever consecutive on-time streak.
    static func computeBestStreak(sessions: [MorningSession]) -> Int {
        let calendar = Calendar.current
        let sorted = sessions
            .filter(\.wasOnTime)
            .sorted { $0.alarmFiredAt < $1.alarmFiredAt }

        guard !sorted.isEmpty else { return 0 }

        var best = 1
        var current = 1
        var lastDay = calendar.startOfDay(for: sorted[0].alarmFiredAt)

        for session in sorted.dropFirst() {
            let day = calendar.startOfDay(for: session.alarmFiredAt)
            if day == lastDay { continue } // same day

            guard let nextExpected = calendar.date(byAdding: .day, value: 1, to: lastDay) else {
                // Edge case: calendar overflow. Restart the current streak at this day.
                current = 1
                lastDay = day
                continue
            }
            if day == nextExpected {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
            lastDay = day
        }
        return best
    }

    /// Average minutes from alarm fire to verification.
    static func computeAverageWakeMinutes(sessions: [MorningSession]) -> Double {
        let durations = sessions.compactMap(\.wakeUpDuration)
        guard !durations.isEmpty else { return 0 }
        let totalMinutes = durations.reduce(0.0) { $0 + $1 / 60.0 }
        return totalMinutes / Double(durations.count)
    }

    /// Total reward points earned minus tamper penalties.
    static func computeRewardPoints(
        sessions: [MorningSession],
        tamperEvents: [TamperEvent]
    ) -> Int {
        var points = 0

        // Points per session
        for session in sessions where session.state == .verified {
            // On-time bonus
            if session.wasOnTime {
                points += 10
            }
            // No-snooze bonus
            if session.snoozeCount == 0 {
                points += 5
            }
        }

        // Streak bonuses (based on consecutive on-time days)
        let streak = computeStreak(sessions: sessions.filter { $0.state == .verified })
        if streak >= 3 { points += 25 }
        if streak >= 7 { points += 75 }
        if streak >= 14 { points += 150 }
        if streak >= 30 { points += 300 }

        // Tamper penalties
        for event in tamperEvents {
            points += event.effectiveConsequence.pointsImpact // negative values subtract
        }

        return max(0, points)
    }
}
