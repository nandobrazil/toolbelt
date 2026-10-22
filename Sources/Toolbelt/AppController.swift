import AppKit

final class AppController: NSObject {
    private let claudeAccounts = ClaudeAccountsModule()
    private let clipboard = ClipboardModule()
    private let windowLayout = WindowLayoutModule()
    private let menuBarOverflow = MenuBarOverflowModule()
    private lazy var modules: [ToolbeltModule] = [claudeAccounts, clipboard, windowLayout, menuBarOverflow]

    private var chevronItem: NSStatusItem?
    private var runningModuleIdentifiers: Set<String> = []
    private let defaults = UserDefaults.standard

    func start() {
        NSLog("Toolbelt: started, accessibility trusted=\(AccessibilityPermission.isTrusted)")
        let enabledModules = modules.filter(isEnabled)
        startIfEnabled(claudeAccounts)
        createChevron()
        menuBarOverflow.onStateChange = { [weak self] in self?.updateChevronIcon() }
        for module in modules where module !== claudeAccounts {
            startIfEnabled(module)
        }
        if enabledModules.contains(where: { $0.requiresAccessibility }) {
            AccessibilityPermission.requestIfNeeded()
        }
        updateChevronIcon()
    }

    private func isEnabled(_ module: ToolbeltModule) -> Bool {
        defaults.object(forKey: enabledKey(module)) as? Bool ?? true
    }

    private func enabledKey(_ module: ToolbeltModule) -> String {
        "module.\(module.identifier).enabled"
    }

    private func startIfEnabled(_ module: ToolbeltModule) {
        guard isEnabled(module), !runningModuleIdentifiers.contains(module.identifier) else { return }
        module.start()
        runningModuleIdentifiers.insert(module.identifier)
    }

    private func setEnabled(_ module: ToolbeltModule, _ enabled: Bool) {
        defaults.set(enabled, forKey: enabledKey(module))
        if enabled {
            startIfEnabled(module)
            if module.requiresAccessibility {
                AccessibilityPermission.requestIfNeeded()
            }
        } else if runningModuleIdentifiers.contains(module.identifier) {
            module.stop()
            runningModuleIdentifiers.remove(module.identifier)
        }
        updateChevronIcon()
    }

    private func createChevron() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "toolbelt.chevron"
        item.button?.target = self
        item.button?.action = #selector(chevronClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.toolTip = "Clique: ícones escondidos · ⌥ clique: organizar a barra · Clique direito: menu do Toolbelt"
        chevronItem = item
    }

    private func updateChevronIcon() {
        let overflowRunning = runningModuleIdentifiers.contains(menuBarOverflow.identifier)
        let symbolName: String
        if !overflowRunning {
            symbolName = "wrench.and.screwdriver"
        } else if !menuBarOverflow.isCollapsed {
            symbolName = "chevron.right"
        } else {
            symbolName = menuBarOverflow.isPanelVisible ? "chevron.up" : "chevron.down"
        }
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Toolbelt")
        image?.isTemplate = true
        chevronItem?.button?.image = image
    }

    @objc private func chevronClicked() {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
        let isOptionClick = NSApp.currentEvent?.modifierFlags.contains(.option) ?? false
        let overflowRunning = runningModuleIdentifiers.contains(menuBarOverflow.identifier)
        if isRightClick || !overflowRunning {
            showMainMenu()
        } else if isOptionClick {
            menuBarOverflow.toggleArrangeMode()
        } else if let anchor = chevronItem?.button?.window?.frame {
            menuBarOverflow.togglePanel(below: anchor)
        }
    }

    private func showMainMenu() {
        guard let chevronItem else { return }
        chevronItem.menu = buildMainMenu()
        chevronItem.button?.performClick(nil)
        chevronItem.menu = nil
    }

    private func buildMainMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(sectionHeader("Toolbelt"))

        for module in modules where runningModuleIdentifiers.contains(module.identifier) {
            module.menuItems().forEach(menu.addItem)
        }

        menu.addItem(.separator())
        if !AccessibilityPermission.isTrusted && modules.contains(where: { $0.requiresAccessibility && isEnabled($0) }) {
            menu.addItem(ActionMenuItem(title: "⚠︎ Permitir Acessibilidade…") {
                AccessibilityPermission.requestIfNeeded()
                AccessibilityPermission.openSettings()
            })
        }

        let modulesItem = NSMenuItem(title: "Módulos", action: nil, keyEquivalent: "")
        let modulesMenu = NSMenu()
        for module in modules {
            let item = ActionMenuItem(title: module.title) { [weak self] in
                guard let self else { return }
                self.setEnabled(module, !self.isEnabled(module))
            }
            item.state = isEnabled(module) ? .on : .off
            modulesMenu.addItem(item)
        }
        modulesItem.submenu = modulesMenu
        menu.addItem(modulesItem)

        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(title: "Sair do Toolbelt", keyEquivalent: "q") {
            NSApp.terminate(nil)
        })
        return menu
    }
}
