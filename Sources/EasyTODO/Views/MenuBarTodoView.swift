import Foundation
import SwiftData
import SwiftUI

struct MenuBarTodoView: View {
    @AppStorage(EasyTODOSettings.textScale) private var textScale = TextSize.defaultScale
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor(\TodoTask.sortOrder),
        SortDescriptor(\TodoTask.createdAt)
    ]) private var tasks: [TodoTask]

    @State private var isQuickAddPresented = false
    @State private var taskPendingDeletion: TodoTask?
    @State private var hoveredTaskID: PersistentIdentifier?

    private let calendar = Calendar.current
    private let dayRefreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var todayTasks: [TodoTask] {
        tasks.filter { task in
            task.isScheduled(on: .now, calendar: calendar)
        }
    }

    private var completedCount: Int {
        todayTasks.filter(\.isCompleted).count
    }

    private var orderedTasks: [TodoTask] {
        TaskListOrdering.ordered(todayTasks)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today")
                    .font(.system(size: TextSize.scaled(13, by: textScale), weight: .semibold))

                Spacer()

                Text("\(completedCount) / \(todayTasks.count)")
                    .font(.system(size: TextSize.scaled(11, by: textScale)))
                    .foregroundStyle(.secondary)

                Button(action: showQuickAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add task")
                .popover(isPresented: $isQuickAddPresented, arrowEdge: .top) {
                    HeaderQuickAddPopover(
                        onSubmit: addTask,
                        onCancel: dismissQuickAdd
                    )
                }
            }

            Divider()

            if todayTasks.isEmpty {
                Text("No tasks yet")
                    .font(.system(size: TextSize.scaled(13, by: textScale)))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                List {
                    ForEach(orderedTasks) { task in
                        menuTaskRow(task)
                            .padding(.vertical, 3)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 2))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onMove(perform: moveTasks)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, titleHeight + 6)
                .frame(height: taskListHeight)
                .scrollIndicators(.automatic)
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    MenuBarManager.shared.closePopover()
                    WidgetWindowManager.shared.toggleWidget()
                } label: {
                    Label("Widget", systemImage: "rectangle.on.rectangle")
                }
                .buttonStyle(.bordered)

                Button {
                    MenuBarManager.shared.closePopover()
                    WindowManager.shared.showMainWindow()
                } label: {
                    Label("Full App", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
            }
            .labelStyle(.titleAndIcon)
            .controlSize(.small)
            .font(.system(size: TextSize.scaled(11, by: textScale)))

        }
        .padding(14)
        .frame(width: TextSize.panelDimension(260, scale: textScale))
        .contentShape(Rectangle())
        .onAppear(perform: runDailyTaskMaintenance)
        .onDisappear { hoveredTaskID = nil }
        .onReceive(dayRefreshTimer) { _ in
            runDailyTaskMaintenance()
        }
        .confirmationDialog(
            "Delete this task?",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deletePendingTask)
            Button("Cancel", role: .cancel) {
                taskPendingDeletion = nil
            }
        } message: {
            Text(confirmDeleteMessage)
        }
    }

    private var taskListHeight: CGFloat {
        min(CGFloat(orderedTasks.count) * (titleHeight + 6), TextSize.panelDimension(220, scale: textScale))
    }

    private var titleHeight: CGFloat {
        TextSize.rowHeight(baseFontSize: 13, scale: textScale)
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding {
            taskPendingDeletion != nil
        } set: { isPresented in
            if !isPresented {
                taskPendingDeletion = nil
            }
        }
    }

    private var confirmDeleteMessage: String {
        guard let taskPendingDeletion else {
            return "This task will be removed."
        }

        let title = taskPendingDeletion.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "This task will be removed." : "\"\(title)\" will be removed."
    }

    private func menuTaskRow(_ task: TodoTask) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: titleHeight)
                .contentShape(Rectangle())
                .accessibilityLabel("Drag to reorder")

            Button {
                toggleCompletion(for: task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? Color.accentColor : Color.secondary)
                    .frame(width: 24, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")

            FloatingTaskTitle(
                title: task.title,
                isCompleted: task.isCompleted,
                fontSize: TextSize.scaled(13, by: textScale),
                fontWeight: .regular,
                isHovered: hoveredTaskID == task.persistentModelID,
                onEdit: { title in
                    task.title = title
                    saveChanges()
                }
            )
            .frame(maxWidth: .infinity, minHeight: titleHeight)

            Button {
                requestDelete(task)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete task")
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active:
                if hoveredTaskID != task.persistentModelID {
                    hoveredTaskID = task.persistentModelID
                }
            case .ended:
                if hoveredTaskID == task.persistentModelID {
                    hoveredTaskID = nil
                }
            }
        }
    }

    private func moveTasks(from source: IndexSet, to destination: Int) {
        hoveredTaskID = nil
        TaskListOrdering.moveTasks(from: source, to: destination, in: todayTasks)
        saveChanges()
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Unable to save menu bar task change: \(error)")
        }
    }

    private func toggleCompletion(for task: TodoTask) {
        let wasCompleted = task.isCompleted
        task.isCompleted.toggle()

        if !wasCompleted && task.isCompleted {
            TaskListOrdering.moveCompletedTaskToFront(task, in: todayTasks)
        } else if wasCompleted && !task.isCompleted {
            TaskListOrdering.moveReactivatedTaskToEnd(task, in: todayTasks)
        }

        saveChanges()

        if !wasCompleted && task.isCompleted {
            CompletionFeedbackPlayer.playTaskCompletedSound()
        }
    }

    private func requestDelete(_ task: TodoTask) {
        taskPendingDeletion = task
    }

    private func deletePendingTask() {
        guard let taskPendingDeletion else { return }

        delete(taskPendingDeletion)
        self.taskPendingDeletion = nil
    }

    private func delete(_ task: TodoTask) {
        modelContext.delete(task)
        saveChanges()
    }

    private func showQuickAdd() {
        isQuickAddPresented = true
    }

    private func dismissQuickAdd() {
        isQuickAddPresented = false
    }

    private func addTask(title: String) -> Bool {
        do {
            return try TaskCreation.addTask(title: title, in: modelContext, calendar: calendar) != nil
        } catch {
            assertionFailure("Unable to save menu bar task: \(error)")
            return false
        }
    }

    private func runDailyTaskMaintenance() {
        if TaskDayMaintenance.rolloverUnfinishedTasksToToday(tasks, calendar: calendar) {
            saveChanges()
        }
    }
}
