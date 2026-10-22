import AppKit

final class AppSwitcherModule: ToolbeltModule {
    let identifier = "appSwitcher"
    let title = "Alternar janelas"
    let summary = "⌥⇥ mostra todas as janelas abertas e troca entre elas, como o AltTab."
    let symbolName = "rectangle.on.rectangle"
    let requiresAccessibility = true

    private let panel = SwitcherPanel()
    private var hotKeyIdentifiers: [UInt32] = []
    private var registeredSettings: AppSwitcherSettings?
    private var windows: [SwitchableWindow] = []
    private var selectedIndex = 0
    private var isSwitching = false
    private var showWorkItem: DispatchWorkItem?
    private var modifierMonitors: [Any] = []
    private var keyMonitor: Any?

    private var settings: AppSwitcherSettings { AppSettings.shared.values.appSwitcher }

    func start() {
        registerHotKeys()
        panel.onSelect = { [weak self] index in
            self?.selectedIndex = index
            self?.commit()
        }
    }

    func stop() {
        cancel()
        unregisterHotKeys()
    }

    func settingsDidChange() {
        guard registeredSettings != settings else { return }
        unregisterHotKeys()
        registerHotKeys()
    }

    private func registerHotKeys() {
        let current = settings
        registeredSettings = current
        guard let combo = current.activeShortcut else { return }
        if let forward = HotKeyCenter.shared.register(combo, handler: { [weak self] in self?.advance(by: 1) }) {
            hotKeyIdentifiers.append(forward)
        }
        if combo.modifiers & KeyCombo.shift == 0 {
            let reverse = KeyCombo(keyCode: combo.keyCode, modifiers: combo.modifiers | KeyCombo.shift)
            if let backward = HotKeyCenter.shared.register(reverse, handler: { [weak self] in self?.advance(by: -1) }) {
                hotKeyIdentifiers.append(backward)
            }
        }
    }

    private func unregisterHotKeys() {
        hotKeyIdentifiers.forEach(HotKeyCenter.shared.unregister)
        hotKeyIdentifiers.removeAll()
        registeredSettings = nil
    }

    private func advance(by step: Int) {
        guard AccessibilityPermission.isTrusted else {
            AccessibilityPermission.requestIfNeeded()
            return
        }
        if !isSwitching {
            begin(step: step)
            return
        }
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + step + windows.count) % windows.count
        panel.select(selectedIndex)
    }

    private func begin(step: Int) {
        windows = WindowCatalog.windows(includingMinimized: settings.includesMinimized)
        guard !windows.isEmpty else { return }
        isSwitching = true
        selectedIndex = windows.count > 1 ? (step > 0 ? 1 : windows.count - 1) : 0
        watchModifierRelease()
        let requiredFlags = Self.modifierFlags(from: settings.shortcut.modifiers).subtracting(.shift)
        guard requiredFlags.isSubset(of: NSEvent.modifierFlags.intersection([.command, .option, .control])) else {
            commit()
            return
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isSwitching else { return }
            self.panel.show(
                windows: self.windows,
                selectedIndex: self.selectedIndex,
                iconSize: CGFloat(self.settings.iconSize),
                showsThumbnails: self.settings.showsThumbnails && ScreenRecordingPermission.isGranted
            )
            self.watchKeys()
        }
        showWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(settings.showDelayMilliseconds), execute: work)
    }

    private func watchModifierRelease() {
        let requiredFlags = Self.modifierFlags(from: settings.shortcut.modifiers).subtracting(.shift)
        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self, self.isSwitching else { return }
            let held = event.modifierFlags.intersection([.command, .option, .control])
            if !requiredFlags.isSubset(of: held) {
                self.commit()
            }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handler) {
            modifierMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { event in
            handler(event)
            return event
        }) {
            modifierMonitors.append(local)
        }
    }

    private func watchKeys() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isSwitching else { return event }
            switch event.keyCode {
            case 53:
                self.cancel()
            case 36, 76:
                self.commit()
            case 123, 126:
                self.advance(by: -1)
            case 124, 125:
                self.advance(by: 1)
            default:
                break
            }
            return nil
        }
    }

    private func commit() {
        guard isSwitching else { return }
        let target = windows.indices.contains(selectedIndex) ? windows[selectedIndex] : nil
        finish()
        target?.focus()
    }

    private func cancel() {
        guard isSwitching else { return }
        finish()
    }

    private func finish() {
        isSwitching = false
        showWorkItem?.cancel()
        showWorkItem = nil
        modifierMonitors.forEach(NSEvent.removeMonitor)
        modifierMonitors.removeAll()
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        panel.close()
        windows.removeAll()
    }

    private static func modifierFlags(from carbonModifiers: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbonModifiers & KeyCombo.command != 0 { flags.insert(.command) }
        if carbonModifiers & KeyCombo.option != 0 { flags.insert(.option) }
        if carbonModifiers & KeyCombo.control != 0 { flags.insert(.control) }
        if carbonModifiers & KeyCombo.shift != 0 { flags.insert(.shift) }
        return flags
    }
}

private final class SwitcherWindow: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class SwitcherPanel {
    private static let tileWidth: CGFloat = 132
    private static let tileSpacing: CGFloat = 8
    private static let padding: CGFloat = 14

    private static let thumbnailTileWidth: CGFloat = 220
    private static let thumbnailHeight: CGFloat = 130

    private var window: SwitcherWindow?
    private var tiles: [SwitcherTile] = []
    private var thumbnailTask: Task<Void, Never>?
    var onSelect: ((Int) -> Void)?

    func show(windows: [SwitchableWindow], selectedIndex: Int, iconSize: CGFloat, showsThumbnails: Bool) {
        close()
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? .zero
        let tileWidth = showsThumbnails ? Self.thumbnailTileWidth : Self.tileWidth
        let tileHeight = showsThumbnails ? Self.thumbnailHeight + 48 : iconSize + 52
        let maximumColumns = max(1, Int((bounds.width * 0.9 - Self.padding * 2 + Self.tileSpacing) / (tileWidth + Self.tileSpacing)))
        let columns = min(windows.count, maximumColumns)
        let rows = Int(ceil(Double(windows.count) / Double(columns)))
        let width = CGFloat(columns) * tileWidth + CGFloat(columns - 1) * Self.tileSpacing + Self.padding * 2
        let height = CGFloat(rows) * tileHeight + CGFloat(rows - 1) * Self.tileSpacing + Self.padding * 2

        let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 16
        background.layer?.masksToBounds = true

        tiles = windows.enumerated().map { index, item in
            let column = index % columns
            let row = index / columns
            let frame = NSRect(
                x: Self.padding + CGFloat(column) * (tileWidth + Self.tileSpacing),
                y: height - Self.padding - CGFloat(row + 1) * tileHeight - CGFloat(row) * Self.tileSpacing,
                width: tileWidth,
                height: tileHeight
            )
            let tile = SwitcherTile(frame: frame, window: item, iconSize: iconSize, thumbnailHeight: showsThumbnails ? Self.thumbnailHeight : nil) { [weak self] in
                self?.onSelect?(index)
            }
            background.addSubview(tile)
            return tile
        }

        let panel = SwitcherWindow(
            contentRect: NSRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = background
        panel.makeKeyAndOrderFront(nil)
        window = panel
        select(selectedIndex)

        if showsThumbnails {
            let tilesByWindow = Dictionary(uniqueKeysWithValues: zip(windows.map(\.windowID), tiles))
            let visibleWindowIDs = windows.filter { !$0.isMinimized }.map(\.windowID)
            thumbnailTask = WindowThumbnails.capture(
                windowIDs: visibleWindowIDs,
                maximumSize: CGSize(width: tileWidth - 16, height: Self.thumbnailHeight)
            ) { identifier, image in
                tilesByWindow[identifier]?.thumbnail = image
            }
        }
    }

    func select(_ index: Int) {
        for (tileIndex, tile) in tiles.enumerated() {
            tile.isSelected = tileIndex == index
        }
    }

    func close() {
        thumbnailTask?.cancel()
        thumbnailTask = nil
        window?.orderOut(nil)
        window = nil
        tiles.removeAll()
    }
}

private final class SwitcherTile: NSView {
    private let handler: () -> Void
    private let highlight = NSView()
    private var thumbnailView: NSImageView?
    private var iconView: NSImageView?
    private let iconSize: CGFloat

    var thumbnail: NSImage? {
        didSet {
            guard let thumbnailView else { return }
            thumbnailView.image = thumbnail
            if thumbnail != nil, let iconView {
                let badge: CGFloat = 28
                iconView.frame = NSRect(x: 10, y: thumbnailView.frame.minY + 4, width: badge, height: badge)
                iconView.alphaValue = 1
            }
        }
    }

    var isSelected = false {
        didSet {
            highlight.layer?.backgroundColor = isSelected
                ? NSColor.controlAccentColor.withAlphaComponent(0.35).cgColor
                : NSColor.clear.cgColor
        }
    }

    init(frame: NSRect, window: SwitchableWindow, iconSize: CGFloat, thumbnailHeight: CGFloat?, handler: @escaping () -> Void) {
        self.handler = handler
        self.iconSize = iconSize
        super.init(frame: frame)

        highlight.frame = bounds
        highlight.wantsLayer = true
        highlight.layer?.cornerRadius = 10
        addSubview(highlight)

        if let thumbnailHeight {
            let thumbnailView = NSImageView(frame: NSRect(x: 8, y: frame.height - thumbnailHeight - 8, width: frame.width - 16, height: thumbnailHeight))
            thumbnailView.imageScaling = .scaleProportionallyDown
            thumbnailView.wantsLayer = true
            thumbnailView.layer?.cornerRadius = 6
            thumbnailView.layer?.masksToBounds = true
            addSubview(thumbnailView)
            self.thumbnailView = thumbnailView
        }

        let iconFrame: NSRect
        if let thumbnailHeight {
            let size = min(iconSize, thumbnailHeight - 20)
            iconFrame = NSRect(x: (frame.width - size) / 2, y: frame.height - 8 - thumbnailHeight / 2 - size / 2, width: size, height: size)
        } else {
            iconFrame = NSRect(x: (frame.width - iconSize) / 2, y: frame.height - iconSize - 8, width: iconSize, height: iconSize)
        }
        let iconView = NSImageView(frame: iconFrame)
        self.iconView = iconView
        iconView.image = window.icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        if window.isMinimized {
            iconView.alphaValue = 0.55
        }
        addSubview(iconView)

        let titleLabel = NSTextField(wrappingLabelWithString: window.displayTitle)
        titleLabel.frame = NSRect(x: 6, y: 4, width: frame.width - 12, height: 36)
        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.maximumNumberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.textColor = .labelColor
        addSubview(titleLabel)
        toolTip = "\(window.applicationName) — \(window.displayTitle)"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func mouseDown(with event: NSEvent) {
        handler()
    }
}
