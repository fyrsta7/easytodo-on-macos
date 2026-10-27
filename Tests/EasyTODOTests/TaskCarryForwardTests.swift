import SwiftData
import XCTest
@testable import EasyTODO

@MainActor
final class TaskCarryForwardTests: XCTestCase {
    private let calendar = Calendar.current

    private func day(_ offset: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 27 + offset))!
    }

    private func tasks(in context: ModelContext, on date: Date) throws -> [TodoTask] {
        try context.fetch(FetchDescriptor<TodoTask>()).filter { $0.isScheduled(on: date, calendar: calendar) }
    }

    func testOriginalDetailsStayIntactAndCopiesAreIndependent() throws {
        let container = try PersistenceController.modelContainer(inMemory: true)
        let context = container.mainContext
        let original = TodoTask(title: "Finish report", sortOrder: 7, createdAt: day(-1),
                                scheduledDate: day(0), priority: .importantUrgent)
        context.insert(original)
        try context.save()
        let originalID = original.persistentModelID

        XCTAssertTrue(try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(1), now: day(1)))
        let copy = try XCTUnwrap(tasks(in: context, on: day(1)).first)
        XCTAssertNotEqual(copy.persistentModelID, originalID)
        XCTAssertEqual(copy.title, original.title)
        XCTAssertEqual(copy.priority, .importantUrgent)
        XCTAssertFalse(copy.isCompleted)
        XCTAssertEqual(copy.createdAt, day(1))
        copy.title = "Revised report"
        copy.priority = .notUrgentImportant
        copy.isCompleted = true
        try context.save()

        XCTAssertEqual(original.persistentModelID, originalID)
        XCTAssertEqual(original.title, "Finish report")
        XCTAssertEqual(original.priority, .importantUrgent)
        XCTAssertFalse(original.isCompleted)
        XCTAssertEqual(original.scheduledDate, day(0))
        XCTAssertEqual(original.createdAt, day(-1))
        XCTAssertEqual(original.sortOrder, 7)
        XCTAssertFalse(try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(2)))
        XCTAssertTrue(try tasks(in: context, on: day(2)).isEmpty)
    }

    func testRepeatedRefreshAndRelaunchDoNotCreateDuplicateCopies() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appendingPathComponent("tasks.store")
        do {
            let container = try PersistenceController.modelContainer(storeURL: store)
            let context = container.mainContext
            context.insert(TodoTask(title: "Carry once", scheduledDate: day(0)))
            XCTAssertTrue(try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(1)))
            for _ in 0..<3 {
                XCTAssertFalse(try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(1)))
            }
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoTask>()), 2)
        }
        let reopened = try PersistenceController.modelContainer(storeURL: store)
        let context = reopened.mainContext
        XCTAssertFalse(try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(1)))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoTask>()), 2)
        XCTAssertEqual(try tasks(in: context, on: day(0)).first?.carriedForwardDate, day(1))
        XCTAssertNil(try tasks(in: context, on: day(1)).first?.carriedForwardDate)
    }

    func testConsecutiveDaysCopyOnlyTheLatestUnfinishedEntry() throws {
        let container = try PersistenceController.modelContainer(inMemory: true)
        let context = container.mainContext
        context.insert(TodoTask(title: "Keep going", scheduledDate: day(0)))
        for offset in 1...3 {
            XCTAssertTrue(try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(offset)))
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoTask>()), offset + 1)
            for past in 0...offset {
                let entries = try tasks(in: context, on: day(past))
                XCTAssertEqual(entries.count, 1)
                XCTAssertFalse(try XCTUnwrap(entries.first).isCompleted)
            }
        }
    }

    func testDeletingLatestCopyDoesNotResurrectHistoricalTasks() throws {
        let container = try PersistenceController.modelContainer(inMemory: true)
        let context = container.mainContext
        context.insert(TodoTask(title: "No longer needed", scheduledDate: day(0)))
        _ = try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(1))
        let copy = try XCTUnwrap(tasks(in: context, on: day(1)).first)
        context.delete(copy)
        try context.save()
        XCTAssertFalse(try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(1)))
        XCTAssertFalse(try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(2)))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoTask>()), 1)
    }

    func testUndoDeletePreservesHistoryMarkerAndActiveCopyCanContinue() throws {
        let container = try PersistenceController.modelContainer(inMemory: true)
        let context = container.mainContext
        let original = TodoTask(title: "Restore safely", scheduledDate: day(0))
        context.insert(original)
        _ = try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(1))
        let originalSnapshot = DeletedTaskSnapshot(task: original, calendar: calendar)
        context.delete(original)
        try context.save()
        context.insert(originalSnapshot.task())
        try context.save()
        XCTAssertFalse(try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(1)))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoTask>()), 2)

        let copy = try XCTUnwrap(tasks(in: context, on: day(1)).first)
        let copySnapshot = DeletedTaskSnapshot(task: copy, calendar: calendar)
        context.delete(copy)
        try context.save()
        context.insert(copySnapshot.task())
        try context.save()
        XCTAssertTrue(try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(2)))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoTask>()), 3)
    }

    func testMovingCopyToFutureDoesNotSpawnAnExtraTodayCopy() throws {
        let container = try PersistenceController.modelContainer(inMemory: true)
        let context = container.mainContext
        context.insert(TodoTask(title: "Plan later", scheduledDate: day(0)))
        _ = try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(1))
        let copy = try XCTUnwrap(tasks(in: context, on: day(1)).first)
        TaskScheduling.move(copy, to: day(4), among: try context.fetch(FetchDescriptor<TodoTask>()))
        try context.save()
        XCTAssertFalse(try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(2)))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoTask>()), 2)
    }

    func testMissedDaysAndChangingBoundaryBackwardsDoNotMultiplyCopies() throws {
        let container = try PersistenceController.modelContainer(inMemory: true)
        let context = container.mainContext
        context.insert(TodoTask(title: "After a break", scheduledDate: day(0)))
        _ = try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(4))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoTask>()), 2)
        for offset in 1...3 { XCTAssertTrue(try tasks(in: context, on: day(offset)).isEmpty) }
        XCTAssertFalse(try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(3)))
        XCTAssertFalse(try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(4)))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoTask>()), 2)
    }

    func testIdenticalTitlesRemainDistinctAndCopiesAppendInOriginalOrder() throws {
        let container = try PersistenceController.modelContainer(inMemory: true)
        let context = container.mainContext
        let first = TodoTask(title: "Same title", sortOrder: 3, scheduledDate: day(0), priority: .importantUrgent)
        let second = TodoTask(title: "Same title", sortOrder: 5, scheduledDate: day(0), priority: .notUrgentImportant)
        let existing = TodoTask(title: "Already planned", sortOrder: 10, scheduledDate: day(1))
        for task in [first, second, existing] { context.insert(task) }
        _ = try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(1))
        let copies = try tasks(in: context, on: day(1)).filter { $0.title == "Same title" }.sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(copies.count, 2)
        XCTAssertEqual(copies.map(\.sortOrder), [11, 12])
        XCTAssertEqual(copies.map(\.priority), [.importantUrgent, .notUrgentImportant])
        XCTAssertEqual(first.sortOrder, 3)
        XCTAssertEqual(second.sortOrder, 5)
    }

    func testExistingStoreMigratesWithoutChangingTaskDetails() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appendingPathComponent("legacy.store")
        do {
            let schema = Schema([PreviousTaskSchema.TodoTask.self])
            let configuration = ModelConfiguration("EasyTODO", schema: schema, url: store)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            container.mainContext.insert(PreviousTaskSchema.TodoTask(title: "Legacy task", date: day(0)))
            try container.mainContext.save()
        }
        let container = try PersistenceController.modelContainer(storeURL: store)
        let context = container.mainContext
        let original = try XCTUnwrap(context.fetch(FetchDescriptor<TodoTask>()).first)
        XCTAssertEqual(original.title, "Legacy task")
        XCTAssertEqual(original.scheduledDate, day(0))
        XCTAssertEqual(original.createdAt, day(0))
        XCTAssertEqual(original.sortOrder, 7)
        XCTAssertEqual(original.priorityRawValue, TaskPriority.importantUrgent.rawValue)
        XCTAssertFalse(original.isCompleted)
        XCTAssertNil(original.carriedForwardDate)
        XCTAssertFalse(try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(0)))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoTask>()), 1)
        XCTAssertTrue(try TaskDayMaintenance.copyUnfinishedTasksToToday(in: context, today: day(1)))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoTask>()), 2)
    }
}

// The pre-1.0.17 persistent model, used to exercise the real SQLite migration.
private enum PreviousTaskSchema {
    @Model final class TodoTask {
        var title: String
        var isCompleted: Bool
        var sortOrder: Int
        var createdAt: Date
        var scheduledDate: Date?
        var priorityRawValue: String?
        var repeatRuleRawValue: String?
        var recurrenceGroupID: String?

        init(title: String, date: Date) {
            self.title = title
            self.isCompleted = false
            self.sortOrder = 7
            self.createdAt = date
            self.scheduledDate = date
            self.priorityRawValue = TaskPriority.importantUrgent.rawValue
            self.repeatRuleRawValue = TaskRepeatRule.none.rawValue
        }
    }
}
