import Foundation

extension Date {
    /// Returns just the time portion as "h:mm a" (e.g., "7:30 AM").
    var timeString: String {
        formatted(date: .omitted, time: .shortened)
    }

    /// Returns a short date string like "Mon, Mar 15".
    var shortDateString: String {
        formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    /// Returns "Today", "Yesterday", or the short date string.
    var relativeDayString: String {
        if Calendar.current.isDateInToday(self) { return "Today" }
        if Calendar.current.isDateInYesterday(self) { return "Yesterday" }
        return shortDateString
    }

    /// Returns the start of the current day (midnight).
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Returns a date by adding the given number of days.
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    /// Returns the weekday (1 = Sunday ... 7 = Saturday).
    var weekday: Int {
        Calendar.current.component(.weekday, from: self)
    }

    /// Duration formatted as "Xm Ys" from a time interval.
    static func durationString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}
