import AppKit

final class MenuBarOverflowModule: ToolbeltModule {
    let identifier = "menuBarOverflow"
    let title = "Esconder ícones da barra"
    let requiresAccessibility = true

    private static let collapsedLength: CGFloat = 10_000
    private static let arrangeModeDelay: TimeInterval = 30
    private static let revealSettleDelay: TimeInterval = 0.6
    private static let popupPollInterval: TimeInterval = 0.3
    private static let popupDetectionWindow: TimeInterval = 3
    private static let popupMaximumWait: TimeInterval = 300

    private var separatorItem: NSStatusItem?
    private var autoCollapseTimer: Timer?
    private var popupWatchTimer: Timer?
    private let panel = HiddenItemsPanel()
    private(set) var isCollapsed = false
    var isPanelVisible: Bool { panel.isVisible }
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
        panel.onClose = { [weak self] in self?.onStateChange?() }
        collapse()
    }

    func stop() {
        panel.close()
        autoCollapseTimer?.invalidate()
        popupWatchTimer?.invalidate()
        if let separatorItem {
            NSStatusBar.system.removeStatusItem(separatorItem)
        }
        separatorItem = nil
        isCollapsed = false
        onStateChange?()
    }

    func togglePanel(below anchor: NSRect) {
        if panel.isVisible {
            panel.close()
            return
        }
        if !isCollapsed {
            collapse()
        }
        guard AccessibilityPermission.isTrusted else {
            AccessibilityPermission.requestIfNeeded()
            return
        }
        panel.show(extras: MenuBarExtras.hidden(), below: anchor) { [weak self] extra in
            self?.open(extra)
        }
        onStateChange?()
    }

    func toggleArrangeMode() {
        panel.close()
        if isCollapsed {
            reveal()
            scheduleAutoCollapse(after: Self.arrangeModeDelay)
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

    private func reveal() {
        guard let separatorItem else { return }
        autoCollapseTimer?.invalidate()
        separatorItem.length = NSStatusItem.variableLength
        separatorItem.button?.isHidden = false
        isCollapsed = false
        onStateChange?()
    }

    private func open(_ extra: MenuBarExtra) {
        reveal()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealSettleDelay) { [weak self] in
            extra.press()
            self?.collapseWhenPopupCloses(for: extra.processIdentifier)
        }
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
