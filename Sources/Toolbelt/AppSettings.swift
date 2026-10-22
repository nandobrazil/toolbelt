import AppKit
import Combine

enum ChevronStyle: String, Codable, CaseIterable, Identifiable {
    case chevron
    case dots
    case toolbox

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chevron: return "Seta"
        case .dots: return "Três pontos"
        case .toolbox: return "Caixa de ferramentas"
        }
    }

    func symbolName(isOpen: Bool) -> String {
        switch self {
        case .chevron: return isOpen ? "chevron.up" : "chevron.down"
        case .dots: return isOpen ? "ellipsis.circle.fill" : "ellipsis.circle"
        case .toolbox: return isOpen ? "wrench.and.screwdriver.fill" : "wrench.and.screwdriver"
        }
    }
}

enum PickerPosition: String, Codable, CaseIterable, Identifiable {
    case cursor
    case screenCenter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cursor: return "Junto ao cursor"
        case .screenCenter: return "Centro da tela"
        }
    }
}

struct MenuBarSettings: Codable, Equatable {
    var iconStyle: ChevronStyle = .chevron
    var panelColumns = 10
    var arrangeModeSeconds = 30

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = MenuBarSettings()
        iconStyle = (try? container.decodeIfPresent(ChevronStyle.self, forKey: .iconStyle)) ?? defaults.iconStyle
        panelColumns = (try? container.decodeIfPresent(Int.self, forKey: .panelColumns)) ?? defaults.panelColumns
        arrangeModeSeconds = (try? container.decodeIfPresent(Int.self, forKey: .arrangeModeSeconds)) ?? defaults.arrangeModeSeconds
    }
}

struct ClipboardSettings: Codable, Equatable {
    static let defaultShortcut = KeyCombo(keyCode: 9, modifiers: KeyCombo.option | KeyCombo.command)

    var shortcut: KeyCombo = ClipboardSettings.defaultShortcut
    var isShortcutEnabled = true
    var historyLimit = 40
    var imageLimit = 20
    var captureCopiedImages = true
    var captureScreenshots = true
    var pasteAutomatically = true
    var pickerPosition: PickerPosition = .cursor
    var ignoredBundleIdentifiers: [String] = []

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ClipboardSettings()
        shortcut = (try? container.decodeIfPresent(KeyCombo.self, forKey: .shortcut)) ?? defaults.shortcut
        isShortcutEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isShortcutEnabled)) ?? true
        historyLimit = (try? container.decodeIfPresent(Int.self, forKey: .historyLimit)) ?? defaults.historyLimit
        imageLimit = (try? container.decodeIfPresent(Int.self, forKey: .imageLimit)) ?? defaults.imageLimit
        captureCopiedImages = (try? container.decodeIfPresent(Bool.self, forKey: .captureCopiedImages)) ?? defaults.captureCopiedImages
        captureScreenshots = (try? container.decodeIfPresent(Bool.self, forKey: .captureScreenshots)) ?? defaults.captureScreenshots
        pasteAutomatically = (try? container.decodeIfPresent(Bool.self, forKey: .pasteAutomatically)) ?? defaults.pasteAutomatically
        pickerPosition = (try? container.decodeIfPresent(PickerPosition.self, forKey: .pickerPosition)) ?? defaults.pickerPosition
        ignoredBundleIdentifiers = (try? container.decodeIfPresent([String].self, forKey: .ignoredBundleIdentifiers)) ?? defaults.ignoredBundleIdentifiers
    }

    var activeShortcut: KeyCombo? {
        get { isShortcutEnabled ? shortcut : nil }
        set {
            isShortcutEnabled = newValue != nil
            if let newValue {
                shortcut = newValue
            }
        }
    }
}

struct WindowSettings: Codable, Equatable {
    var shortcutOverrides: [String: KeyCombo] = [:]
    var disabledLayouts: [String] = []
    var gap = 0

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shortcutOverrides = (try? container.decodeIfPresent([String: KeyCombo].self, forKey: .shortcutOverrides)) ?? [:]
        disabledLayouts = (try? container.decodeIfPresent([String].self, forKey: .disabledLayouts)) ?? []
        gap = (try? container.decodeIfPresent(Int.self, forKey: .gap)) ?? 0
    }

    func shortcut(for layout: WindowLayout) -> KeyCombo? {
        guard !disabledLayouts.contains(layout.rawValue) else { return nil }
        return shortcutOverrides[layout.rawValue] ?? layout.defaultCombo
    }

    mutating func setShortcut(_ combo: KeyCombo?, for layout: WindowLayout) {
        guard let combo else {
            if !disabledLayouts.contains(layout.rawValue) {
                disabledLayouts.append(layout.rawValue)
            }
            return
        }
        disabledLayouts.removeAll { $0 == layout.rawValue }
        shortcutOverrides[layout.rawValue] = combo == layout.defaultCombo ? nil : combo
    }
}

struct ClaudeSettings: Codable, Equatable {
    var showUsageInTitle = true
    var accountNames: [String: String] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showUsageInTitle = (try? container.decodeIfPresent(Bool.self, forKey: .showUsageInTitle)) ?? true
        accountNames = (try? container.decodeIfPresent([String: String].self, forKey: .accountNames)) ?? [:]
    }

    func displayName(for account: String) -> String {
        let custom = accountNames[account]?.trimmingCharacters(in: .whitespaces) ?? ""
        return custom.isEmpty ? "Conta \(account.uppercased())" : custom
    }
}

struct SettingsValues: Codable, Equatable {
    var enabledModules: [String: Bool] = [:]
    var menuBar = MenuBarSettings()
    var clipboard = ClipboardSettings()
    var windows = WindowSettings()
    var claude = ClaudeSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabledModules = (try? container.decodeIfPresent([String: Bool].self, forKey: .enabledModules)) ?? [:]
        menuBar = (try? container.decodeIfPresent(MenuBarSettings.self, forKey: .menuBar)) ?? MenuBarSettings()
        clipboard = (try? container.decodeIfPresent(ClipboardSettings.self, forKey: .clipboard)) ?? ClipboardSettings()
        windows = (try? container.decodeIfPresent(WindowSettings.self, forKey: .windows)) ?? WindowSettings()
        claude = (try? container.decodeIfPresent(ClaudeSettings.self, forKey: .claude)) ?? ClaudeSettings()
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private static let storageKey = "settings.v1"
    private let defaults = UserDefaults.standard

    @Published var values: SettingsValues {
        didSet {
            guard values != oldValue else { return }
            save()
        }
    }

    private init() {
        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode(SettingsValues.self, from: data) {
            values = stored
        } else {
            var initial = SettingsValues()
            for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("module.") && key.hasSuffix(".enabled") {
                let identifier = String(key.dropFirst("module.".count).dropLast(".enabled".count))
                initial.enabledModules[identifier] = defaults.bool(forKey: key)
            }
            values = initial
        }
    }

    func isModuleEnabled(_ identifier: String) -> Bool {
        values.enabledModules[identifier] ?? true
    }

    func setModule(_ identifier: String, enabled: Bool) {
        values.enabledModules[identifier] = enabled
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(values) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

enum LaunchAtLogin {
    static let label = "dev.oconde.toolbelt"

    private static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: agentURL.path)
    }

    static func setEnabled(_ enabled: Bool) {
        if !enabled {
            try? FileManager.default.removeItem(at: agentURL)
            return
        }
        guard let executable = Bundle.main.executablePath else { return }
        let logPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Toolbelt.log").path
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable],
            "StandardErrorPath": logPath,
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        do {
            try FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: agentURL, options: .atomic)
        } catch {
            NSLog("Toolbelt: failed to write launch agent: \(error)")
        }
    }
}
