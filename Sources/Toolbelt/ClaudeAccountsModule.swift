import AppKit

struct ClaudeUsageWindow: Decodable {
    let percent: Int?
    let resetsAt: String?

    var resetDate: Date? {
        resetsAt.flatMap(ClaudeAccountsModule.parseDate)
    }

    var currentPercent: Int? {
        if let resetDate, resetDate <= Date() {
            return 0
        }
        return percent
    }
}

struct ClaudeAccountSummary: Decodable, Identifiable {
    let account: String
    let alias: String
    let label: String
    let primary: Bool
    let active: Bool
    let configured: Bool
    let configDir: String
    let email: String?
    let fiveHour: ClaudeUsageWindow
    let sevenDay: ClaudeUsageWindow
    let usageFetchedAtMs: Double?

    var id: String { account }

    var configFilePath: String {
        primary ? NSString(string: "~/.claude.json").expandingTildeInPath : configDir + "/.claude.json"
    }

    var shortName: String {
        if !alias.isEmpty {
            return alias
        }
        if let email, let localPart = email.split(separator: "@").first {
            return String(localPart)
        }
        return "Conta \(account)"
    }
}

enum AccountBadge {
    static func image(for account: String, diameter: CGFloat = 16) -> NSImage {
        let color = NSColor(hex: AppSettings.shared.values.claude.colorHex(for: account))
        let size = NSSize(width: diameter, height: diameter)
        let image = NSImage(size: size, flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            let text = account.count > 2 ? String(account.prefix(2)) : account
            let font = NSFont.systemFont(ofSize: diameter * (text.count > 1 ? 0.5 : 0.62), weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2),
                withAttributes: attributes
            )
            return true
        }
        image.isTemplate = false
        return image
    }
}

private struct LatestSession: Decodable {
    let sessionId: String
    let cwd: String?
}

private struct StatusReport: Decodable {
    let active: String
    let accounts: [ClaudeAccountSummary]
    let latestSession: LatestSession?
}

final class ClaudeAccountsModule: NSObject, ToolbeltModule, NSMenuDelegate {
    let identifier = "claudeAccounts"
    let title = "Contas do Claude"
    let summary = "Alterna entre contas do Claude Code e mostra o uso de cada uma."
    let symbolName = "sparkle"

    private static let maximumTitleLength = 12

    private let accountsCommand = NSString(string: "~/.local/bin/cca").expandingTildeInPath
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var report: StatusReport?
    private var resetTimer: Timer?
    private var fileWatchers: [String: FileWatcher] = [:]
    private var hotKeyIdentifiers: [UInt32] = []
    private var registeredShortcuts: [String: KeyCombo] = [:]
    var onOpenSettings: (() -> Void)?

    var accounts: [ClaudeAccountSummary] { report?.accounts ?? [] }

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "toolbelt.claude"
        item.button?.imagePosition = .imageLeading
        menu.delegate = self
        item.menu = menu
        statusItem = item
        refresh()
        registerTerminalShortcuts()
    }

    func openTerminal(for account: String) {
        Terminal.run("eval \"$(cca pin \(account))\" && cd ~ && clear && claude")
    }

    private func registerTerminalShortcuts() {
        hotKeyIdentifiers.forEach(HotKeyCenter.shared.unregister)
        hotKeyIdentifiers.removeAll()
        registeredShortcuts = AppSettings.shared.values.claude.terminalShortcuts
        for (account, combo) in registeredShortcuts {
            if let identifier = HotKeyCenter.shared.register(combo, handler: { [weak self] in
                self?.openTerminal(for: account)
            }) {
                hotKeyIdentifiers.append(identifier)
            }
        }
    }

    func stop() {
        resetTimer?.invalidate()
        fileWatchers.removeAll()
        hotKeyIdentifiers.forEach(HotKeyCenter.shared.unregister)
        hotKeyIdentifiers.removeAll()
        registeredShortcuts = [:]
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    func settingsDidChange() {
        updateTitle()
        if registeredShortcuts != AppSettings.shared.values.claude.terminalShortcuts {
            registerTerminalShortcuts()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
    }

    func refresh() {
        report = loadReport()
        updateTitle()
        rebuildMenu()
        watchAccountFiles()
        scheduleResetRefresh()
    }

    private func watchAccountFiles() {
        let stateDirectory = NSString(string: "~/.config/claude-accounts").expandingTildeInPath
        var paths = Set([stateDirectory + "/active", stateDirectory + "/accounts.json"])
        for account in accounts {
            paths.insert(account.configFilePath)
        }
        for path in fileWatchers.keys where !paths.contains(path) {
            fileWatchers[path] = nil
        }
        for path in paths where fileWatchers[path] == nil {
            fileWatchers[path] = FileWatcher(path: path) { [weak self] in self?.refresh() }
        }
    }

    private func scheduleResetRefresh() {
        resetTimer?.invalidate()
        let now = Date()
        let nextReset = accounts
            .flatMap { [$0.fiveHour.resetDate, $0.sevenDay.resetDate] }
            .compactMap { $0 }
            .filter { $0 > now }
            .min()
        guard let nextReset else { return }
        resetTimer = Timer.scheduledTimer(withTimeInterval: nextReset.timeIntervalSince(now) + 2, repeats: false) { [weak self] _ in
            self?.updateTitle()
            self?.rebuildMenu()
            self?.scheduleResetRefresh()
        }
    }

    func use(_ account: String) {
        runAccountsCommand(["use", account])
        refresh()
    }

    func switchAccount() {
        guard let report, report.accounts.count > 1,
              let index = report.accounts.firstIndex(where: { $0.active }) else { return }
        use(report.accounts[(index + 1) % report.accounts.count].account)
    }

    func login(_ account: String) {
        Terminal.run("cca login \(account)")
    }

    func rename(_ account: String, alias: String) {
        runAccountsCommand(["rename", account] + (alias.isEmpty ? [] : [alias]))
        refresh()
    }

    func addAccount(alias: String) {
        runAccountsCommand(["add"] + (alias.isEmpty ? [] : [alias]))
        refresh()
    }

    func remove(_ account: String) {
        runAccountsCommand(["remove", account])
        refresh()
    }

    private func loadReport() -> StatusReport? {
        guard let output = runAccountsCommand(["status", "--json"]) else { return nil }
        return try? JSONDecoder().decode(StatusReport.self, from: output)
    }

    @discardableResult
    private func runAccountsCommand(_ arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: accountsCommand)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            NSLog("Toolbelt: cca failed to start: \(error)")
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }

    private func updateTitle() {
        guard let button = statusItem?.button else { return }
        guard let report, let active = report.accounts.first(where: { $0.active }) else {
            let image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Claude")
            image?.isTemplate = true
            button.image = image
            button.title = " ?"
            return
        }
        button.image = AccountBadge.image(for: active.account)
        let settings = AppSettings.shared.values.claude
        var parts: [String] = []
        if settings.showNameInTitle {
            parts.append(Self.shortened(active.shortName))
        }
        if settings.showUsageInTitle, let percent = active.fiveHour.currentPercent {
            parts.append("\(percent)%")
        }
        button.title = parts.isEmpty ? "" : " " + parts.joined(separator: " · ")
        button.toolTip = "Conta ativa: \(active.shortName) · \(active.email ?? "sem login")"
    }

    private static func shortened(_ text: String) -> String {
        text.count > maximumTitleLength ? String(text.prefix(maximumTitleLength - 1)) + "…" : text
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        guard let report else {
            menu.addItem(disabledMenuItem("Não consegui ler o cca (~/.local/bin/cca)"))
            return
        }

        if let active = report.accounts.first(where: { $0.active }) {
            let header = disabledMenuItem("Ativa agora: \(active.shortName)")
            header.image = AccountBadge.image(for: active.account)
            menu.addItem(header)
            menu.addItem(.separator())
        }
        menu.addItem(sectionHeader("Trocar para"))
        for account in report.accounts {
            let name = account.account
            let item = ActionMenuItem(title: "\(account.shortName) · \(account.email ?? "sem login")") { [weak self] in
                self?.use(name)
            }
            item.image = AccountBadge.image(for: account.account)
            item.state = account.active ? .on : .off
            menu.addItem(item)
            menu.addItem(disabledMenuItem("     " + usageLine(account)))
        }

        menu.addItem(.separator())
        let terminalItem = NSMenuItem(title: "Abrir terminal com", action: nil, keyEquivalent: "")
        let terminalMenu = NSMenu()
        let shortcuts = AppSettings.shared.values.claude.terminalShortcuts
        for account in report.accounts where account.email != nil {
            let name = account.account
            let shortcut = shortcuts[name].map { "\t\($0.display)" } ?? ""
            let item = ActionMenuItem(title: "\(account.shortName)\(shortcut)") { [weak self] in
                self?.openTerminal(for: name)
            }
            item.image = AccountBadge.image(for: name)
            terminalMenu.addItem(item)
        }
        terminalItem.submenu = terminalMenu
        terminalItem.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)
        menu.addItem(terminalItem)

        if let session = report.latestSession, let cwd = session.cwd {
            menu.addItem(disabledMenuItem("Última conversa: " + (cwd as NSString).abbreviatingWithTildeInPath))
            let resumeItem = NSMenuItem(title: "Retomar última conversa em", action: nil, keyEquivalent: "")
            let resumeMenu = NSMenu()
            for account in report.accounts where account.email != nil {
                let name = account.account
                resumeMenu.addItem(ActionMenuItem(title: account.label) { [weak self] in
                    self?.use(name)
                    Terminal.run("cca resume \(name)")
                })
            }
            resumeItem.submenu = resumeMenu
            menu.addItem(resumeItem)
        }

        for account in report.accounts where account.email == nil {
            let name = account.account
            menu.addItem(ActionMenuItem(title: "Entrar em \(account.label)…") { [weak self] in
                self?.login(name)
            })
        }

        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(title: "Gerenciar contas…") { [weak self] in
            self?.onOpenSettings?()
        })
    }

    private func usageLine(_ account: ClaudeAccountSummary) -> String {
        guard account.email != nil else { return "—" }
        let fiveHour = account.fiveHour.currentPercent.map { "\($0)%" } ?? "?"
        let sevenDay = account.sevenDay.currentPercent.map { "\($0)%" } ?? "?"
        var line = "5h \(fiveHour)\(resetSuffix(account.fiveHour.resetsAt)) · semana \(sevenDay)"
        if let fetchedAtMs = account.usageFetchedAtMs {
            line += " · \(Self.relativeAge(fetchedAtMs))"
        }
        return line
    }

    private func resetSuffix(_ isoDate: String?) -> String {
        guard let isoDate, let date = Self.parseDate(isoDate), date > Date() else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return " (zera \(formatter.string(from: date)))"
    }

    static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    static func relativeAge(_ milliseconds: Double) -> String {
        let minutes = Int(Date().timeIntervalSince1970 - milliseconds / 1000) / 60
        if minutes < 1 { return "agora" }
        if minutes < 60 { return "há \(minutes) min" }
        if minutes < 1440 { return "há \(minutes / 60) h" }
        return "há \(minutes / 1440) d"
    }
}

enum Terminal {
    static func run(_ command: String) {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Terminal"
            activate
            do script "\(escaped)"
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            NSLog("Toolbelt: Terminal script failed: \(error)")
        }
    }
}
