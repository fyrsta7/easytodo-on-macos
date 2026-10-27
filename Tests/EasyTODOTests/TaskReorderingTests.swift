import AppKit
import SwiftData
import SwiftUI
import XCTest
@testable import EasyTODO

@MainActor
final class TaskReorderingTests: XCTestCase {
    func testTasksMoveUpAndDownWithinTheirColorWithoutChangingTaskDetails() {
        let red = TodoTask(title: "Red", priority: .importantUrgent)
        let first = TodoTask(title: "First green", sortOrder: 1)
        let second = TodoTask(title: "Second green", sortOrder: 2)
        let third = TodoTask(title: "Third green", sortOrder: 3)
        let tasks = [red, first, second, third]
        let originalDetails = tasks.map { [$0.title, $0.priority.rawValue, String($0.isCompleted), String($0.createdAt.timeIntervalSince1970)] }

        TaskListOrdering.moveTasks(from: IndexSet(integer: 3), to: 1, in: tasks)
        XCTAssertEqual(TaskListOrdering.ordered(tasks).map(\.title), ["Red", "Third green", "First green", "Second green"])
        TaskListOrdering.moveTasks(from: IndexSet(integer: 1), to: 4, in: tasks)
        XCTAssertEqual(TaskListOrdering.ordered(tasks).map(\.title), ["Red", "First green", "Second green", "Third green"])
        XCTAssertEqual(tasks.map { [$0.title, $0.priority.rawValue, String($0.isCompleted), String($0.createdAt.timeIntervalSince1970)] }, originalDetails)
    }

    func testDraggingAcrossGroupsKeepsColorPriorityAndCompletionGrouping() {
        let red = TodoTask(title: "Red", priority: .importantUrgent)
        let yellow = TodoTask(title: "Yellow", sortOrder: 1, priority: .urgentNotImportant)
        let green = TodoTask(title: "Green", sortOrder: 2)
        let doneRed = TodoTask(title: "Done red", isCompleted: true, sortOrder: 3, priority: .importantUrgent)
        let doneGreen = TodoTask(title: "Done green", isCompleted: true, sortOrder: 4)
        let tasks = [red, yellow, green, doneRed, doneGreen]
        TaskListOrdering.moveTasks(from: IndexSet(integer: 2), to: 0, in: tasks)
        XCTAssertEqual(TaskListOrdering.ordered(tasks).map(\.title), ["Red", "Yellow", "Green", "Done red", "Done green"])
        TaskListOrdering.moveTasks(from: IndexSet(integer: 4), to: 0, in: tasks)
        XCTAssertEqual(TaskListOrdering.ordered(tasks).map(\.title), ["Red", "Yellow", "Green", "Done red", "Done green"])
        XCTAssertTrue(doneGreen.isCompleted)
    }

    func testManualOrderPersistsAcrossRelaunchWithoutReorderingOtherDays() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("EasyTODOReorder-\(UUID().uuidString)")
        let store = directory.appendingPathComponent("EasyTODO.store")
        defer { try? FileManager.default.removeItem(at: directory) }
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: .now))
        do {
            let container = try PersistenceController.modelContainer(storeURL: store)
            let context = container.mainContext
            let first = TodoTask(title: "First green", sortOrder: 5)
            let second = TodoTask(title: "Second green", sortOrder: 9)
            let future = TodoTask(title: "Tomorrow", sortOrder: 42, scheduledDate: tomorrow)
            for task in [first, second, future] { context.insert(task) }
            TaskListOrdering.moveTasks(from: IndexSet(integer: 1), to: 0, in: [first, second])
            try context.save()
        }
        let reopened = try PersistenceController.modelContainer(storeURL: store)
        let tasks = try reopened.mainContext.fetch(FetchDescriptor<TodoTask>())
        XCTAssertEqual(TaskListOrdering.ordered(tasks.filter { $0.isScheduled(on: TaskDayBoundary.current.day()) }).map(\.title), ["Second green", "First green"])
        XCTAssertEqual(tasks.first { $0.title == "Tomorrow" }?.sortOrder, 42)
    }

    func testMenuBarExposesNativeDragReorderingForVisibleTasks() throws {
        _ = NSApplication.shared
        let container = try PersistenceController.modelContainer(inMemory: true)
        for (index, title) in ["First", "Second", "Third"].enumerated() {
            container.mainContext.insert(TodoTask(title: title, sortOrder: index))
        }
        try container.mainContext.save()
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 300, height: 360),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: MenuBarTodoView().modelContainer(container))
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        let deadline = Date().addingTimeInterval(1)
        while tables(in: host).first?.numberOfRows != 3 && Date() < deadline {
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        let table = try XCTUnwrap(tables(in: host).first)
        XCTAssertEqual(table.numberOfRows, 3)
        XCTAssertFalse(table.registeredDraggedTypes.isEmpty, "The menu list must accept native row dragging")
    }

    private func tables(in view: NSView) -> [NSTableView] {
        if let table = view as? NSTableView { return [table] }
        return view.subviews.flatMap { tables(in: $0) }
    }
}
