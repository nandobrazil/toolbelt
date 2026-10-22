import AppKit

struct PanelAction {
    let title: String
    let symbolName: String
    let handler: () -> Void
}

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class ToolbeltPanel {
    private static let iconSize: CGFloat = 18
    private static let itemButtonSize = NSSize(width: 30, height: 26)
    private static let actionButtonSize = NSSize(width: 28, height: 24)
    private static let padding: CGFloat = 8
    private static let minimumWidth: CGFloat = 250

    private var panel: FloatingPanel?
    private var outsideClickMonitor: Any?
    private var escapeMonitor: Any?
    var onClose: (() -> Void)?

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(
        hiddenExtras: [MenuBarExtra]?,
        columns: Int,
        quickActions: [PanelAction],
        trailingActions: [PanelAction],
        below anchor: NSRect,
        onSelectExtra: @escaping (MenuBarExtra) -> Void
    ) {
        close()
        let content = makeContent(
            hiddenExtras: hiddenExtras,
            columns: max(columns, 4),
            quickActions: quickActions,
            trailingActions: trailingActions,
            onSelectExtra: onSelectExtra
        )
        var size = content.fittingSize
        size.width = max(size.width, Self.minimumWidth)
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

    private func makeContent(
        hiddenExtras: [MenuBarExtra]?,
        columns: Int,
        quickActions: [PanelAction],
        trailingActions: [PanelAction],
        onSelectExtra: @escaping (MenuBarExtra) -> Void
    ) -> NSView {
        let background = NSVisualEffectView()
        background.material = .menu
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.masksToBounds = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        if let hiddenExtras {
            stack.addArrangedSubview(sectionLabel("Ícones escondidos"))
            if hiddenExtras.isEmpty {
                let empty = NSTextField(labelWithString: "Nenhum. ⌥ clique na setinha para organizar a barra.")
                empty.font = .systemFont(ofSize: 12)
                empty.textColor = .secondaryLabelColor
                stack.addArrangedSubview(empty)
            }
            for rowStart in stride(from: 0, to: hiddenExtras.count, by: columns) {
                let row = NSStackView()
                row.orientation = .horizontal
                row.spacing = 2
                for extra in hiddenExtras[rowStart..<min(rowStart + columns, hiddenExtras.count)] {
                    row.addArrangedSubview(makeExtraButton(extra) { [weak self] in
                        self?.close()
                        onSelectExtra(extra)
                    })
                }
                stack.addArrangedSubview(row)
            }
            let divider = NSBox()
            divider.boxType = .separator
            stack.addArrangedSubview(divider)
            divider.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.spacing = 2
        for action in quickActions {
            footer.addArrangedSubview(makeActionButton(action))
        }
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        footer.addArrangedSubview(spacer)
        for action in trailingActions {
            footer.addArrangedSubview(makeActionButton(action))
        }
        stack.addArrangedSubview(footer)
        footer.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: Self.padding),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -Self.padding),
            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: Self.padding),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -Self.padding),
            stack.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.minimumWidth - Self.padding * 2)
        ])
        return background
    }

    private func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        return label
    }

    private func makeExtraButton(_ extra: MenuBarExtra, handler: @escaping () -> Void) -> NSView {
        let image = (extra.icon?.copy() as? NSImage) ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)
        image?.size = NSSize(width: Self.iconSize, height: Self.iconSize)
        return HoverButton(image: image, toolTip: extra.label, size: Self.itemButtonSize, handler: handler)
    }

    private func makeActionButton(_ action: PanelAction) -> NSView {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = NSImage(systemSymbolName: action.symbolName, accessibilityDescription: action.title)?
            .withSymbolConfiguration(configuration)
        return HoverButton(image: image, toolTip: action.title, size: Self.actionButtonSize) { [weak self] in
            self?.close()
            action.handler()
        }
    }
}

private final class HoverButton: NSButton {
    private let handler: () -> Void

    init(image: NSImage?, toolTip: String, size: NSSize, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        self.image = image
        self.toolTip = toolTip
        imagePosition = .imageOnly
        isBordered = false
        contentTintColor = .labelColor
        target = self
        action = #selector(runHandler)
        wantsLayer = true
        layer?.cornerRadius = 5
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size.width),
            heightAnchor.constraint(equalToConstant: size.height)
        ])
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

    @objc private func runHandler() {
        handler()
    }
}
