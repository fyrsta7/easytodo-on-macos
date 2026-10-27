import AppKit
import SwiftData
import SwiftUI

struct TaskRow: View {
    @AppStorage(EasyTODOSettings.textScale) private var textScale = TextSize.defaultScale
    @Bindable var task: TodoTask
    var onUpdate: () -> Void
    var onCompletionChanged: (_ task: TodoTask, _ oldValue: Bool, _ newValue: Bool) -> Void
    var onMoveToDate: ((_ task: TodoTask, _ date: Date) -> Void)? = nil
    var onRepeatRuleChanged: ((_ task: TodoTask, _ repeatRule: TaskRepeatRule) -> Void)? = nil
    var onDelete: () -> Void

    @State private var isHoveringDelete = false
    @State private var isConfirmingDelete = false
    @State private var titleEditor = TaskTitleEditorHandle()
    @State private var isMoveDatePresented = false
    @State private var moveDate = Date()

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(task.priority.color)
                .frame(width: 4, height: 24)
                .opacity(task.isCompleted ? 0.45 : 1)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 14)

            CheckBox(isOn: $task.isCompleted)
                .onChange(of: task.isCompleted) { oldValue, newValue in
                    onCompletionChanged(task, oldValue, newValue)
                }

            titleContent

            PriorityPicker(priority: priorityBinding)
                .opacity(task.isCompleted ? 0.6 : 1)
                .padding(.trailing, 4)

            Button {
                isConfirmingDelete = true
            } label: {
                AnimatedTrashIcon(isOpen: isHoveringDelete)
                    .frame(width: 28, height: 28)
                    .background {
                        Circle()
                            .fill(isHoveringDelete ? Color.red.opacity(0.12) : Color.clear)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(isHoveringDelete ? Color.red : Color.secondary)
            .opacity(isHoveringDelete ? 1 : 0.75)
            .help("Delete task")
            .accessibilityLabel("Delete task")
            .onHover { isHovering in
                isHoveringDelete = isHovering
            }
            .confirmationDialog(
                "Delete this task?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive, action: onDelete)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(confirmDeleteMessage)
            }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .contextMenu {
            taskContextMenu
        }
        .popover(isPresented: $isMoveDatePresented, arrowEdge: .trailing) {
            moveDatePopover
        }
    }

    private var titleContent: some View {
        FloatingTaskTitle(
            title: task.title,
            isCompleted: task.isCompleted,
            fontSize: TextSize.scaled(15, by: textScale),
            fontWeight: .regular,
            editor: titleEditor,
            onEdit: { title in
                task.title = title
                onUpdate()
            }
        )
        .frame(maxWidth: .infinity, minHeight: TextSize.rowHeight(baseFontSize: 15, scale: textScale))
    }

    @ViewBuilder
    private var taskContextMenu: some View {
        Button {
            titleEditor.beginEditing()
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        if onMoveToDate != nil {
            Divider()

            Button {
                moveTaskToTomorrow()
            } label: {
                Label("Move to Tomorrow", systemImage: "calendar.badge.clock")
            }

            Button {
                moveDate = task.scheduledDay(in: calendar)
                isMoveDatePresented = true
            } label: {
                Label("Move to...", systemImage: "calendar")
            }
        }

        if onRepeatRuleChanged != nil {
            Divider()

            Menu {
                repeatRuleButton(.none)
                repeatRuleButton(.daily)
                repeatRuleButton(.weekly)
            } label: {
                Label("Repeat", systemImage: "repeat")
            }
        }
    }

    private var moveDatePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("Move Date", selection: $moveDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()

            HStack {
                Button("Cancel") {
                    isMoveDatePresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Move") {
                    onMoveToDate?(task, moveDate)
                    isMoveDatePresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 260)
    }

    private func repeatRuleButton(_ repeatRule: TaskRepeatRule) -> some View {
        Button {
            onRepeatRuleChanged?(task, repeatRule)
        } label: {
            if task.repeatRule == repeatRule {
                Label(repeatRule.title, systemImage: "checkmark")
            } else {
                Text(repeatRule.title)
            }
        }
    }

    private func moveTaskToTomorrow() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: task.scheduledDay(in: calendar)) ?? .now
        onMoveToDate?(task, tomorrow)
    }

    private var confirmDeleteMessage: String {
        let title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "This task will be removed." : "\"\(title)\" will be removed."
    }

    private var priorityBinding: Binding<TaskPriority> {
        Binding {
            task.priority
        } set: { newPriority in
            task.priority = newPriority
            onUpdate()
        }
    }
}

private struct AnimatedTrashIcon: View {
    let isOpen: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(lineWidth: 1.5)
                .frame(width: 12, height: 12)
                .offset(y: 4)

            Path { path in
                path.move(to: CGPoint(x: 9, y: 13))
                path.addLine(to: CGPoint(x: 9, y: 20))
                path.move(to: CGPoint(x: 14, y: 13))
                path.addLine(to: CGPoint(x: 14, y: 20))
                path.move(to: CGPoint(x: 19, y: 13))
                path.addLine(to: CGPoint(x: 19, y: 20))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(.foreground)
                .frame(width: 14, height: 1.6)
                .rotationEffect(.degrees(isOpen ? -28 : 0), anchor: .leading)
                .offset(x: isOpen ? -1 : 0, y: isOpen ? -5 : -4)

            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(.foreground)
                .frame(width: 6, height: 1.5)
                .offset(y: isOpen ? -8 : -7)
                .opacity(isOpen ? 0.9 : 1)
        }
        .frame(width: 28, height: 28)
        .scaleEffect(isOpen ? 1.08 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.62), value: isOpen)
    }
}
