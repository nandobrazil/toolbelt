import AppKit
import Combine

final class AppController: NSObject {
    private let claudeAccounts = ClaudeAccountsModule()
    private let clipboard = ClipboardModule()
    private let windowLayout = WindowLayoutModule()
    private let menuBarOverflow = MenuBarOverflowModule()
    private let systemMonitor = SystemMonitorModule()
    private let appSwitcher = AppSwitcherModule()
    private let systemReport = SystemReportWindowController()
    private let updater = AppUpdater()
    private let crashReporter = CrashReporter.shared
    private let feedbackWindow = FeedbackWindowController()
    private lazy var modules: [ToolbeltModule] = [menuBarOverflow, appSwitcher, clipboard, windowLayout, systemMonitor, claudeAccounts]

    private let settings = AppSettings.shared
    private let panel = ToolbeltPanel()
    private lazy var settingsWindow = SettingsWindowController(updater: updater)
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
        NativeWindowSwitching.restoreOnExit()
        LaunchAtLogin.configureOnFirstLaunch()
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
        updater.onChange = { [weak self] in self?.updateChevronIcon() }
        updater.onOpenSettings = { [weak self] in self?.openSettings(section: .general) }
        updater.start()
        crashReporter.onChange = { [weak self] in self?.updateChevronIcon() }
        crashReporter.onOpenSettings = { [weak self] in self?.openSettings(section: .support) }
        feedbackWindow.enabledModules = { [weak self] in
            guard let self else { return [] }
            return self.modules.filter { self.isRunning($0) }.map(\.identifier)
        }
        crashReporter.start()

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
        systemMonitor.onChange = { [weak self] in self?.updateChevronIcon() }
        claudeAccounts.onChange = { [weak self] in self?.updateChevronIcon() }
        systemMonitor.onOpenSettings = { [weak self] in self?.openSettings(section: .system) }
        bridge.openSystemReport = { [weak self] in self?.openSystemReport() }
        bridge.clearClipboardHistory = { [weak self] in self?.clipboard.clearHistory() }
        bridge.previewClipboard = { [weak self] in self?.clipboard.togglePicker() }
        bridge.arrangeMenuBar = { [weak self] in self?.menuBarOverflow.toggleArrangeMode() }
        bridge.loginClaude = { [weak self] account in self?.claudeAccounts.login(account) }
        bridge.openFeedback = { [weak self] kind in self?.feedbackWindow.show(kind: kind) }
        bridge.loadMenuBarLayout = { [weak self] in
            guard let self, self.isRunning(self.menuBarOverflow) else { return MenuBarLayout() }
            return self.menuBarOverflow.layout()
        }
        bridge.moveMenuBarItem = { [weak self] identifier, target, completion in
            guard let self, self.isRunning(self.menuBarOverflow) else {
                completion(.failed("Ative o módulo da barra de menus para organizar os ícones."))
                return
            }
            self.menuBarOverflow.moveItem(withID: identifier, to: target, completion: completion)
        }
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
        updater.settingsDidChange()
        crashReporter.settingsDidChange()
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
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "toolbelt.chevron"
        item.button?.imagePosition = .imageLeading
        item.button?.target = self
        item.button?.action = #selector(chevronClicked)
        item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        item.button?.toolTip = "Toolbelt · clique: painel · ⌥ clique: organizar a barra · clique direito: menu rápido"
        chevronItem = item
    }

    private func updateChevronIcon() {
        guard let button = chevronItem?.button else { return }
        if isRunning(menuBarOverflow) && !menuBarOverflow.isCollapsed {
            let image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Toolbelt")
            image?.isTemplate = true
            button.image = image
        } else {
            button.image = settings.values.menuBar.iconStyle.image(isOpen: panel.isVisible)
        }
        let title = NSMutableAttributedString(attributedString: inlineTitle())
        let dotFont = NSFont.systemFont(ofSize: NSFont.systemFontSize - 3)
        if updater.availableRelease != nil {
            title.append(NSAttributedString(string: " ●", attributes: [.font: dotFont, .foregroundColor: NSColor.controlAccentColor]))
        }
        if !crashReporter.pending.isEmpty {
            title.append(NSAttributedString(string: " ●", attributes: [.font: dotFont, .foregroundColor: NSColor.systemOrange]))
        }
        button.attributedTitle = title
    }

    private func inlineTitle() -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let title = NSMutableAttributedString()
        func append(_ text: String, color: NSColor = .labelColor) {
            title.append(NSAttributedString(string: (title.length == 0 ? " " : " · ") + text, attributes: [.font: font, .foregroundColor: color]))
        }
        let snapshot = systemMonitor.snapshot
        let activeAccount = isRunning(claudeAccounts) ? claudeAccounts.activeAccount : nil
        for info in settings.values.menuBar.inlineInfo {
            switch info {
            case .claudeAccount:
                guard let activeAccount else { continue }
                let dotColor = NSColor(hex: settings.values.claude.colorHex(for: activeAccount.account))
                title.append(NSAttributedString(string: title.length == 0 ? " ●" : " · ●", attributes: [.font: font, .foregroundColor: dotColor]))
                title.append(NSAttributedString(string: " " + activeAccount.shortName, attributes: [.font: font, .foregroundColor: NSColor.labelColor]))
            case .claudeUsage:
                if let percent = activeAccount?.fiveHour.currentPercent {
                    append("\(percent)%", color: percent >= 90 ? .systemOrange : .labelColor)
                }
            case .memory:
                guard isRunning(systemMonitor) else { continue }
                append("RAM \(Int((snapshot.memoryUsedRatio * 100).rounded()))%", color: snapshot.pressureLevel >= 2 ? .systemOrange : .labelColor)
            case .swap:
                guard isRunning(systemMonitor) else { continue }
                append("swap \(ByteFormat.memory(snapshot.swapUsed))")
            case .disk:
                guard isRunning(systemMonitor) else { continue }
                append(ByteFormat.storage(snapshot.diskFree), color: snapshot.diskFreeRatio < 0.1 ? .systemOrange : .labelColor)
            }
        }
        return title
    }

    private func panelSections() -> [NSView] {
        var sections: [NSView] = []
        if let crashSection = PanelSections.crash(
            pending: crashReporter.pending,
            onSend: { [weak self] in
                self?.panel.close()
                self?.crashReporter.sendPending(rememberChoice: false)
            },
            onAlways: { [weak self] in
                self?.panel.close()
                self?.crashReporter.sendPending(rememberChoice: true)
            },
            onDismiss: { [weak self] in
                self?.panel.close()
                self?.crashReporter.dismissPending()
            }
        ) {
            sections.append(crashSection)
        }
        if let updateSection = PanelSections.update(state: updater.state, onInstall: { [weak self] in
            self?.panel.close()
            self?.updater.installAvailableUpdate()
        }) {
            sections.append(updateSection)
        }
        if settings.values.menuBar.panelShowsClaude && isRunning(claudeAccounts) && !claudeAccounts.accounts.isEmpty {
            sections.append(PanelSections.claude(
                accounts: claudeAccounts.accounts,
                onUse: { [weak self] account in
                    self?.panel.close()
                    self?.claudeAccounts.use(account)
                },
                onOpenTerminal: { [weak self] account in
                    self?.panel.close()
                    self?.claudeAccounts.openTerminal(for: account)
                }
            ))
        }
        if settings.values.menuBar.panelShowsSystem && isRunning(systemMonitor) {
            systemMonitor.sample()
            sections.append(PanelSections.system(snapshot: systemMonitor.snapshot) { [weak self] in
                self?.openSystemReport()
            })
        }
        return sections
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
            sections: panelSections(),
            quickActions: quickActions(),
            trailingActions: [
                PanelAction(title: "Relatar um problema", symbolName: "exclamationmark.bubble") { [weak self] in self?.feedbackWindow.show(kind: .bug) },
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
        if let release = updater.availableRelease {
            menu.addItem(ActionMenuItem(title: "Atualizar para a versão \(release.version)") { [weak self] in
                self?.updater.installAvailableUpdate()
            })
        } else {
            menu.addItem(ActionMenuItem(title: "Verificar atualizações…") { [weak self] in
                self?.updater.check(userInitiated: true)
                self?.openSettings(section: .general)
            })
        }
        menu.addItem(ActionMenuItem(title: "Relatar um problema…") { [weak self] in
            self?.feedbackWindow.show(kind: .bug)
        })
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
