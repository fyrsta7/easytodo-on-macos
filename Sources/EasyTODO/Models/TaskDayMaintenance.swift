import Foundation
import SwiftData

enum TaskDayMaintenance {
    @MainActor
    static func copyUnfinishedTasksToToday(
        in context: ModelContext,
        today: Date? = nil,
        calendar: Calendar = .current,
        now: Date = .now
    ) throws -> Bool {
        let tasks = try context.fetch(FetchDescriptor<TodoTask>())
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
                !task.isCompleted && task.repeatRule == .none && task.carriedForwardDate == nil
                    && task.scheduledDay(in: calendar) < todayStart
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
            let copy = TodoTask(
                title: task.title,
                sortOrder: nextSortOrder,
                createdAt: now,
                scheduledDate: todayStart,
                priority: task.priority
            )
            context.insert(copy)
            // Save the marker and copy together. Past content, completion, date, and order stay intact.
            task.carriedForwardDate = todayStart
            nextSortOrder += 1
            didChange = true
        }

        if didChange || context.hasChanges {
            try context.save()
        }

        return didChange
    }
}
