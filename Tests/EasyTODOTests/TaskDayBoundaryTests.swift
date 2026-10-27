import AppKit
import SwiftData
import SwiftUI
import XCTest
@testable import EasyTODO

@MainActor
final class TaskDayBoundaryTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func instant(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    func testFourAMChangesDateAtTheExactBoundary() {
        let boundary = TaskDayBoundary(minutes: 240)
        let yesterday = instant("2026-10-27T00:00:00+08:00")
        let today = instant("2026-10-28T00:00:00+08:00")
        for time in ["2026-10-28T00:00:00+08:00", "2026-10-28T03:59:59+08:00"] {
            XCTAssertEqual(boundary.day(containing: instant(time), calendar: calendar), yesterday)
        }
        for time in ["2026-10-28T04:00:00+08:00", "2026-10-28T23:59:59+08:00"] {
            XCTAssertEqual(boundary.day(containing: instant(time), calendar: calendar), today)
        }
        XCTAssertEqual(boundary.nextBoundary(after: instant("2026-10-28T03:59:59+08:00"), calendar: calendar),
                       instant("2026-10-28T04:00:00+08:00"))
        XCTAssertEqual(boundary.nextBoundary(after: instant("2026-10-28T04:00:00+08:00"), calendar: calendar),
                       instant("2026-10-29T04:00:00+08:00"))
    }

    func testMinutePrecisionAndMidnightCompatibility() {
        let time = instant("2026-10-28T04:29:59+08:00")
        XCTAssertEqual(TaskDayBoundary(minutes: 270).day(containing: time, calendar: calendar),
                       instant("2026-10-27T00:00:00+08:00"))
        XCTAssertEqual(TaskDayBoundary(minutes: 270).day(containing: time.addingTimeInterval(1), calendar: calendar),
                       instant("2026-10-28T00:00:00+08:00"))
        let midnight = instant("2026-10-28T00:00:00+08:00")
        XCTAssertEqual(TaskDayBoundary(minutes: 0).day(containing: midnight, calendar: calendar), midnight)
        XCTAssertEqual(TaskDayBoundary(minutes: 1439).day(containing: instant("2026-10-28T23:59:00+08:00"), calendar: calendar), midnight)
    }

    func testBoundaryHandlesYearAndLeapMonthChanges() {
        let boundary = TaskDayBoundary(minutes: 240)
        for (now, expected) in [("2027-01-01T03:00:00+08:00", "2026-12-31T00:00:00+08:00"),
                                ("2028-03-01T03:00:00+08:00", "2028-02-29T00:00:00+08:00")] {
            XCTAssertEqual(boundary.day(containing: instant(now), calendar: calendar), instant(expected))
        }
    }

    func testDaylightSavingUsesLocalFourAMOnShortAndLongDays() {
        var calendar = calendar
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let boundary = TaskDayBoundary(minutes: 240)
        for (before, dayStart, previousStart) in [
            ("2026-03-08T03:59:59-07:00", "2026-03-08T00:00:00-08:00", "2026-03-07T00:00:00-08:00"),
            ("2026-11-01T03:59:59-08:00", "2026-11-01T00:00:00-07:00", "2026-10-31T00:00:00-07:00")
        ] {
            let now = instant(before)
            XCTAssertEqual(boundary.day(containing: now, calendar: calendar), instant(previousStart))
            XCTAssertEqual(boundary.day(containing: now.addingTimeInterval(1), calendar: calendar), instant(dayStart))
        }
    }

    func testSkippedAndRepeatedBoundaryTimesDoNotSwitchBack() {
        var calendar = calendar
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let skipped = TaskDayBoundary(minutes: 150)
        XCTAssertEqual(skipped.nextBoundary(after: instant("2026-03-08T01:59:59-08:00"), calendar: calendar),
                       instant("2026-03-08T03:00:00-07:00"))
        let repeated = TaskDayBoundary(minutes: 90)
        let today = instant("2026-11-01T00:00:00-07:00")
        XCTAssertEqual(repeated.day(containing: instant("2026-11-01T01:30:00-07:00"), calendar: calendar), today)
        XCTAssertEqual(repeated.day(containing: instant("2026-11-01T01:10:00-08:00"), calendar: calendar), today)
    }

    func testBoundaryPersistsAndInvalidValuesAreClamped() throws {
        try withDefaults { defaults in
            EasyTODOSettings.registerDefaults(in: defaults)
            XCTAssertEqual(TaskDayBoundary.saved(in: defaults).minutes, 0)
            defaults.set(275, forKey: EasyTODOSettings.dayBoundaryMinutes)
            EasyTODOSettings.registerDefaults(in: defaults)
            XCTAssertEqual(TaskDayBoundary.saved(in: defaults).minutes, 275)
            for (saved, expected) in [(-10, 0), (2000, 1439)] {
                defaults.set(saved, forKey: EasyTODOSettings.dayBoundaryMinutes)
                EasyTODOSettings.registerDefaults(in: defaults)
                XCTAssertEqual(defaults.integer(forKey: EasyTODOSettings.dayBoundaryMinutes), expected)
            }
        }
    }

    func testQuickAddUsesTaskDayButExplicitCalendarDatesRemainExact() throws {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 3, minute: 59))!
        let boundary = TaskDayBoundary(minutes: 240)
        let yesterday = boundary.day(containing: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let container = try PersistenceController.modelContainer(inMemory: true)
        let context = container.mainContext
        let first = try XCTUnwrap(TaskCreation.addTask(title: "Before four", in: context, calendar: calendar,
                                                      now: now, dayBoundary: boundary))
        let second = try XCTUnwrap(TaskCreation.addTask(title: "Same task day", in: context, calendar: calendar,
                                                       now: now, dayBoundary: boundary))
        let explicit = try XCTUnwrap(TaskCreation.addTask(title: "Calendar date", scheduledDate: today,
                                                         in: context, calendar: calendar, now: now, dayBoundary: boundary))
        let after = try XCTUnwrap(TaskCreation.addTask(title: "After four", in: context, calendar: calendar,
                                                      now: now.addingTimeInterval(60), dayBoundary: boundary))
        XCTAssertEqual(first.scheduledDate, yesterday)
        XCTAssertEqual(second.scheduledDate, yesterday)
        XCTAssertEqual(second.sortOrder, first.sortOrder + 1)
        XCTAssertEqual(explicit.scheduledDate, today)
        XCTAssertEqual(after.scheduledDate, today)
        TaskScheduling.move(first, to: today, among: [first, second, explicit, after], calendar: calendar)
        XCTAssertEqual(first.scheduledDate, today)
    }

    func testRolloverWaitsForBoundaryAndPersistsOnlyUnfinishedNonRepeatingTasks() throws {
        try withDefaults { defaults in
            defaults.set(240, forKey: EasyTODOSettings.dayBoundaryMinutes)
            let calendar = Calendar.current
            let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 3, minute: 59))!
            let boundary = TaskDayBoundary(minutes: 240)
            let yesterday = boundary.day(containing: now, calendar: calendar)
            let today = calendar.startOfDay(for: now)
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = directory.appendingPathComponent("test.store")
            do {
                let container = try PersistenceController.modelContainer(storeURL: store)
                let context = container.mainContext
                let unfinished = TodoTask(title: "Carry", scheduledDate: yesterday)
                let completed = TodoTask(title: "Done", isCompleted: true, scheduledDate: yesterday)
                let recurring = TodoTask(title: "Repeat", scheduledDate: yesterday, repeatRule: .daily)
                let future = TodoTask(title: "Planned", scheduledDate: today)
                for task in [unfinished, completed, recurring, future] { context.insert(task) }
                try context.save()
                let clock = TaskDayClock(defaults: defaults, calendar: calendar, now: now)
                clock.configure(modelContainer: container, now: now)
                XCTAssertEqual(unfinished.scheduledDate, yesterday)
                clock.refresh(at: now.addingTimeInterval(60))
                XCTAssertEqual(unfinished.scheduledDate, today)
                XCTAssertEqual(completed.scheduledDate, yesterday)
                XCTAssertEqual(recurring.scheduledDate, yesterday)
                XCTAssertEqual(future.scheduledDate, today)
                let order = unfinished.sortOrder
                clock.refresh(at: now.addingTimeInterval(61), forceMaintenance: true)
                XCTAssertEqual(unfinished.sortOrder, order)
            }
            let reopened = try PersistenceController.modelContainer(storeURL: store)
            let tasks = try reopened.mainContext.fetch(FetchDescriptor<TodoTask>())
            XCTAssertEqual(tasks.first { $0.title == "Carry" }?.scheduledDate, today)
            XCTAssertEqual(tasks.first { $0.title == "Done" }?.scheduledDate, yesterday)
        }
    }

    func testClockRefreshesAfterSleepAndWhenSettingChangesWithoutAnyTasks() throws {
        try withDefaults { defaults in
            let now = instant("2026-10-28T02:00:00+08:00")
            let clock = TaskDayClock(defaults: defaults, calendar: calendar, now: now)
            XCTAssertEqual(clock.today, instant("2026-10-28T00:00:00+08:00"))
            defaults.set(240, forKey: EasyTODOSettings.dayBoundaryMinutes)
            clock.refresh(at: now)
            XCTAssertEqual(clock.today, instant("2026-10-27T00:00:00+08:00"))
            XCTAssertEqual(clock.nextRefreshDate, instant("2026-10-28T04:00:00+08:00"))
            clock.refresh(at: instant("2026-10-30T10:00:00+08:00"))
            XCTAssertEqual(clock.today, instant("2026-10-30T00:00:00+08:00"))
            XCTAssertEqual(clock.nextRefreshDate, instant("2026-10-31T04:00:00+08:00"))
        }
    }

    func testAllListsRefreshEvenWhenOnlyCompletedTasksExist() throws {
        _ = NSApplication.shared
        try withDefaults { defaults in
            defaults.set(240, forKey: EasyTODOSettings.dayBoundaryMinutes)
            let calendar = Calendar.current
            let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 3, minute: 59))!
            let clock = TaskDayClock(defaults: defaults, calendar: calendar, now: now)
            let container = try PersistenceController.modelContainer(inMemory: true)
            let yesterday = clock.today
            container.mainContext.insert(TodoTask(title: "Previous day", isCompleted: true, scheduledDate: yesterday))
            container.mainContext.insert(TodoTask(title: "Next day", isCompleted: true, scheduledDate: calendar.startOfDay(for: now)))
            try container.mainContext.save()
            for content in [AnyView(MenuBarTodoView(dayClock: clock)), AnyView(WidgetTodoView(dayClock: clock)),
                            AnyView(TodoListView(dayClock: clock))] {
                let host = NSHostingView(rootView: AnyView(content.modelContainer(container)))
                let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 400, height: 400),
                                      styleMask: [.titled], backing: .buffered, defer: false)
                window.contentView = host
                window.makeKeyAndOrderFront(nil)
                defer {
                    window.orderOut(nil)
                    // WindowManager retains the main test window. Release its query before the store.
                    host.rootView = AnyView(EmptyView())
                    window.contentView = nil
                    drainRunLoop()
                }
                drainRunLoop()
                clock.refresh(at: now)
                drainRunLoop()
                XCTAssertEqual(titleViews(in: host).compactMap { ($0.subviews.first as? NSTextField)?.stringValue }, ["Previous day"])
                clock.refresh(at: now.addingTimeInterval(60))
                drainRunLoop()
                XCTAssertEqual(titleViews(in: host).compactMap { ($0.subviews.first as? NSTextField)?.stringValue }, ["Next day"])
            }
        }
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "EasyTODOTests.DayBoundary.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    private func titleViews(in view: NSView) -> [FloatingTaskTitleView] {
        guard !view.isHiddenOrHasHiddenAncestor, view.alphaValue > 0 else { return [] }
        if let title = view as? FloatingTaskTitleView { return [title] }
        return view.subviews.flatMap { titleViews(in: $0) }
    }

    private func drainRunLoop() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
}
