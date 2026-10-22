import AppKit

final class MenuBarOverflowModule: ToolbeltModule {
    let identifier = "menuBarOverflow"
    let title = "Esconder ícones da barra"

    private static let collapsedLength: CGFloat = 10_000
    private static let autoCollapseDelay: TimeInterval = 15

    private var separatorItem: NSStatusItem?
    private var autoCollapseTimer: Timer?
    private(set) var isCollapsed = false
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
    }

    func stop() {
        autoCollapseTimer?.invalidate()
        if let separatorItem {
            NSStatusBar.system.removeStatusItem(separatorItem)
        }
        separatorItem = nil
        isCollapsed = false
        onStateChange?()
    }

    func toggle() {
        isCollapsed ? expand() : collapse()
    }

    func expand() {
        guard let separatorItem else { return }
        separatorItem.length = NSStatusItem.variableLength
        separatorItem.button?.isHidden = false
        isCollapsed = false
        scheduleAutoCollapse()
        onStateChange?()
    }

    func collapse() {
        guard let separatorItem else { return }
        autoCollapseTimer?.invalidate()
        separatorItem.length = Self.collapsedLength
        separatorItem.button?.isHidden = true
        isCollapsed = true
        onStateChange?()
    }

    private func scheduleAutoCollapse() {
        autoCollapseTimer?.invalidate()
        autoCollapseTimer = Timer.scheduledTimer(withTimeInterval: Self.autoCollapseDelay, repeats: false) { [weak self] _ in
            guard let self else { return }
            if NSEvent.modifierFlags.contains(.command) {
                self.scheduleAutoCollapse()
            } else {
                self.collapse()
            }
        }
    }
}
