import AppKit

/// A draft stays separate from the task until Save; dismissing the popover cancels it.
@MainActor
final class TaskTitleEditorController: NSViewController, NSTextViewDelegate {
    let textView = NSTextView()
    private let initialTitle: String
    private let font: NSFont
    private let onSave: (String) -> Void
    private let onCancel: () -> Void
    private let saveButton = NSButton(title: "Save", target: nil, action: nil)
    private var didFinish = false

    init(title: String, font: NSFont, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        initialTitle = title
        self.font = font
        self.onSave = onSave
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        let heading = NSTextField(labelWithString: "Edit Task")
        heading.font = .systemFont(ofSize: 15, weight: .semibold)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        textView.string = initialTitle
        textView.font = font
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 380, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = self
        textView.setAccessibilityLabel("Task content")
        textView.setAccessibilityIdentifier("task-title-editor")
        scroll.documentView = textView

        let hint = NSTextField(wrappingLabelWithString: "Return to save · Shift-Return for a new line · Esc to cancel")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        saveButton.target = self
        saveButton.action = #selector(save)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.isEnabled = !initialTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let buttons = NSStackView(views: [cancelButton, saveButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8

        for child in [heading, scroll, hint, buttons] {
            child.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(child)
        }
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 420),
            heading.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            heading.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            scroll.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scroll.heightAnchor.constraint(equalToConstant: max(140, font.pointSize * 7)),
            hint.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 8),
            hint.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            hint.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            buttons.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 12),
            buttons.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            buttons.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        ])
        view.layoutSubtreeIfNeeded()
        preferredContentSize = view.fittingSize
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Focus after attachment, when the popover has a real key window.
        guard let window = view.window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKey()
        window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        textView.scrollRangeToVisible(textView.selectedRange())
    }

    func textDidChange(_ notification: Notification) {
        saveButton.isEnabled = !textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Let the input method finish composing Chinese/Japanese text first.
        guard !textView.hasMarkedText() else { return false }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                textView.insertText("\n", replacementRange: textView.selectedRange())
            } else {
                save()
            }
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancel()
            return true
        }
        return false
    }

    @objc func save() {
        guard !didFinish, !textView.hasMarkedText() else { return }
        let title = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        didFinish = true
        onSave(title)
    }

    @objc func cancel() {
        guard !didFinish else { return }
        didFinish = true
        onCancel()
    }
}
