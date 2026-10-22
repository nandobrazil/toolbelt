import AppKit
import SwiftUI

final class SettingsWindowController: NSObject, NSWindowDelegate {
    let bridge = SettingsBridge()
    private let updater: AppUpdater
    private var window: NSWindow?

    init(updater: AppUpdater) {
        self.updater = updater
        super.init()
    }

    func show(section: SettingsSection? = nil) {
        if let section {
            bridge.selection = section
        }
        bridge.refresh()
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(rootView: SettingsView(settings: AppSettings.shared, bridge: bridge, updater: updater))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Configurações do Toolbelt"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(NSSize(width: 780, height: 560))
        window.center()
        window.setFrameAutosaveName("ToolbeltSettings")
        return window
    }
}

enum MainMenuBuilder {
    static func install(openSettings: @escaping () -> Void) {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(ActionMenuItem(title: "Configurações…", keyEquivalent: ",", handler: openSettings))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Sair do Toolbelt", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Editar")
        editMenu.addItem(NSMenuItem(title: "Desfazer", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Refazer", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Recortar", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Colar", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Selecionar tudo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Janela")
        windowMenu.addItem(NSMenuItem(title: "Fechar", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        windowMenu.addItem(NSMenuItem(title: "Minimizar", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)

        NSApp.mainMenu = mainMenu
    }
}
