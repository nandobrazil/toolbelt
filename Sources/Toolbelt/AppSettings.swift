import AppKit
import Combine

enum ChevronStyle: String, Codable, CaseIterable, Identifiable {
    case belt
    case chevron
    case dots
    case toolbox

    var id: String { rawValue }

    var title: String {
        switch self {
        case .belt: return "Cinto"
        case .chevron: return "Seta"
        case .dots: return "Três pontos"
        case .toolbox: return "Caixa de ferramentas"
        }
    }

    func image(isOpen: Bool) -> NSImage? {
        guard let symbolName = systemSymbolName(isOpen: isOpen) else {
            return ToolbeltIcon.image(isOpen: isOpen)
        }
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Toolbelt")
        image?.isTemplate = true
        return image
    }

    private func systemSymbolName(isOpen: Bool) -> String? {
        switch self {
        case .belt: return nil
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

enum PanelTheme: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Do sistema"
        case .light: return "Claro"
        case .dark: return "Escuro"
        }
    }
}

enum PanelBackground: String, Codable, CaseIterable, Identifiable {
    case glass
    case frosted
    case solid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass: return "Vidro transparente"
        case .frosted: return "Fosco"
        case .solid: return "Sólido"
        }
    }
}

struct ClipboardPanelAppearance: Codable, Equatable {
    var theme: PanelTheme = .system
    var background: PanelBackground = .frosted
    var backgroundOpacity = 1.0
    var width = 420.0
    var fontSize = 13.0
    var imageHeight = 72.0
    var cornerRadius = 12.0
    var maximumHeight = 520.0
    var showsShortcutNumbers = true

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ClipboardPanelAppearance()
        theme = (try? container.decodeIfPresent(PanelTheme.self, forKey: .theme)) ?? defaults.theme
        background = (try? container.decodeIfPresent(PanelBackground.self, forKey: .background)) ?? defaults.background
        backgroundOpacity = (try? container.decodeIfPresent(Double.self, forKey: .backgroundOpacity)) ?? defaults.backgroundOpacity
        width = (try? container.decodeIfPresent(Double.self, forKey: .width)) ?? defaults.width
        fontSize = (try? container.decodeIfPresent(Double.self, forKey: .fontSize)) ?? defaults.fontSize
        imageHeight = (try? container.decodeIfPresent(Double.self, forKey: .imageHeight)) ?? defaults.imageHeight
        cornerRadius = (try? container.decodeIfPresent(Double.self, forKey: .cornerRadius)) ?? defaults.cornerRadius
        maximumHeight = (try? container.decodeIfPresent(Double.self, forKey: .maximumHeight)) ?? defaults.maximumHeight
        showsShortcutNumbers = (try? container.decodeIfPresent(Bool.self, forKey: .showsShortcutNumbers)) ?? defaults.showsShortcutNumbers
    }
}

enum InlineInfo: String, Codable, CaseIterable, Identifiable {
    case claudeAccount
    case claudeUsage
    case memory
    case swap
    case disk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claudeAccount: return "Conta ativa do Claude"
        case .claudeUsage: return "Uso de 5 h do Claude"
        case .memory: return "RAM em uso (%)"
        case .swap: return "Swap em uso"
        case .disk: return "Espaço livre no disco"
        }
    }
}

struct MenuBarSettings: Codable, Equatable {
    var iconStyle: ChevronStyle = .belt
    var panelColumns = 10
    var arrangeModeSeconds = 30
    var inlineInfo: [InlineInfo] = []
    var panelShowsClaude = true
    var panelShowsSystem = true

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = MenuBarSettings()
        inlineInfo = (try? container.decodeIfPresent([InlineInfo].self, forKey: .inlineInfo)) ?? defaults.inlineInfo
        panelShowsClaude = (try? container.decodeIfPresent(Bool.self, forKey: .panelShowsClaude)) ?? defaults.panelShowsClaude
        panelShowsSystem = (try? container.decodeIfPresent(Bool.self, forKey: .panelShowsSystem)) ?? defaults.panelShowsSystem
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
    var isArchiveEnabled = false
    var archiveFolderPath = ClipboardSettings.defaultArchiveFolderPath
    var archiveIncludesImages = true
    var appearance = ClipboardPanelAppearance()

    static let defaultArchiveFolderPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/Clipboard History", isDirectory: true).path

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
        isArchiveEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isArchiveEnabled)) ?? defaults.isArchiveEnabled
        archiveFolderPath = (try? container.decodeIfPresent(String.self, forKey: .archiveFolderPath)) ?? defaults.archiveFolderPath
        archiveIncludesImages = (try? container.decodeIfPresent(Bool.self, forKey: .archiveIncludesImages)) ?? defaults.archiveIncludesImages
        appearance = (try? container.decodeIfPresent(ClipboardPanelAppearance.self, forKey: .appearance)) ?? defaults.appearance
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
    static let palette = ["#D97757", "#3B82F6", "#22C55E", "#A855F7", "#EC4899", "#EAB308", "#14B8A6", "#64748B"]

    var showUsageInTitle = true
    var showNameInTitle = true
    var showInMenuBar = true
    var accountColors: [String: String] = [:]
    var terminalShortcuts: [String: KeyCombo] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showUsageInTitle = (try? container.decodeIfPresent(Bool.self, forKey: .showUsageInTitle)) ?? true
        showNameInTitle = (try? container.decodeIfPresent(Bool.self, forKey: .showNameInTitle)) ?? true
        showInMenuBar = (try? container.decodeIfPresent(Bool.self, forKey: .showInMenuBar)) ?? true
        accountColors = (try? container.decodeIfPresent([String: String].self, forKey: .accountColors)) ?? [:]
        terminalShortcuts = (try? container.decodeIfPresent([String: KeyCombo].self, forKey: .terminalShortcuts)) ?? [:]
    }

    func colorHex(for account: String) -> String {
        if let custom = accountColors[account] {
            return custom
        }
        let index = max((Int(account) ?? 1) - 1, 0)
        return Self.palette[index % Self.palette.count]
    }
}

extension NSColor {
    convenience init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt32(digits, radix: 16) ?? 0x888888
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    var hexString: String {
        let color = usingColorSpace(.sRGB) ?? self
        return String(
            format: "#%02X%02X%02X",
            Int((color.redComponent * 255).rounded()),
            Int((color.greenComponent * 255).rounded()),
            Int((color.blueComponent * 255).rounded())
        )
    }
}

struct SystemMonitorSettings: Codable, Equatable {
    var showInMenuBar = true
    var showsMemory = true
    var showsDisk = true
    var showsSwap = false
    var refreshSeconds = 15
    var alertsEnabled = true
    var diskWarningPercent = 10
    var swapWarningGigabytes = 4

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SystemMonitorSettings()
        showInMenuBar = (try? container.decodeIfPresent(Bool.self, forKey: .showInMenuBar)) ?? defaults.showInMenuBar
        showsMemory = (try? container.decodeIfPresent(Bool.self, forKey: .showsMemory)) ?? defaults.showsMemory
        showsDisk = (try? container.decodeIfPresent(Bool.self, forKey: .showsDisk)) ?? defaults.showsDisk
        showsSwap = (try? container.decodeIfPresent(Bool.self, forKey: .showsSwap)) ?? defaults.showsSwap
        refreshSeconds = (try? container.decodeIfPresent(Int.self, forKey: .refreshSeconds)) ?? defaults.refreshSeconds
        alertsEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .alertsEnabled)) ?? defaults.alertsEnabled
        diskWarningPercent = (try? container.decodeIfPresent(Int.self, forKey: .diskWarningPercent)) ?? defaults.diskWarningPercent
        swapWarningGigabytes = (try? container.decodeIfPresent(Int.self, forKey: .swapWarningGigabytes)) ?? defaults.swapWarningGigabytes
    }
}

struct AppSwitcherSettings: Codable, Equatable {
    static let defaultShortcut = KeyCombo(keyCode: 48, modifiers: KeyCombo.option)
    static let defaultSameApplicationShortcut = KeyCombo(keyCode: 50, modifiers: KeyCombo.option)

    var shortcut = AppSwitcherSettings.defaultShortcut
    var isShortcutEnabled = true
    var sameApplicationShortcut = AppSwitcherSettings.defaultSameApplicationShortcut
    var isSameApplicationShortcutEnabled = true
    var showsKeyHints = true
    var includesMinimized = true
    var showDelayMilliseconds = 120
    var iconSize = 64
    var showsThumbnails = false

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSwitcherSettings()
        showsThumbnails = (try? container.decodeIfPresent(Bool.self, forKey: .showsThumbnails)) ?? defaults.showsThumbnails
        sameApplicationShortcut = (try? container.decodeIfPresent(KeyCombo.self, forKey: .sameApplicationShortcut)) ?? defaults.sameApplicationShortcut
        isSameApplicationShortcutEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isSameApplicationShortcutEnabled)) ?? defaults.isSameApplicationShortcutEnabled
        showsKeyHints = (try? container.decodeIfPresent(Bool.self, forKey: .showsKeyHints)) ?? defaults.showsKeyHints
        shortcut = (try? container.decodeIfPresent(KeyCombo.self, forKey: .shortcut)) ?? defaults.shortcut
        isShortcutEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isShortcutEnabled)) ?? defaults.isShortcutEnabled
        includesMinimized = (try? container.decodeIfPresent(Bool.self, forKey: .includesMinimized)) ?? defaults.includesMinimized
        showDelayMilliseconds = (try? container.decodeIfPresent(Int.self, forKey: .showDelayMilliseconds)) ?? defaults.showDelayMilliseconds
        iconSize = (try? container.decodeIfPresent(Int.self, forKey: .iconSize)) ?? defaults.iconSize
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

    var activeSameApplicationShortcut: KeyCombo? {
        get { isSameApplicationShortcutEnabled ? sameApplicationShortcut : nil }
        set {
            isSameApplicationShortcutEnabled = newValue != nil
            if let newValue {
                sameApplicationShortcut = newValue
            }
        }
    }
}

struct SettingsValues: Codable, Equatable {
    var enabledModules: [String: Bool] = [:]
    var menuBar = MenuBarSettings()
    var clipboard = ClipboardSettings()
    var windows = WindowSettings()
    var claude = ClaudeSettings()
    var systemMonitor = SystemMonitorSettings()
    var appSwitcher = AppSwitcherSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabledModules = (try? container.decodeIfPresent([String: Bool].self, forKey: .enabledModules)) ?? [:]
        menuBar = (try? container.decodeIfPresent(MenuBarSettings.self, forKey: .menuBar)) ?? MenuBarSettings()
        clipboard = (try? container.decodeIfPresent(ClipboardSettings.self, forKey: .clipboard)) ?? ClipboardSettings()
        windows = (try? container.decodeIfPresent(WindowSettings.self, forKey: .windows)) ?? WindowSettings()
        claude = (try? container.decodeIfPresent(ClaudeSettings.self, forKey: .claude)) ?? ClaudeSettings()
        systemMonitor = (try? container.decodeIfPresent(SystemMonitorSettings.self, forKey: .systemMonitor)) ?? SystemMonitorSettings()
        appSwitcher = (try? container.decodeIfPresent(AppSwitcherSettings.self, forKey: .appSwitcher)) ?? AppSwitcherSettings()
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
