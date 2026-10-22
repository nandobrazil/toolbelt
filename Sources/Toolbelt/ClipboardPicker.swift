import AppKit

private final class PickerPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true {
            super.keyDown(with: event)
        }
    }
}

final class ClipboardPicker: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    private static let headerHeight: CGFloat = 30
    private var appearance: ClipboardPanelAppearance { AppSettings.shared.values.clipboard.appearance }
    private var width: CGFloat { CGFloat(appearance.width) }
    private var textRowHeight: CGFloat { CGFloat(appearance.fontSize) * 2 }
    private var imageRowHeight: CGFloat { CGFloat(appearance.imageHeight) }
    private var maximumHeight: CGFloat { CGFloat(appearance.maximumHeight) }
    private static let previewLength = 80

    private let store: ClipboardStore
    private var panel: PickerPanel?
    private let tableView = NSTableView()
    private let queryLabel = NSTextField(labelWithString: "")
    private var visibleEntries: [ClipboardEntry] = []
    private var query = ""
    private var onChoose: ((ClipboardEntry) -> Void)?

    init(store: ClipboardStore) {
        self.store = store
        super.init()
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(onChoose: @escaping (ClipboardEntry) -> Void) {
        close()
        self.onChoose = onChoose
        query = ""
        refreshEntries()
        guard !store.entries.isEmpty else { return }

        let panel = PickerPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.delegate = self
        panel.onKeyDown = { [weak self] event in self?.handleKey(event) ?? false }
        panel.contentView = makeContent()
        switch appearance.theme {
        case .system: panel.appearance = nil
        case .light: panel.appearance = NSAppearance(named: .aqua)
        case .dark: panel.appearance = NSAppearance(named: .darkAqua)
        }
        self.panel = panel

        resizeAndPosition()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(nil)
        selectRow(0)
    }

    func close() {
        guard let panel else { return }
        panel.delegate = nil
        panel.orderOut(nil)
        self.panel = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func makeContent() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = CGFloat(appearance.cornerRadius)
        container.layer?.masksToBounds = true

        let backdrop = makeBackdrop()
        backdrop.alphaValue = CGFloat(appearance.backgroundOpacity)
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: container.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        let background = container

        queryLabel.font = .systemFont(ofSize: 12, weight: .medium)
        queryLabel.textColor = .secondaryLabelColor
        queryLabel.translatesAutoresizingMaskIntoConstraints = false
        updateQueryLabel()

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("entry"))
        column.width = width - 16
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.style = .plain
        tableView.selectionHighlightStyle = .regular
        tableView.refusesFirstResponder = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(rowClicked)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        background.addSubview(queryLabel)
        background.addSubview(scrollView)
        NSLayoutConstraint.activate([
            queryLabel.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 12),
            queryLabel.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -12),
            queryLabel.topAnchor.constraint(equalTo: background.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 6),
            scrollView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -6),
            scrollView.topAnchor.constraint(equalTo: background.topAnchor, constant: Self.headerHeight),
            scrollView.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -6)
        ])
        return background
    }

    private func makeBackdrop() -> NSView {
        switch appearance.background {
        case .glass:
            let view = NSVisualEffectView()
            view.material = .hudWindow
            view.blendingMode = .behindWindow
            view.state = .active
            return view
        case .frosted:
            let view = NSVisualEffectView()
            view.material = .popover
            view.blendingMode = .behindWindow
            view.state = .active
            return view
        case .solid:
            let view = NSView()
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            return view
        }
    }

    private func resizeAndPosition() {
        guard let panel else { return }
        let rowsHeight = visibleEntries.reduce(CGFloat(0)) { total, entry in
            total + rowHeight(for: entry) + tableView.intercellSpacing.height
        }
        let height = min(maximumHeight, max(rowsHeight, textRowHeight) + Self.headerHeight + 8)
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? .zero
        var origin = NSPoint(x: mouse.x, y: mouse.y - height)
        if AppSettings.shared.values.clipboard.pickerPosition == .screenCenter {
            origin = NSPoint(x: bounds.midX - width / 2, y: bounds.midY - height / 2 + bounds.height / 8)
        }
        origin.x = max(bounds.minX + 8, min(origin.x, bounds.maxX - width - 8))
        origin.y = max(bounds.minY + 8, min(origin.y, bounds.maxY - height - 8))
        panel.setFrame(NSRect(x: origin.x, y: origin.y, width: width, height: height), display: true)
    }

    private func refreshEntries() {
        let normalizedQuery = query.lowercased()
        visibleEntries = store.entries.filter { entry in
            guard !normalizedQuery.isEmpty else { return true }
            switch entry.kind {
            case .text: return entry.text?.lowercased().contains(normalizedQuery) ?? false
            case .image: return "imagem print screenshot".contains(normalizedQuery)
            }
        }
        tableView.reloadData()
    }

    private func updateQueryLabel() {
        queryLabel.stringValue = query.isEmpty
            ? "Histórico · digite para filtrar · 1–9 e 0 \(AppSettings.shared.values.clipboard.pasteAutomatically ? "colam" : "copiam") direto"
            : "Filtro: \(query)"
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53:
            close()
            return true
        case 36, 76:
            chooseSelected()
            return true
        case 125:
            selectRow(min(tableView.selectedRow + 1, visibleEntries.count - 1))
            return true
        case 126:
            selectRow(max(tableView.selectedRow - 1, 0))
            return true
        case 51:
            guard !query.isEmpty else { return true }
            query.removeLast()
            applyQuery()
            return true
        default:
            break
        }
        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else { return false }
        if query.isEmpty, let digit = Int(characters), characters.count == 1 {
            let index = digit == 0 ? 9 : digit - 1
            if index < visibleEntries.count {
                choose(visibleEntries[index])
            }
            return true
        }
        if event.modifierFlags.intersection([.command, .control]).isEmpty {
            query += characters
            applyQuery()
            return true
        }
        return false
    }

    private func applyQuery() {
        updateQueryLabel()
        refreshEntries()
        resizeAndPosition()
        selectRow(0)
    }

    private func selectRow(_ row: Int) {
        guard row >= 0, row < visibleEntries.count else { return }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    @objc private func rowClicked() {
        let row = tableView.clickedRow
        guard row >= 0, row < visibleEntries.count else { return }
        choose(visibleEntries[row])
    }

    private func chooseSelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < visibleEntries.count else { return }
        choose(visibleEntries[row])
    }

    private func choose(_ entry: ClipboardEntry) {
        let handler = onChoose
        close()
        handler?(entry)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        visibleEntries.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        rowHeight(for: visibleEntries[row])
    }

    private func rowHeight(for entry: ClipboardEntry) -> CGFloat {
        entry.kind == .image ? imageRowHeight : textRowHeight
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = visibleEntries[row]
        let container = NSView()

        let shortcutText = row < 9 ? "\(row + 1)" : (row == 9 ? "0" : "")
        let shortcut = NSTextField(labelWithString: appearance.showsShortcutNumbers ? shortcutText : "")
        shortcut.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        shortcut.textColor = .tertiaryLabelColor
        shortcut.alignment = .center
        shortcut.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(shortcut)

        let content: NSView
        switch entry.kind {
        case .text:
            let label = NSTextField(labelWithString: preview(entry.text ?? ""))
            label.lineBreakMode = .byTruncatingTail
            label.font = .systemFont(ofSize: CGFloat(appearance.fontSize))
            content = label
        case .image:
            let imageView = NSImageView()
            imageView.image = store.thumbnail(for: entry)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.imageAlignment = .alignLeft
            content = imageView
        }
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)

        NSLayoutConstraint.activate([
            shortcut.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            shortcut.widthAnchor.constraint(equalToConstant: appearance.showsShortcutNumbers ? 16 : 0),
            shortcut.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            content.leadingAnchor.constraint(equalTo: shortcut.trailingAnchor, constant: 8),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8)
        ])
        if entry.kind == .image {
            NSLayoutConstraint.activate([
                content.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
                content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
            ])
        } else {
            content.centerYAnchor.constraint(equalTo: container.centerYAnchor).isActive = true
        }
        return container
    }

    private func preview(_ text: String) -> String {
        let singleLine = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ⏎ ")
        guard singleLine.count > Self.previewLength else { return singleLine }
        return String(singleLine.prefix(Self.previewLength)) + "…"
    }
}
