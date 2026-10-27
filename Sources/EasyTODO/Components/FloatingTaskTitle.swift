@preconcurrency import AppKit
import SwiftUI

struct FloatingTaskTitle: NSViewRepresentable {
    let title: String
    var isCompleted = false
    var fontSize: CGFloat = 15
    var fontWeight: NSFont.Weight = .regular
    var isHovered: Bool? = nil
    var editor: TaskTitleEditorHandle?
    var onEdit: ((String) -> Void)?

    func makeNSView(context: Context) -> FloatingTaskTitleView {
        let view = FloatingTaskTitleView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ nsView: FloatingTaskTitleView, context: Context) {
        editor?.titleView = nsView
        nsView.update(
            title: title,
            isCompleted: isCompleted,
            font: .systemFont(ofSize: fontSize, weight: fontWeight),
            isHovered: isHovered,
            onEdit: onEdit
        )
    }

    static func dismantleNSView(_ nsView: FloatingTaskTitleView, coordinator: ()) {
        nsView.hidePanel()
        nsView.closeEditor()
    }
}

@MainActor
final class TaskTitleEditorHandle {
    weak var titleView: FloatingTaskTitleView?

    func beginEditing() {
        // A menu action can run before AppKit has finished restoring the key window.
        DispatchQueue.main.async { [weak self] in self?.titleView?.beginEditing() }
    }
}

final class FloatingTaskTitleView: NSView, NSPopoverDelegate {
    private let label = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var panel: NSPanel?
    private var title = ""
    private var font = NSFont.systemFont(ofSize: 15, weight: .regular)
    private var hoverOverride: Bool?
    private var isMouseInside = false
    private var onEdit: ((String) -> Void)?
    private(set) var editorPopover: NSPopover?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.isSelectable = false
        label.drawsBackground = false
        label.isBordered = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override var mouseDownCanMoveWindow: Bool { false }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: ceil(font.ascender - font.descender + font.leading))
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard onEdit != nil, super.hitTest(point) != nil else { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            beginEditing()
            return
        }
        // Consume the first click too, so List selection/window dragging cannot steal the double-click.
        window?.makeFirstResponder(self)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        updatePreview()
    }

    override func mouseMoved(with event: NSEvent) {
        isMouseInside = true
        updatePreview()
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        updatePreview()
    }

    override func layout() {
        super.layout()
        updatePreview()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        isMouseInside = window.map {
            bounds.contains(convert($0.mouseLocationOutsideOfEventStream, from: nil))
        } ?? false
        updatePreview()
    }

    func update(
        title: String,
        isCompleted: Bool,
        font: NSFont,
        isHovered: Bool?,
        onEdit: ((String) -> Void)?
    ) {
        if self.title != title || self.font != font {
            hidePanel()
        }
        self.title = title
        self.font = font
        hoverOverride = isHovered
        self.onEdit = onEdit

        label.attributedStringValue = NSAttributedString(string: title.isEmpty ? "Untitled task" : title, attributes: [
            .font: font,
            .foregroundColor: isCompleted ? NSColor.secondaryLabelColor : NSColor.labelColor,
            .strikethroughStyle: isCompleted ? NSUnderlineStyle.single.rawValue : 0,
            .strikethroughColor: NSColor.secondaryLabelColor
        ])
        // The custom card is the only tooltip; a delayed system tooltip would overlap it.
        label.toolTip = nil
        invalidateIntrinsicContentSize()
        updatePreview()
    }

    func beginEditing() {
        guard editorPopover == nil, onEdit != nil, window != nil else { return }
        hidePanel()
        let popover = NSPopover()
        popover.behavior = .semitransient
        popover.animates = false
        popover.delegate = self
        popover.contentViewController = TaskTitleEditorController(
            title: title,
            font: font,
            onSave: { [weak self] title in
                self?.onEdit?(title)
                self?.closeEditor()
            },
            onCancel: { [weak self] in self?.closeEditor() }
        )
        editorPopover = popover
        popover.show(relativeTo: bounds, of: self, preferredEdge: .maxY)
    }

    func closeEditor() {
        editorPopover?.close()
        editorPopover = nil
    }

    func popoverDidClose(_ notification: Notification) {
        editorPopover = nil
        isMouseInside = false
    }

    private func updatePreview() {
        // Every task uses the same hover card, whether or not its inline title fits.
        guard editorPopover == nil, hoverOverride ?? isMouseInside,
              let window, window.isVisible, !visibleRect.isEmpty else {
            hidePanel()
            return
        }

        let sourceFrame = window.convertToScreen(convert(bounds, to: nil))
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? sourceFrame
        let size = TaskTitlePreviewLayout.size(for: title, screenWidth: visibleFrame.width, font: previewFont)
        let frame = TaskTitlePreviewLayout.frame(size: size, source: sourceFrame, screen: visibleFrame)
        let preview = panel ?? makePanel(size: size)
        preview.appearance = window.effectiveAppearance
        preview.level = NSWindow.Level(rawValue: max(NSWindow.Level.floating.rawValue, window.level.rawValue + 1))
        if preview.frame != frame {
            preview.setFrame(frame, display: true)
        }
        if preview.parent !== window {
            preview.parent?.removeChildWindow(preview)
            window.addChildWindow(preview, ordered: .above)
        }
        preview.orderFrontRegardless()
        panel = preview
    }

    fileprivate func hidePanel() {
        guard let panel else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        self.panel = nil
    }

    private var previewFont: NSFont {
        .systemFont(ofSize: font.pointSize, weight: .medium)
    }

    private func makePanel(size: NSSize) -> NSPanel {
        let preview = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        preview.isOpaque = false // Only the rounded corners are transparent.
        preview.backgroundColor = .clear
        preview.alphaValue = 1
        preview.hasShadow = true
        preview.ignoresMouseEvents = true
        preview.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        preview.isReleasedWhenClosed = false
        preview.setAccessibilityLabel("Full task title")

        let card = NSBox(frame: NSRect(origin: .zero, size: size))
        card.boxType = .custom
        card.isTransparent = false
        card.titlePosition = .noTitle
        card.fillColor = .windowBackgroundColor
        card.borderColor = .separatorColor
        card.borderWidth = 1
        card.cornerRadius = 8
        card.contentViewMargins = .zero

        let fullTitle = NSTextField(wrappingLabelWithString: title)
        fullTitle.font = previewFont
        fullTitle.textColor = .labelColor
        fullTitle.lineBreakMode = .byCharWrapping
        fullTitle.maximumNumberOfLines = 0
        fullTitle.frame = NSRect(origin: .zero, size: size).insetBy(
            dx: TaskTitlePreviewLayout.horizontalPadding,
            dy: TaskTitlePreviewLayout.verticalPadding
        )
        fullTitle.autoresizingMask = [.width, .height]
        card.addSubview(fullTitle)
        preview.contentView = card
        return preview
    }
}

@MainActor
enum TaskTitlePreviewLayout {
    static let font = NSFont.systemFont(ofSize: 13, weight: .medium)
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 10
    static let screenMargin: CGFloat = 8

    static func size(for title: String, screenWidth: CGFloat, font: NSFont = TaskTitlePreviewLayout.font) -> NSSize {
        let maxWidth = min(400, max(72, screenWidth - 2 * (screenMargin + horizontalPadding)))
        let textWidth = min(maxWidth, max(72, ceil((title as NSString).size(withAttributes: [.font: font]).width)))
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byCharWrapping
        let textBounds = NSAttributedString(string: title, attributes: [.font: font, .paragraphStyle: paragraph]).boundingRect(
            // NSTextField reserves a small inset on each side of its text cell.
            with: NSSize(width: textWidth - 4, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        return NSSize(
            width: textWidth + 2 * horizontalPadding,
            height: max(ceil(textBounds.height) + 2, lineHeight) + 2 * verticalPadding
        )
    }

    static func frame(size: NSSize, source: NSRect, screen: NSRect) -> NSRect {
        let gap: CGFloat = 6
        let x = max(screen.minX + screenMargin, min(source.minX, screen.maxX - size.width - screenMargin))
        let below = source.minY - gap - size.height
        let y = below >= screen.minY + screenMargin ? below : source.maxY + gap
        return NSRect(
            origin: NSPoint(x: x, y: max(screen.minY + screenMargin, min(y, screen.maxY - size.height - screenMargin))),
            size: size
        )
    }
}
