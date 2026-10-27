import SwiftUI

struct PriorityPicker: View {
    @Binding var priority: TaskPriority
    var isCompact = false
    var onPresentationChange: (Bool) -> Void = { _ in }
    @State private var isShowingPalette = false
    @State private var isHovering = false
    @State private var hoveredOption: TaskPriority?

    var body: some View {
        Button {
            isShowingPalette.toggle()
        } label: {
            priorityIndicator
                .frame(width: isCompact ? 20 : 32, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(priority.color.opacity(isHovering || isShowingPalette ? 0.14 : 0))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help("Change priority")
        .onHover { isHovering = $0 }
        .onChange(of: isShowingPalette) { _, isPresented in
            onPresentationChange(isPresented)
        }
        .onDisappear {
            if isShowingPalette { onPresentationChange(false) }
        }
        .popover(isPresented: $isShowingPalette, arrowEdge: .bottom) {
            HStack(spacing: 8) {
                ForEach(TaskPriority.allCases) { option in
                    Button {
                        isShowingPalette = false
                        priority = option
                    } label: {
                        Circle()
                            .fill(option.color)
                            .frame(width: 14, height: 14)
                            .padding(5)
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        priority == option ? option.color.opacity(0.55) : Color.clear,
                                        lineWidth: 1.5
                                    )
                            }
                            .shadow(
                                color: priority == option ? option.color.opacity(0.24) : Color.clear,
                                radius: 3,
                                x: 0,
                                y: 1
                            )
                            .frame(width: 32, height: 32)
                            .background {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(option.color.opacity(hoveredOption == option ? 0.14 : 0))
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovering in
                        if isHovering {
                            hoveredOption = option
                        } else if hoveredOption == option {
                            hoveredOption = nil
                        }
                    }
                    .accessibilityLabel("Priority color \(option.rawValue)")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .onDisappear { hoveredOption = nil }
        }
        .accessibilityLabel("Change priority color")
    }

    @ViewBuilder
    private var priorityIndicator: some View {
        if isCompact {
            Circle()
                .fill(priority.color)
                .frame(width: 7, height: 7)
        } else {
            Circle()
                .fill(priority.color)
                .frame(width: 12, height: 12)
                .padding(6)
                .overlay {
                    Circle()
                        .strokeBorder(priority.color.opacity(0.45), lineWidth: 1.5)
                }
                .shadow(color: priority.color.opacity(0.26), radius: 4, x: 0, y: 1)
        }
    }
}
