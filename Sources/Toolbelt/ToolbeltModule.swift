import AppKit

protocol ToolbeltModule: AnyObject {
    var identifier: String { get }
    var title: String { get }
    var requiresAccessibility: Bool { get }
    func start()
    func stop()
    func menuItems() -> [NSMenuItem]
}

extension ToolbeltModule {
    var requiresAccessibility: Bool { false }
    func menuItems() -> [NSMenuItem] { [] }
}

enum AppPaths {
    static let support: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("Toolbelt", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()
}

enum AccessibilityPermission {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestIfNeeded() {
        guard !isTrusted else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(runHandler), keyEquivalent: keyEquivalent)
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func runHandler() {
        handler()
    }
}

func disabledMenuItem(_ title: String) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.isEnabled = false
    return item
}

func sectionHeader(_ title: String) -> NSMenuItem {
    if #available(macOS 14.0, *) {
        return NSMenuItem.sectionHeader(title: title)
    }
    return disabledMenuItem(title)
}
