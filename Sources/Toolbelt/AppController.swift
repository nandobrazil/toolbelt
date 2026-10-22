import AppKit
import Combine

final class AppController: NSObject {
    private let claudeAccounts = ClaudeAccountsModule()
    private let clipboard = ClipboardModule()
    private let windowLayout = WindowLayoutModule()
    private let menuBarOverflow = MenuBarOverflowModule()
    private lazy var modules: [ToolbeltModule] = [menuBarOverflow, clipboard, windowLayout, claudeAccounts]

    private let settings = AppSettings.shared
    private let panel = ToolbeltPanel()
    private let settingsWindow = SettingsWindowController()
    private var chevronItem: NSStatusItem?
    private var runningModuleIdentifiers: Set<String> = []
    private var settingsSubscription: AnyCancellable?

    func start() {
        NSLog("Toolbelt: started, accessibility trusted=\(AccessibilityPermission.isTrusted)")
        MainMenuBuilder.install { [weak self] in self?.openSettings() }
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
        bridge.loadClaudeEmails = { [weak self] in self?.claudeAccounts.accountEmails() ?? [:] }
        bridge.clearClipboardHistory = { [weak self] in self?.clipboard.clearHistory() }
        bridge.arrangeMenuBar = { [weak self] in self?.menuBarOverflow.toggleArrangeMode() }
        bridge.loginClaude = { [weak self] account in self?.claudeAccounts.login(account) }
    }

    private func applySettings() {
        for module in modules {
            let shouldRun = settings.isModuleEnabled(module.identifier)
            let isRunning = runningModuleIdentifiers.contains(module.identifier)
            if shouldRun && !isRunning {
                startIfEnabled(module)
                if module.requiresAccessibility {
                    AccessibilityPermission.requestIfNeeded()
                }
            } else if !shouldRun && isRunning {
                module.stop()
                runningModuleIdentifiers.remove(module.identifier)
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
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.toolTip = "Toolbelt · clique: painel · ⌥ clique: organizar a barra · clique direito: menu rápido"
        chevronItem = item
    }

    private func updateChevronIcon() {
        let symbolName: String
        if isRunning(menuBarOverflow) && !menuBarOverflow.isCollapsed {
            symbolName = "chevron.right"
        } else {
            symbolName = settings.values.menuBar.iconStyle.symbolName(isOpen: panel.isVisible)
        }
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Toolbelt")
        image?.isTemplate = true
        chevronItem?.button?.image = image
    }

    @objc private func chevronClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
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
        guard let anchor = chevronItem?.button?.window?.frame else { return }
        let hiddenExtras: [MenuBarExtra]?
        if isRunning(menuBarOverflow) && AccessibilityPermission.isTrusted {
            hiddenExtras = menuBarOverflow.hiddenExtras()
        } else {
            hiddenExtras = nil
        }
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
        if isRunning(claudeAccounts) {
            actions.append(PanelAction(title: "Trocar a conta ativa do Claude", symbolName: "person.2.circle") { [weak self] in
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
