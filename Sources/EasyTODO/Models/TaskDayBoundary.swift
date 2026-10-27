import Foundation

/// Maps an instant to a task date. Stored/explicit task dates remain calendar dates.
struct TaskDayBoundary {
    static let defaultMinutes = 0
    let minutes: Int

    init(minutes: Int) {
        self.minutes = min(max(minutes, 0), 1439)
    }

    static func saved(in defaults: UserDefaults = .standard) -> TaskDayBoundary {
        TaskDayBoundary(minutes: defaults.integer(forKey: EasyTODOSettings.dayBoundaryMinutes))
    }

    static var current: TaskDayBoundary { saved() }

    func day(containing instant: Date = .now, calendar: Calendar = .current) -> Date {
        let calendarDay = calendar.startOfDay(for: instant)
        if instant < boundary(on: calendarDay, calendar: calendar) {
            return calendar.date(byAdding: .day, value: -1, to: calendarDay)!
        }
        return calendarDay
    }

    func nextBoundary(after instant: Date, calendar: Calendar = .current) -> Date {
        let calendarDay = calendar.startOfDay(for: instant)
        let todayBoundary = boundary(on: calendarDay, calendar: calendar)
        if instant < todayBoundary { return todayBoundary }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendarDay)!
        return boundary(on: tomorrow, calendar: calendar)
    }

    private func boundary(on day: Date, calendar: Calendar) -> Date {
        // Use wall-clock time rather than subtracting hours: DST days need not be 24 hours.
        // A skipped time uses the next valid time; a repeated time uses its first occurrence.
        calendar.date(
            bySettingHour: minutes / 60, minute: minutes % 60, second: 0,
            of: day, matchingPolicy: .nextTime, repeatedTimePolicy: .first
        )!
    }
}
