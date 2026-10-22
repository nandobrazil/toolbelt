import AppKit

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class HiddenItemsPanel {
    private static let iconSize: CGFloat = 18
    private static let buttonSize = NSSize(width: 30, height: 26)
    private static let maximumColumns = 10
    private static let padding: CGFloat = 6

    private var panel: FloatingPanel?
    private var outsideClickMonitor: Any?
    private var escapeMonitor: Any?
    var onClose: (() -> Void)?

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(extras: [MenuBarExtra], below anchor: NSRect, onSelect: @escaping (MenuBarExtra) -> Void) {
        close()
        let content = makeContent(extras: extras) { [weak self] extra in
            self?.close()
            onSelect(extra)
        }
        let size = content.fittingSize
        NSLog("Toolbelt: panel extras=\(extras.count) size=\(size) anchor=\(anchor)")
        let screenFrame = NSScreen.screens.first { $0.frame.contains(anchor.origin) }?.frame ?? NSScreen.main?.frame ?? .zero
        var origin = NSPoint(x: anchor.maxX - size.width, y: anchor.minY - size.height - 4)
        origin.x = max(screenFrame.minX + 4, min(origin.x, screenFrame.maxX - size.width - 4))

        let panel = FloatingPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = content
        panel.orderFrontRegardless()
        self.panel = panel

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.close()
                return nil
            }
            return event
        }
    }

    func close() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
        }
        outsideClickMonitor = nil
        escapeMonitor = nil
        let wasVisible = panel != nil
        panel?.orderOut(nil)
        panel = nil
        if wasVisible {
            onClose?()
        }
    }

    private func makeContent(extras: [MenuBarExtra], onSelect: @escaping (MenuBarExtra) -> Void) -> NSView {
        let background = NSVisualEffectView()
        background.material = .menu
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.masksToBounds = true

        let grid = NSStackView()
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = 2
        grid.translatesAutoresizingMaskIntoConstraints = false

        if extras.isEmpty {
            let label = NSTextField(labelWithString: "Nenhum ícone escondido")
            label.textColor = .secondaryLabelColor
            grid.addArrangedSubview(label)
        }

        for rowStart in stride(from: 0, to: extras.count, by: Self.maximumColumns) {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 2
            for extra in extras[rowStart..<min(rowStart + Self.maximumColumns, extras.count)] {
                row.addArrangedSubview(makeButton(for: extra, onSelect: onSelect))
            }
            grid.addArrangedSubview(row)
        }

        background.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: Self.padding),
            grid.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -Self.padding),
            grid.topAnchor.constraint(equalTo: background.topAnchor, constant: Self.padding),
            grid.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -Self.padding)
        ])
        return background
    }

    private func makeButton(for extra: MenuBarExtra, onSelect: @escaping (MenuBarExtra) -> Void) -> NSView {
        let button = ExtraButton(extra: extra, onSelect: onSelect)
        let image = (extra.icon?.copy() as? NSImage) ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)
        image?.size = NSSize(width: Self.iconSize, height: Self.iconSize)
        button.image = image
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.toolTip = extra.label
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: Self.buttonSize.width),
            button.heightAnchor.constraint(equalToConstant: Self.buttonSize.height)
        ])
        return button
    }
}

private final class ExtraButton: NSButton {
    private let extra: MenuBarExtra
    private let onSelect: (MenuBarExtra) -> Void

    init(extra: MenuBarExtra, onSelect: @escaping (MenuBarExtra) -> Void) {
        self.extra = extra
        self.onSelect = onSelect
        super.init(frame: .zero)
        target = self
        action = #selector(chooseExtra)
        wantsLayer = true
        layer?.cornerRadius = 5
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.12).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = nil
    }

    @objc private func chooseExtra() {
        onSelect(extra)
    }
}
