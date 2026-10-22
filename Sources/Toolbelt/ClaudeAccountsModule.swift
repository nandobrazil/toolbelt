import AppKit

struct ClaudeUsageWindow: Decodable {
    let percent: Int?
    let resetsAt: String?
}

struct ClaudeAccountSummary: Decodable, Identifiable {
    let account: String
    let alias: String
    let label: String
    let primary: Bool
    let active: Bool
    let configured: Bool
    let email: String?
    let fiveHour: ClaudeUsageWindow
    let sevenDay: ClaudeUsageWindow
    let usageFetchedAtMs: Double?

    var id: String { account }
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
    private var refreshTimer: Timer?
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
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    func settingsDidChange() {
        updateTitle()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
    }

    func refresh() {
        report = loadReport()
        updateTitle()
        rebuildMenu()
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
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Claude")?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        button.image = image

        guard let report, let active = report.accounts.first(where: { $0.active }) else {
            button.title = " ?"
            return
        }
        let settings = AppSettings.shared.values.claude
        var parts: [String] = []
        if settings.showNameInTitle {
            parts.append(Self.shortened(active.alias.isEmpty ? active.account : active.alias))
        }
        if settings.showUsageInTitle, let percent = active.fiveHour.percent {
            parts.append("\(percent)%")
        }
        button.title = parts.isEmpty ? "" : " " + parts.joined(separator: " · ")
        button.toolTip = "\(active.label) · \(active.email ?? "sem login")"
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

        menu.addItem(sectionHeader("Contas do Claude"))
        for account in report.accounts {
            let name = account.account
            let item = ActionMenuItem(title: "\(account.label) · \(account.email ?? "sem login")") { [weak self] in
                self?.use(name)
            }
            item.state = account.active ? .on : .off
            menu.addItem(item)
            menu.addItem(disabledMenuItem("     " + usageLine(account)))
        }

        menu.addItem(.separator())
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
        let fiveHour = account.fiveHour.percent.map { "\($0)%" } ?? "?"
        let sevenDay = account.sevenDay.percent.map { "\($0)%" } ?? "?"
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
