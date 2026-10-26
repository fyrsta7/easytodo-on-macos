@preconcurrency import AppKit
import SwiftUI

struct FloatingTaskTitle: NSViewRepresentable {
    let title: String
    var isCompleted = false
    var fontSize: CGFloat = 15
    var fontWeight: NSFont.Weight = .regular
    var isHovered: Bool? = nil
    var alwaysShowPreview = false
    var onDoubleClick: (() -> Void)?

    func makeNSView(context: Context) -> FloatingTaskTitleView {
        let view = FloatingTaskTitleView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ nsView: FloatingTaskTitleView, context: Context) {
        nsView.update(
            title: title.isEmpty ? "Untitled task" : title,
            isCompleted: isCompleted,
            font: .systemFont(ofSize: fontSize, weight: fontWeight),
            isHovered: isHovered,
            alwaysShowPreview: alwaysShowPreview,
            onDoubleClick: onDoubleClick
        )
    }

    static func dismantleNSView(_ nsView: FloatingTaskTitleView, coordinator: ()) {
        nsView.hidePanel()
    }
}

final class FloatingTaskTitleView: NSView {
    private let label = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var panel: NSPanel?
    private var title = ""
    private var font = NSFont.systemFont(ofSize: 15, weight: .regular)
    private var hoverOverride: Bool?
    private var alwaysShowPreview = false
    private var isMouseInside = false
    private var onDoubleClick: (() -> Void)?

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

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: ceil(font.ascender - font.descender + font.leading))
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard onDoubleClick != nil, super.hitTest(point) != nil else { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            hidePanel()
            onDoubleClick?()
            return
        }
        super.mouseDown(with: event)
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
        alwaysShowPreview: Bool = false,
        onDoubleClick: (() -> Void)?
    ) {
        if self.title != title || self.font != font {
            hidePanel()
        }
        self.title = title
        self.font = font
        hoverOverride = isHovered
        self.alwaysShowPreview = alwaysShowPreview
        self.onDoubleClick = onDoubleClick

        label.attributedStringValue = NSAttributedString(string: title, attributes: [
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

    private func updatePreview() {
        guard hoverOverride ?? isMouseInside,
              let window, window.isVisible, !visibleRect.isEmpty,
              alwaysShowPreview || TaskTitlePreviewLayout.isTruncated(title, font: font, availableWidth: bounds.width) else {
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

    static func isTruncated(_ title: String, font: NSFont, availableWidth: CGFloat) -> Bool {
        guard availableWidth > 0 else { return false }
        return title.contains(where: \.isNewline)
            || (title as NSString).size(withAttributes: [.font: font]).width > availableWidth + 1
    }

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
