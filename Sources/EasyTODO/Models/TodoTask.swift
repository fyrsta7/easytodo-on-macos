import Foundation
import SwiftData

@Model
final class TodoTask {
    var title: String
    var isCompleted: Bool
    var sortOrder: Int
    var createdAt: Date
    var scheduledDate: Date?
    var priorityRawValue: String?
    var repeatRuleRawValue: String?
    var recurrenceGroupID: String?
    // A historical entry can produce one successor, even if that successor is later deleted.
    var carriedForwardDate: Date?

    init(
        title: String,
        isCompleted: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        scheduledDate: Date? = nil,
        priority: TaskPriority = .notUrgentImportant,
        repeatRule: TaskRepeatRule = .none,
        recurrenceGroupID: String? = nil,
        carriedForwardDate: Date? = nil
    ) {
        self.title = title
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.scheduledDate = scheduledDate.map { Calendar.current.startOfDay(for: $0) }
            ?? TaskDayBoundary.current.day()
        self.priorityRawValue = priority.rawValue
        self.repeatRuleRawValue = repeatRule.rawValue
        self.recurrenceGroupID = recurrenceGroupID
        self.carriedForwardDate = carriedForwardDate
    }

    var priority: TaskPriority {
        get {
            TaskPriority.normalized(from: priorityRawValue)
        }
        set {
            priorityRawValue = newValue.rawValue
        }
    }

    var repeatRule: TaskRepeatRule {
        get {
            TaskRepeatRule.normalized(from: repeatRuleRawValue)
        }
        set {
            repeatRuleRawValue = newValue.rawValue
        }
    }

    func scheduledDay(in calendar: Calendar = .current) -> Date {
        scheduledDate.map { calendar.startOfDay(for: $0) }
            ?? TaskDayBoundary.current.day(calendar: calendar)
    }

    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(scheduledDay(in: calendar), inSameDayAs: date)
    }
}
