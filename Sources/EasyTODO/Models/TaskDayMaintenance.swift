import Foundation
import SwiftData

enum TaskDayMaintenance {
    @MainActor
    static func rolloverUnfinishedTasksToToday(
        in context: ModelContext,
        today: Date? = nil,
        calendar: Calendar = .current
    ) throws -> Bool {
        let tasks = try context.fetch(FetchDescriptor<TodoTask>())
        let didChange = rolloverUnfinishedTasksToToday(tasks, today: today, calendar: calendar)

        if didChange {
            try context.save()
        }

        return didChange
    }

    static func rolloverUnfinishedTasksToToday(
        _ tasks: [TodoTask],
        today: Date? = nil,
        calendar: Calendar = .current
    ) -> Bool {
        let todayStart = today.map { calendar.startOfDay(for: $0) }
            ?? TaskDayBoundary.current.day(calendar: calendar)
        var didChange = false
        for task in tasks where task.scheduledDate == nil {
            task.scheduledDate = todayStart
            didChange = true
        }
        var nextSortOrder = (tasks
            .filter { $0.isScheduled(on: todayStart, calendar: calendar) }
            .map(\.sortOrder)
            .max() ?? -1) + 1

        let overdueTasks = tasks
            .filter { task in
                !task.isCompleted && task.repeatRule == .none && task.scheduledDay(in: calendar) < todayStart
            }
            .sorted { lhs, rhs in
                let lhsDay = lhs.scheduledDay(in: calendar)
                let rhsDay = rhs.scheduledDay(in: calendar)

                if lhsDay != rhsDay {
                    return lhsDay < rhsDay
                }

                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }

                return lhs.createdAt < rhs.createdAt
            }

        for task in overdueTasks {
            task.scheduledDate = todayStart
            task.sortOrder = nextSortOrder
            nextSortOrder += 1
            didChange = true
        }

        return didChange
    }
}
