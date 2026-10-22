import AppKit

final class AppSwitcherModule: ToolbeltModule {
    let identifier = "appSwitcher"
    let title = String(localized: "Alternar janelas")
    let summary = String(localized: "⌥⇥ mostra todas as janelas abertas e troca entre elas, como o AltTab.")
    let symbolName = "rectangle.on.rectangle"
    let requiresAccessibility = true

    private static let keyHints = String(localized: "W fechar · M minimizar · H esconder app · Q fechar app · / buscar")
    private static let cachedThumbnailSize = CGSize(width: 204, height: 130)

    private let panel = SwitcherPanel()
    private let thumbnailCache = ThumbnailCache()
    private var hotKeyIdentifiers: [UInt32] = []
    private var registeredSettings: AppSwitcherSettings?
    private var allWindows: [SwitchableWindow] = []
    private var windows: [SwitchableWindow] = []
    private var selectedIndex = 0
    private var isSwitching = false
    private var isSearching = false
    private var query = ""
    private var activeModifiers: NSEvent.ModifierFlags = []
    private var showWorkItem: DispatchWorkItem?
    private var modifierMonitors: [Any] = []
    private var keyMonitor: Any?
    private var activationObserver: NSObjectProtocol?
    private var lastActiveProcess: pid_t?

    private var settings: AppSwitcherSettings { AppSettings.shared.values.appSwitcher }
    private var showsThumbnails: Bool { settings.showsThumbnails && ScreenRecordingPermission.isGranted }

    func start() {
        registerHotKeys()
        panel.onSelect = { [weak self] index in
            self?.selectedIndex = index
            self?.commit()
        }
        panel.onHover = { [weak self] index in
            self?.selectedIndex = index
        }
        lastActiveProcess = NSWorkspace.shared.frontmostApplication?.processIdentifier
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.applicationDidActivate(notification)
        }
    }

    func stop() {
        cancel()
        unregisterHotKeys()
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil
        thumbnailCache.clear()
    }

    func settingsDidChange() {
        if !settings.showsThumbnails {
            thumbnailCache.clear()
        }
        guard registeredSettings != settings else { return }
        unregisterHotKeys()
        registerHotKeys()
    }

    private func applicationDidActivate(_ notification: Notification) {
        let previous = lastActiveProcess
        lastActiveProcess = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
        guard showsThumbnails, !isSwitching, let previous, previous != ProcessInfo.processInfo.processIdentifier,
              let windowID = WindowCatalog.frontWindowID(of: previous) else { return }
        _ = WindowThumbnails.capture(windowIDs: [windowID], maximumSize: Self.cachedThumbnailSize) { [weak self] identifier, image in
            self?.thumbnailCache.store(image, for: identifier)
        }
    }

    private func registerHotKeys() {
        let current = settings
        registeredSettings = current
        if let combo = current.activeShortcut {
            registerPair(combo) { [weak self] step in self?.advance(by: step, sameApplication: false) }
        }
        if let combo = current.activeSameApplicationShortcut {
            registerPair(combo) { [weak self] step in self?.advance(by: step, sameApplication: true) }
        }
    }

    private func registerPair(_ combo: KeyCombo, handler: @escaping (Int) -> Void) {
        if let forward = HotKeyCenter.shared.register(combo, handler: { handler(1) }) {
            hotKeyIdentifiers.append(forward)
        }
        guard combo.modifiers & KeyCombo.shift == 0 else { return }
        let reverse = KeyCombo(keyCode: combo.keyCode, modifiers: combo.modifiers | KeyCombo.shift)
        if let backward = HotKeyCenter.shared.register(reverse, handler: { handler(-1) }) {
            hotKeyIdentifiers.append(backward)
        }
    }

    private func unregisterHotKeys() {
        hotKeyIdentifiers.forEach(HotKeyCenter.shared.unregister)
        hotKeyIdentifiers.removeAll()
        registeredSettings = nil
    }

    private func advance(by step: Int, sameApplication: Bool) {
        guard AccessibilityPermission.isTrusted else {
            AccessibilityPermission.requestIfNeeded()
            return
        }
        if !isSwitching {
            begin(step: step, sameApplication: sameApplication)
            return
        }
        move(by: step)
    }

    private func move(by step: Int) {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + step + windows.count) % windows.count
        panel.select(selectedIndex)
    }

    private func begin(step: Int, sameApplication: Bool) {
        var found = WindowCatalog.windows(includingMinimized: settings.includesMinimized)
        if sameApplication, let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier {
            found = found.filter { $0.processIdentifier == frontmost }
        }
        guard !found.isEmpty else { return }
        allWindows = found
        windows = found
        query = ""
        isSearching = false
        isSwitching = true
        selectedIndex = windows.count > 1 ? (step > 0 ? 1 : windows.count - 1) : 0
        let shortcut = sameApplication ? settings.sameApplicationShortcut : settings.shortcut
        activeModifiers = Self.modifierFlags(from: shortcut.modifiers).subtracting(.shift)
        watchModifierRelease()
        guard activeModifiers.isSubset(of: NSEvent.modifierFlags.intersection([.command, .option, .control])) else {
            commit()
            return
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isSwitching else { return }
            self.render(capturingLiveThumbnails: true)
            self.watchKeys()
        }
        showWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(settings.showDelayMilliseconds), execute: work)
    }

    private func render(capturingLiveThumbnails: Bool) {
        let footer: String
        if isSearching {
            footer = query.isEmpty ? String(localized: "Digite para buscar · ⏎ trocar · ⎋ fechar") : String(localized: "Buscar: \(query)  ·  ⏎ trocar · ⌫ apagar · ⎋ fechar")
        } else {
            footer = settings.showsKeyHints ? Self.keyHints : ""
        }
        panel.show(
            windows: windows,
            selectedIndex: selectedIndex,
            iconSize: CGFloat(settings.iconSize),
            showsThumbnails: showsThumbnails,
            cachedThumbnails: thumbnailCache.all,
            footer: footer,
            emptyMessage: isSearching ? String(localized: "Nada encontrado para “\(query)”") : nil,
            capturesLiveThumbnails: capturingLiveThumbnails
        ) { [weak self] identifier, image in
            self?.thumbnailCache.store(image, for: identifier)
        }
    }

    private func watchModifierRelease() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self, self.isSwitching, !self.isSearching else { return }
            let held = event.modifierFlags.intersection([.command, .option, .control])
            if !self.activeModifiers.isSubset(of: held) {
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
            self.handleKey(event)
            return nil
        }
    }

    private func handleKey(_ event: NSEvent) {
        switch event.keyCode {
        case 53:
            cancel()
            return
        case 36, 76:
            commit()
            return
        case 123, 126:
            move(by: -1)
            return
        case 124, 125:
            move(by: 1)
            return
        default:
            break
        }
        let character = (event.charactersIgnoringModifiers ?? "").lowercased()
        if isSearching {
            if event.keyCode == 51 {
                guard !query.isEmpty else { return }
                query.removeLast()
            } else if !character.isEmpty, character.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) {
                query += character
            } else {
                return
            }
            applyQuery()
            return
        }
        switch character {
        case "/":
            isSearching = true
            render(capturingLiveThumbnails: false)
        case "w":
            performOnSelection { window in
                window.close()
                return nil
            }
        case "m":
            performOnSelection { window in
                window.isMinimized ? window : window.minimize()
            }
        case "h":
            removeApplicationOfSelection { NSRunningApplication(processIdentifier: $0)?.hide() }
        case "q":
            removeApplicationOfSelection { NSRunningApplication(processIdentifier: $0)?.terminate() }
        default:
            break
        }
    }

    private func applyQuery() {
        windows = query.isEmpty ? allWindows : allWindows.filter { $0.matches(query) }
        selectedIndex = 0
        render(capturingLiveThumbnails: false)
    }

    private func performOnSelection(_ action: (SwitchableWindow) -> SwitchableWindow?) {
        guard windows.indices.contains(selectedIndex) else { return }
        let target = windows[selectedIndex]
        let replacement = action(target)
        replace(target, with: replacement)
    }

    private func removeApplicationOfSelection(_ action: (pid_t) -> Void) {
        guard windows.indices.contains(selectedIndex) else { return }
        let processIdentifier = windows[selectedIndex].processIdentifier
        action(processIdentifier)
        allWindows.removeAll { $0.processIdentifier == processIdentifier }
        windows.removeAll { $0.processIdentifier == processIdentifier }
        refreshAfterChange()
    }

    private func replace(_ window: SwitchableWindow, with replacement: SwitchableWindow?) {
        for index in allWindows.indices.reversed() where allWindows[index].windowID == window.windowID {
            if let replacement {
                allWindows[index] = replacement
            } else {
                allWindows.remove(at: index)
            }
        }
        for index in windows.indices.reversed() where windows[index].windowID == window.windowID {
            if let replacement {
                windows[index] = replacement
            } else {
                windows.remove(at: index)
            }
        }
        refreshAfterChange()
    }

    private func refreshAfterChange() {
        guard !allWindows.isEmpty else {
            cancel()
            return
        }
        selectedIndex = min(selectedIndex, max(windows.count - 1, 0))
        render(capturingLiveThumbnails: false)
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
        isSearching = false
        query = ""
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
        allWindows.removeAll()
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
    private static let footerHeight: CGFloat = 22
    private static let minimumWidth: CGFloat = 420

    private static let thumbnailTileWidth: CGFloat = 220
    private static let thumbnailHeight: CGFloat = 130

    private static let hoverActivationDistance: CGFloat = 3
    private static let selectionAnimationDuration: TimeInterval = 0.14

    private var window: SwitcherWindow?
    private var tiles: [SwitcherTile] = []
    private var thumbnailTask: Task<Void, Never>?
    private let selectionView = NSView()
    private var selectedTileIndex: Int?
    private var mouseLocationAtShow = NSPoint.zero
    private var isHoverActive = false
    var onSelect: ((Int) -> Void)?
    var onHover: ((Int) -> Void)?

    func show(
        windows: [SwitchableWindow],
        selectedIndex: Int,
        iconSize: CGFloat,
        showsThumbnails: Bool,
        cachedThumbnails: [CGWindowID: NSImage],
        footer: String,
        emptyMessage: String?,
        capturesLiveThumbnails: Bool,
        onLiveThumbnail: @escaping (CGWindowID, NSImage) -> Void
    ) {
        let previousMouseLocation = window == nil ? NSEvent.mouseLocation : mouseLocationAtShow
        let wasHoverActive = window != nil && isHoverActive
        close()
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? .zero
        let tileWidth = showsThumbnails ? Self.thumbnailTileWidth : Self.tileWidth
        let tileHeight = showsThumbnails ? Self.thumbnailHeight + 48 : iconSize + 52
        let maximumColumns = max(1, Int((bounds.width * 0.9 - Self.padding * 2 + Self.tileSpacing) / (tileWidth + Self.tileSpacing)))
        let columns = max(1, min(windows.count, maximumColumns))
        let rows = max(1, Int(ceil(Double(windows.count) / Double(columns))))
        let footerSpace = footer.isEmpty ? 0 : Self.footerHeight
        let gridWidth = CGFloat(columns) * tileWidth + CGFloat(columns - 1) * Self.tileSpacing + Self.padding * 2
        let width = max(gridWidth, footer.isEmpty && emptyMessage == nil ? 0 : Self.minimumWidth)
        let gridHeight = CGFloat(rows) * tileHeight + CGFloat(rows - 1) * Self.tileSpacing
        let height = gridHeight + Self.padding * 2 + footerSpace
        let gridOriginX = (width - gridWidth) / 2

        let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 16
        background.layer?.masksToBounds = true

        selectionView.wantsLayer = true
        selectionView.layer?.cornerRadius = 10
        selectionView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.35).cgColor
        selectionView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.7).cgColor
        selectionView.layer?.borderWidth = 1
        selectionView.isHidden = windows.isEmpty
        background.addSubview(selectionView)
        selectedTileIndex = nil
        mouseLocationAtShow = previousMouseLocation
        isHoverActive = wasHoverActive

        tiles = windows.enumerated().map { index, item in
            let column = index % columns
            let row = index / columns
            let frame = NSRect(
                x: gridOriginX + Self.padding + CGFloat(column) * (tileWidth + Self.tileSpacing),
                y: height - Self.padding - CGFloat(row + 1) * tileHeight - CGFloat(row) * Self.tileSpacing,
                width: tileWidth,
                height: tileHeight
            )
            let tile = SwitcherTile(frame: frame, window: item, iconSize: iconSize, thumbnailHeight: showsThumbnails ? Self.thumbnailHeight : nil) { [weak self] in
                self?.onSelect?(index)
            }
            tile.onHover = { [weak self] in
                self?.handleHover(index)
            }
            if showsThumbnails, let cached = cachedThumbnails[item.windowID] {
                tile.thumbnail = cached
            }
            background.addSubview(tile)
            return tile
        }

        if let emptyMessage, windows.isEmpty {
            let label = NSTextField(labelWithString: emptyMessage)
            label.alignment = .center
            label.textColor = .secondaryLabelColor
            label.frame = NSRect(x: 0, y: footerSpace + Self.padding + gridHeight / 2 - 10, width: width, height: 20)
            background.addSubview(label)
        }

        if !footer.isEmpty {
            let footerLabel = NSTextField(labelWithString: footer)
            footerLabel.alignment = .center
            footerLabel.font = .systemFont(ofSize: 11)
            footerLabel.textColor = .secondaryLabelColor
            footerLabel.lineBreakMode = .byTruncatingTail
            footerLabel.frame = NSRect(x: 10, y: 8, width: width - 20, height: 16)
            background.addSubview(footerLabel)
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
        panel.acceptsMouseMovedEvents = true
        panel.contentView = background
        panel.makeKeyAndOrderFront(nil)
        window = panel
        select(selectedIndex)

        guard showsThumbnails, capturesLiveThumbnails else { return }
        let tilesByWindow = Dictionary(uniqueKeysWithValues: zip(windows.map(\.windowID), tiles))
        let visibleWindowIDs = windows.filter { !$0.isMinimized }.map(\.windowID)
        thumbnailTask = WindowThumbnails.capture(
            windowIDs: visibleWindowIDs,
            maximumSize: CGSize(width: tileWidth - 16, height: Self.thumbnailHeight)
        ) { identifier, image in
            tilesByWindow[identifier]?.thumbnail = image
            onLiveThumbnail(identifier, image)
        }
    }

    func select(_ index: Int) {
        guard tiles.indices.contains(index), index != selectedTileIndex else { return }
        let target = tiles[index].frame
        if selectedTileIndex == nil {
            selectionView.frame = target
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.selectionAnimationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true
                selectionView.animator().frame = target
            }
        }
        selectedTileIndex = index
    }

    private func handleHover(_ index: Int) {
        if !isHoverActive {
            let location = NSEvent.mouseLocation
            let distance = hypot(location.x - mouseLocationAtShow.x, location.y - mouseLocationAtShow.y)
            guard distance >= Self.hoverActivationDistance else { return }
            isHoverActive = true
        }
        select(index)
        onHover?(index)
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
    var onHover: (() -> Void)?
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

    init(frame: NSRect, window: SwitchableWindow, iconSize: CGFloat, thumbnailHeight: CGFloat?, handler: @escaping () -> Void) {
        self.handler = handler
        self.iconSize = iconSize
        super.init(frame: frame)

        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self
        ))

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
        titleLabel.textColor = window.isMinimized ? .secondaryLabelColor : .labelColor
        addSubview(titleLabel)
        toolTip = "\(window.applicationName) — \(window.displayTitle)"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?()
    }

    override func mouseMoved(with event: NSEvent) {
        onHover?()
    }

    override func mouseDown(with event: NSEvent) {
        handler()
    }
}
