import AppKit

final class MenuBarOverflowModule: ToolbeltModule {
    let identifier = "menuBarOverflow"
    let title = "Esconder ícones da barra"
    let summary = "Esconde ícones da barra e mostra todos num painel abaixo da setinha."
    let symbolName = "menubar.arrow.up.rectangle"
    let requiresAccessibility = true

    private static let collapsedLength: CGFloat = 10_000
    private static let revealSettleDelay: TimeInterval = 0.6
    private static let popupPollInterval: TimeInterval = 0.3
    private static let popupDetectionWindow: TimeInterval = 3
    private static let popupMaximumWait: TimeInterval = 300

    private var separatorItem: NSStatusItem?
    private var autoCollapseTimer: Timer?
    private var popupWatchTimer: Timer?
    private static let cacheRefreshInterval: TimeInterval = 15

    private static let moveRevealDelay: TimeInterval = 0.4

    private(set) var isCollapsed = false
    private(set) var cachedExtras: [MenuBarExtra] = []
    private var cachedSeparatorMinX: CGFloat?
    private var isMovingItem = false
    private var cacheTimer: Timer?
    private var isRefreshingCache = false
    private var pendingRefreshCompletions: [([MenuBarExtra]) -> Void] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    var onStateChange: (() -> Void)?

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "toolbelt.separator"
        item.button?.attributedTitle = NSAttributedString(
            string: "┊",
            attributes: [.foregroundColor: NSColor.tertiaryLabelColor]
        )
        item.button?.toolTip = "Arraste com ⌘ os ícones para a esquerda deste traço para escondê-los"
        separatorItem = item
        collapse()
        refreshCache()
        cacheTimer = Timer.scheduledTimer(withTimeInterval: Self.cacheRefreshInterval, repeats: true) { [weak self] _ in
            self?.refreshCache()
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self?.refreshCache() }
            })
        }
    }

    func refreshCache(completion: (([MenuBarExtra]) -> Void)? = nil) {
        if let completion {
            pendingRefreshCompletions.append(completion)
        }
        guard isCollapsed, !isRefreshingCache else { return }
        isRefreshingCache = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let startedAt = Date()
            let extras = MenuBarExtras.all()
            let elapsed = Date().timeIntervalSince(startedAt)
            if elapsed > 0.5 {
                NSLog("Toolbelt: slow menu bar scan, found \(extras.count) items in \(String(format: "%.2f", elapsed)) s")
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRefreshingCache = false
                guard self.isCollapsed else { return }
                self.cachedExtras = extras
                self.cachedSeparatorMinX = self.separatorItem?.button?.window?.frame.minX
                let hidden = MenuBarExtras.hidden(from: extras)
                let completions = self.pendingRefreshCompletions
                self.pendingRefreshCompletions.removeAll()
                completions.forEach { $0(hidden) }
            }
        }
    }

    func stop() {
        cacheTimer?.invalidate()
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceObservers.removeAll()
        autoCollapseTimer?.invalidate()
        popupWatchTimer?.invalidate()
        if let separatorItem {
            NSStatusBar.system.removeStatusItem(separatorItem)
        }
        separatorItem = nil
        isCollapsed = false
        onStateChange?()
    }

    func hiddenExtras() -> [MenuBarExtra] {
        if !isCollapsed {
            collapse()
        }
        return MenuBarExtras.hidden(from: cachedExtras)
    }

    func layout() -> MenuBarLayout {
        guard let separatorX = cachedSeparatorMinX else { return MenuBarLayout() }
        let visibleStart = MenuBarExtras.visibleAreaStart()
        var layout = MenuBarLayout()
        for (extra, identifier) in zip(cachedExtras, MenuBarExtras.identifiers(for: cachedExtras)) {
            let isHidden = extra.frame.minX < separatorX
            let item = MenuBarLayoutItem(
                id: identifier,
                title: extra.title,
                label: extra.label,
                icon: extra.icon,
                systemIdentifier: extra.systemIdentifier,
                isMovable: extra.isMovable,
                isBehindNotch: !isHidden && extra.frame.minX < visibleStart
            )
            if isHidden {
                layout.hidden.append(item)
            } else {
                layout.visible.append(item)
            }
        }
        return layout
    }

    func moveItem(withID identifier: String, to target: MenuBarLayoutTarget, completion: @escaping (MenuBarMoveOutcome) -> Void) {
        guard AccessibilityPermission.isTrusted else {
            completion(.failed("Precisa da permissão de Acessibilidade para mover ícones."))
            return
        }
        guard NSMenu.menuBarVisible() else {
            completion(.failed("A barra de menus está escondida agora (tela cheia ou ocultar automaticamente). Nada foi movido."))
            return
        }
        guard NSApp.isActive, separatorItem != nil, !isMovingItem else {
            completion(.failed("Deixe a janela de Configurações na frente e arraste de novo."))
            return
        }
        isMovingItem = true
        let wasCollapsed = isCollapsed
        reveal()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.moveRevealDelay) { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                let outcome = MenuBarItemMover.move(itemWithID: identifier, to: target) {
                    DispatchQueue.main.sync { self?.separatorItem?.button?.window?.frame }
                }
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isMovingItem = false
                    guard wasCollapsed else {
                        completion(outcome)
                        return
                    }
                    self.collapse()
                    DispatchQueue.main.asyncAfter(deadline: .now() + Self.moveRevealDelay) {
                        self.refreshCache { _ in completion(outcome) }
                    }
                }
            }
        }
    }

    func toggleArrangeMode() {
        if isCollapsed {
            reveal()
            scheduleAutoCollapse(after: TimeInterval(AppSettings.shared.values.menuBar.arrangeModeSeconds))
        } else {
            collapse()
        }
    }

    func collapse() {
        guard let separatorItem else { return }
        autoCollapseTimer?.invalidate()
        popupWatchTimer?.invalidate()
        separatorItem.length = Self.collapsedLength
        separatorItem.button?.isHidden = true
        isCollapsed = true
        onStateChange?()
    }

    func open(_ extra: MenuBarExtra) {
        reveal()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealSettleDelay) { [weak self] in
            extra.press()
            self?.collapseWhenPopupCloses(for: extra.processIdentifier)
        }
    }

    private func reveal() {
        guard let separatorItem else { return }
        autoCollapseTimer?.invalidate()
        separatorItem.length = NSStatusItem.variableLength
        separatorItem.button?.isHidden = false
        isCollapsed = false
        onStateChange?()
    }

    private func collapseWhenPopupCloses(for processIdentifier: pid_t) {
        popupWatchTimer?.invalidate()
        var sawPopup = false
        var elapsed: TimeInterval = 0
        popupWatchTimer = Timer.scheduledTimer(withTimeInterval: Self.popupPollInterval, repeats: true) { [weak self] timer in
            elapsed += Self.popupPollInterval
            let isOpen = MenuBarExtras.hasOpenPopup(for: processIdentifier)
            if isOpen {
                sawPopup = true
            }
            let popupClosed = sawPopup && !isOpen
            let popupNeverAppeared = !sawPopup && elapsed >= Self.popupDetectionWindow
            if popupClosed || popupNeverAppeared || elapsed >= Self.popupMaximumWait {
                timer.invalidate()
                self?.collapse()
            }
        }
    }

    private func scheduleAutoCollapse(after delay: TimeInterval) {
        autoCollapseTimer?.invalidate()
        autoCollapseTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            if NSEvent.modifierFlags.contains(.command) {
                self.scheduleAutoCollapse(after: delay)
            } else {
                self.collapse()
            }
        }
    }
}
