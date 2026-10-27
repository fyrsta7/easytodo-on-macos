import AppKit
import Observation
import SwiftData

/// Keeps every surface on the same task day, even with no tasks to trigger a query update.
@MainActor
@Observable
final class TaskDayClock {
    static let shared = TaskDayClock(observesChanges: true)

    private(set) var today: Date
    private(set) var nextRefreshDate: Date

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let observesChanges: Bool
    @ObservationIgnored private var modelContainer: ModelContainer?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = .now,
        observesChanges: Bool = false
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.observesChanges = observesChanges
        let boundary = TaskDayBoundary.saved(in: defaults)
        today = boundary.day(containing: now, calendar: calendar)
        nextRefreshDate = boundary.nextBoundary(after: now, calendar: calendar)
        if observesChanges { startObserving() }
    }

    func configure(modelContainer: ModelContainer, now: Date = .now) {
        self.modelContainer = modelContainer
        refresh(at: now, forceMaintenance: true)
    }

    func refresh(at now: Date = .now, forceMaintenance: Bool = false) {
        let boundary = TaskDayBoundary.saved(in: defaults)
        let newDay = boundary.day(containing: now, calendar: calendar)
        let dayChanged = newDay != today
        today = newDay
        nextRefreshDate = boundary.nextBoundary(after: now, calendar: calendar)

        if let modelContainer, dayChanged || forceMaintenance {
            do {
                _ = try TaskDayMaintenance.copyUnfinishedTasksToToday(
                    in: modelContainer.mainContext, today: newDay, calendar: calendar, now: now
                )
            } catch {
                NSLog("EasyTODO failed to refresh task day: \(error)")
            }
        }

        if observesChanges { scheduleRefresh() }
    }

    private func startObserving() {
        for name in [UserDefaults.didChangeNotification, NSApplication.didBecomeActiveNotification,
                     Notification.Name.NSSystemClockDidChange, Notification.Name.NSSystemTimeZoneDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        scheduleRefresh()
    }

    private func scheduleRefresh() {
        timer?.invalidate()
        let timer = Timer(fire: nextRefreshDate, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}
