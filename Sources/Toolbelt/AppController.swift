import AppKit
import Combine

final class AppController: NSObject {
    private let claudeAccounts = ClaudeAccountsModule()
    private let clipboard = ClipboardModule()
    private let windowLayout = WindowLayoutModule()
    private let menuBarOverflow = MenuBarOverflowModule()
    private let systemMonitor = SystemMonitorModule()
    private let systemReport = SystemReportWindowController()
    private lazy var modules: [ToolbeltModule] = [menuBarOverflow, clipboard, windowLayout, systemMonitor, claudeAccounts]

    private let settings = AppSettings.shared
    private let panel = ToolbeltPanel()
    private let settingsWindow = SettingsWindowController()
    private var chevronItem: NSStatusItem?
    private var runningModuleIdentifiers: Set<String> = []
    private var settingsSubscription: AnyCancellable?
    private static let defaultItemPositions: [String: Double] = [
        "toolbelt.claude": 340,
        "toolbelt.system": 352,
        "toolbelt.chevron": 365,
        "toolbelt.separator": 385
    ]

    func start() {
        NSLog("Toolbelt: started, accessibility trusted=\(AccessibilityPermission.isTrusted)")
        MainMenuBuilder.install { [weak self] in self?.openSettings() }
        restoreMissingItemPositions()
        configureSettingsBridge()

        startIfEnabled(claudeAccounts)
        createChevron()
        menuBarOverflow.onStateChange = { [weak self] in self?.updateChevronIcon() }
        panel.onClose = { [weak self] in self?.updateChevronIcon() }
        for module in modules where module !== claudeAccounts {
            startIfEnabled(module)
        }
        if modules.contains(where: { $0.requiresAccessibility && settings.isModuleEnabled($0.identifier) }) {
            AccessibilityPermission.requestIfNeeded()
        }
        updateChevronIcon()

        settingsSubscription = settings.$values
            .dropFirst()
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.applySettings() }
    }

    private func restoreMissingItemPositions() {
        let defaults = UserDefaults.standard
        for (name, position) in Self.defaultItemPositions {
            let key = "NSStatusItem Preferred Position \(name)"
            if defaults.object(forKey: key) == nil {
                defaults.set(position, forKey: key)
            }
        }
    }

    func openSystemReport() {
        panel.close()
        systemReport.show()
    }

    func openSettings(section: SettingsSection? = nil) {
        panel.close()
        settingsWindow.show(section: section)
    }

    private func configureSettingsBridge() {
        let bridge = settingsWindow.bridge
        bridge.modules = modules.map {
            ModuleInfo(
                id: $0.identifier,
                title: $0.title,
                summary: $0.summary,
                symbolName: $0.symbolName,
                requiresAccessibility: $0.requiresAccessibility
            )
        }
        bridge.loadClipboardStats = { [weak self] in
            guard let clipboard = self?.clipboard else { return ClipboardStats() }
            return ClipboardStats(itemCount: clipboard.historyCount, imageCount: clipboard.imageCount, imageBytes: clipboard.imageBytes)
        }
        bridge.loadClaudeAccounts = { [weak self] in self?.claudeAccounts.accounts ?? [] }
        bridge.renameClaudeAccount = { [weak self] account, alias in self?.claudeAccounts.rename(account, alias: alias) }
        bridge.addClaudeAccount = { [weak self] alias in self?.claudeAccounts.addAccount(alias: alias) }
        bridge.removeClaudeAccount = { [weak self] account in self?.claudeAccounts.remove(account) }
        bridge.useClaudeAccount = { [weak self] account in self?.claudeAccounts.use(account) }
        bridge.openClaudeTerminal = { [weak self] account in self?.claudeAccounts.openTerminal(for: account) }
        claudeAccounts.onOpenSettings = { [weak self] in self?.openSettings(section: .claude) }
        systemMonitor.onOpenReport = { [weak self] in self?.openSystemReport() }
        systemMonitor.onOpenSettings = { [weak self] in self?.openSettings(section: .system) }
        bridge.openSystemReport = { [weak self] in self?.openSystemReport() }
        bridge.clearClipboardHistory = { [weak self] in self?.clipboard.clearHistory() }
        bridge.previewClipboard = { [weak self] in self?.clipboard.togglePicker() }
        bridge.arrangeMenuBar = { [weak self] in self?.menuBarOverflow.toggleArrangeMode() }
        bridge.loginClaude = { [weak self] account in self?.claudeAccounts.login(account) }
    }

    private func applySettings() {
        for module in modules {
            let shouldRun = settings.isModuleEnabled(module.identifier)
            let isRunning = runningModuleIdentifiers.contains(module.identifier)
            if shouldRun && !isRunning {
                restoreMissingItemPositions()
                startIfEnabled(module)
                if module.requiresAccessibility {
                    AccessibilityPermission.requestIfNeeded()
                }
            } else if !shouldRun && isRunning {
                module.stop()
                runningModuleIdentifiers.remove(module.identifier)
                restoreMissingItemPositions()
            } else if isRunning {
                module.settingsDidChange()
            }
        }
        updateChevronIcon()
    }

    private func isRunning(_ module: ToolbeltModule) -> Bool {
        runningModuleIdentifiers.contains(module.identifier)
    }

    private func startIfEnabled(_ module: ToolbeltModule) {
        guard settings.isModuleEnabled(module.identifier), !isRunning(module) else { return }
        module.start()
        runningModuleIdentifiers.insert(module.identifier)
    }

    private func createChevron() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "toolbelt.chevron"
        item.button?.target = self
        item.button?.action = #selector(chevronClicked)
        item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        item.button?.toolTip = "Toolbelt · clique: painel · ⌥ clique: organizar a barra · clique direito: menu rápido"
        chevronItem = item
    }

    private func updateChevronIcon() {
        if isRunning(menuBarOverflow) && !menuBarOverflow.isCollapsed {
            let image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Toolbelt")
            image?.isTemplate = true
            chevronItem?.button?.image = image
            return
        }
        chevronItem?.button?.image = settings.values.menuBar.iconStyle.image(isOpen: panel.isVisible)
    }

    @objc private func chevronClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseDown {
            showQuickMenu()
        } else if event?.modifierFlags.contains(.option) == true, isRunning(menuBarOverflow) {
            panel.close()
            menuBarOverflow.toggleArrangeMode()
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        if panel.isVisible {
            panel.close()
            return
        }
        let showsHiddenItems = isRunning(menuBarOverflow) && AccessibilityPermission.isTrusted
        let cached = showsHiddenItems ? menuBarOverflow.hiddenExtras() : nil
        presentPanel(hiddenExtras: cached)
        guard showsHiddenItems else { return }
        menuBarOverflow.refreshCache { [weak self] fresh in
            guard let self, self.panel.isVisible, let cached, !Self.sameItems(cached, fresh) else { return }
            self.presentPanel(hiddenExtras: fresh)
        }
    }

    private static func sameItems(_ first: [MenuBarExtra], _ second: [MenuBarExtra]) -> Bool {
        first.map { "\($0.processIdentifier)|\($0.label)" } == second.map { "\($0.processIdentifier)|\($0.label)" }
    }

    private func presentPanel(hiddenExtras: [MenuBarExtra]?) {
        guard let anchor = chevronItem?.button?.window?.frame else { return }
        panel.onClose = nil
        panel.show(
            hiddenExtras: hiddenExtras,
            columns: settings.values.menuBar.panelColumns,
            quickActions: quickActions(),
            trailingActions: [
                PanelAction(title: "Configurações", symbolName: "gearshape") { [weak self] in self?.openSettings() },
                PanelAction(title: "Sair do Toolbelt", symbolName: "power") { NSApp.terminate(nil) }
            ],
            below: anchor
        ) { [weak self] extra in
            self?.menuBarOverflow.open(extra)
        }
        panel.onClose = { [weak self] in self?.updateChevronIcon() }
        updateChevronIcon()
    }

    private func quickActions() -> [PanelAction] {
        var actions: [PanelAction] = []
        if isRunning(clipboard) {
            let shortcut = settings.values.clipboard.activeShortcut.map { " (\($0.display))" } ?? ""
            actions.append(PanelAction(title: "Histórico da área de transferência\(shortcut)", symbolName: "doc.on.clipboard") { [weak self] in
                self?.clipboard.togglePicker()
            })
        }
        if isRunning(menuBarOverflow) {
            actions.append(PanelAction(title: "Organizar a barra", symbolName: "arrow.left.and.right.square") { [weak self] in
                self?.menuBarOverflow.toggleArrangeMode()
            })
        }
        if isRunning(windowLayout) {
            actions.append(PanelAction(title: "Atalhos de janela", symbolName: "rectangle.split.2x1") { [weak self] in
                self?.openSettings(section: .windows)
            })
        }
        if isRunning(systemMonitor) {
            actions.append(PanelAction(title: "Relatório do Mac (macscan)", symbolName: "gauge.with.dots.needle.33percent") { [weak self] in
                self?.openSystemReport()
            })
        }
        if isRunning(claudeAccounts) {
            actions.append(PanelAction(title: "Trocar a conta ativa do Claude", symbolName: "sparkle") { [weak self] in
                self?.claudeAccounts.switchAccount()
            })
        }
        return actions
    }

    private func showQuickMenu() {
        guard let chevronItem else { return }
        panel.close()
        let menu = NSMenu()
        menu.addItem(sectionHeader("Toolbelt"))
        for module in modules where isRunning(module) {
            module.menuItems().forEach(menu.addItem)
        }
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(title: "Configurações…", keyEquivalent: ",") { [weak self] in
            self?.openSettings()
        })
        menu.addItem(ActionMenuItem(title: "Sair do Toolbelt", keyEquivalent: "q") {
            NSApp.terminate(nil)
        })
        chevronItem.menu = menu
        chevronItem.button?.performClick(nil)
        chevronItem.menu = nil
    }
}
