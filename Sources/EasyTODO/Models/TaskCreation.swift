import Foundation
import SwiftData

enum TaskCreation {
    @MainActor
    static func addTask(
        title: String,
        scheduledDate: Date? = nil,
        in context: ModelContext,
        calendar: Calendar = .current,
        now: Date = .now,
        dayBoundary: TaskDayBoundary = .current
    ) throws -> TodoTask? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }

        let scheduledDate = scheduledDate ?? dayBoundary.day(containing: now, calendar: calendar)

        let tasks = try context.fetch(FetchDescriptor<TodoTask>())
        let dayTasks = tasks.filter { task in
            task.isScheduled(on: scheduledDate, calendar: calendar)
        }
        let nextSortOrder = (dayTasks.map(\.sortOrder).max() ?? -1) + 1
        let task = TodoTask(title: trimmedTitle, sortOrder: nextSortOrder, scheduledDate: scheduledDate)

        context.insert(task)
        try context.save()

        return task
    }
}
