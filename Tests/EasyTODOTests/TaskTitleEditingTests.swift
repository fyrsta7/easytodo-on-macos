import AppKit
import SwiftData
import SwiftUI
import XCTest
@testable import EasyTODO

@MainActor
final class TaskTitleEditingTests: XCTestCase {
    func testDoubleClickEditsAndSavesWithoutCompletingTaskInEverySurface() throws {
        _ = NSApplication.shared
        let container = try PersistenceController.modelContainer(inMemory: true)
        let task = TodoTask(title: "喝水")
        container.mainContext.insert(task)
        try container.mainContext.save()
        let originalOrder = task.sortOrder
        let originalDate = task.scheduledDate
        let suite = "EasyTODOTests.EditTitle.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        EasyTODOSettings.registerDefaults(in: defaults)
        let views = [
            AnyView(TaskRow(task: task, onUpdate: { try? container.mainContext.save() },
                            onCompletionChanged: { _, _, _ in XCTFail("Editing must not complete the task") }, onDelete: {})),
            AnyView(MenuBarTodoView()),
            AnyView(WidgetTodoView())
        ]
        for (index, view) in views.enumerated() {
            let frame = NSRect(x: -10000, y: -10000, width: 420, height: 360)
            let window: NSWindow = index == 2
                ? NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                : NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
            window.isMovableByWindowBackground = true
            let host = NSHostingView(rootView: view.modelContainer(container).defaultAppStorage(defaults))
            let menuPopover = NSPopover()
            if index == 1 {
                // Match the real status-item popover, including its transient parent behavior.
                let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 360))
                window.contentView = anchor
                window.makeKeyAndOrderFront(nil)
                let controller = NSViewController()
                controller.view = host
                menuPopover.contentViewController = controller
                menuPopover.behavior = .transient
                menuPopover.animates = false
                menuPopover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)
            } else {
                window.contentView = host
                window.makeKeyAndOrderFront(nil)
            }
            defer { menuPopover.close(); window.orderOut(nil) }
            waitUntil { !self.titleViews(in: host).isEmpty }
            let titleView = try XCTUnwrap(titleViews(in: host).first)
            XCTAssertFalse(titleView.mouseDownCanMoveWindow)
            let event = try XCTUnwrap(NSEvent.mouseEvent(
                with: .leftMouseDown, location: titleView.convert(.zero, to: nil), modifierFlags: [],
                timestamp: 0, windowNumber: window.windowNumber, context: nil,
                eventNumber: 0, clickCount: 2, pressure: 1
            ))
            titleView.mouseDown(with: event)
            let popover = try XCTUnwrap(titleView.editorPopover)
            defer { popover.close() }
            let editor = try XCTUnwrap(popover.contentViewController as? TaskTitleEditorController)
            waitUntil { editor.view.window?.firstResponder === editor.textView }
            XCTAssertTrue(popover.isShown)
            if index == 1 { XCTAssertTrue(menuPopover.isShown) }
            XCTAssertTrue(editor.view.window?.firstResponder === editor.textView)
            XCTAssertEqual(editor.textView.string, task.title)
            let changedTitle = "修改第 \(index) 条任务\n完整的第二行内容"
            editor.textView.string = changedTitle
            editor.save()
            XCTAssertEqual(task.title, changedTitle)
            XCTAssertFalse(popover.isShown)
            XCTAssertFalse(task.isCompleted)
            XCTAssertEqual(task.sortOrder, originalOrder)
            XCTAssertEqual(task.scheduledDate, originalDate)
            XCTAssertFalse(container.mainContext.hasChanges)
        }
    }

    func testContextEditRequestFocusesEditorAndDismissalDoesNotSaveDraft() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 400, height: 200),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let title = FloatingTaskTitleView(frame: NSRect(x: 10, y: 80, width: 250, height: 28))
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        host.addSubview(title)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { title.closeEditor(); window.orderOut(nil) }
        let handle = TaskTitleEditorHandle()
        handle.titleView = title
        title.update(title: "原任务", isCompleted: true, font: .systemFont(ofSize: 24),
                     isHovered: true, onEdit: { _ in XCTFail("Dismissal must not save") })
        handle.beginEditing()
        waitUntil { title.editorPopover != nil }
        let editor = try XCTUnwrap(title.editorPopover?.contentViewController as? TaskTitleEditorController)
        waitUntil { editor.view.window?.firstResponder === editor.textView }
        XCTAssertTrue(editor.view.window?.firstResponder === editor.textView)
        XCTAssertEqual(editor.textView.font?.pointSize, 24)
        XCTAssertFalse(window.childWindows?.contains { $0.contentView is NSBox } ?? false)
        editor.textView.string = "不保存的草稿"
        title.closeEditor()
        title.beginEditing()
        let reopened = try XCTUnwrap(title.editorPopover?.contentViewController as? TaskTitleEditorController)
        XCTAssertEqual(reopened.textView.string, "原任务")
    }

    func testReturnSavesOnceAndEscapeCancelsWithoutCommitting() {
        var saved: [String] = []
        var cancelled = 0
        let editor = TaskTitleEditorController(title: "原任务", font: .systemFont(ofSize: 15),
                                               onSave: { saved.append($0) }, onCancel: { cancelled += 1 })
        editor.loadViewIfNeeded()
        editor.textView.string = "  第一行\n第二行  "
        XCTAssertTrue(editor.textView(editor.textView, doCommandBy: #selector(NSResponder.insertNewline(_:))))
        editor.save()
        editor.cancel()
        XCTAssertEqual(saved, ["第一行\n第二行"])
        XCTAssertEqual(cancelled, 0)
        let cancelledEditor = TaskTitleEditorController(title: "原任务", font: .systemFont(ofSize: 15),
                                                        onSave: { saved.append($0) }, onCancel: { cancelled += 1 })
        cancelledEditor.loadViewIfNeeded()
        cancelledEditor.textView.string = "取消的修改"
        XCTAssertTrue(cancelledEditor.textView(cancelledEditor.textView, doCommandBy: #selector(NSResponder.cancelOperation(_:))))
        cancelledEditor.save()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(cancelled, 1)
    }

    func testBlankOrComposingTextCannotOverwriteTheTask() {
        var saved: [String] = []
        let editor = TaskTitleEditorController(title: "原任务", font: .systemFont(ofSize: 15),
                                               onSave: { saved.append($0) }, onCancel: {})
        editor.loadViewIfNeeded()
        editor.textView.string = "  \n  "
        editor.save()
        XCTAssertTrue(saved.isEmpty)
        editor.textView.setMarkedText("输入中", selectedRange: NSRange(location: 3, length: 0), replacementRange: NSRange(location: 0, length: 5))
        XCTAssertTrue(editor.textView.hasMarkedText())
        XCTAssertFalse(editor.textView(editor.textView, doCommandBy: #selector(NSResponder.insertNewline(_:))))
        editor.save()
        XCTAssertTrue(saved.isEmpty)
        editor.textView.unmarkText()
        editor.textView.string = "已完成输入"
        editor.save()
        XCTAssertEqual(saved, ["已完成输入"])
    }

    private func titleViews(in view: NSView) -> [FloatingTaskTitleView] {
        if let title = view as? FloatingTaskTitleView { return [title] }
        return view.subviews.flatMap { titleViews(in: $0) }
    }

    private func waitUntil(_ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(1)
        while !condition() && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
    }
}
