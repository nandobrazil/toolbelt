import AppKit

private struct UsageWindow: Decodable {
    let percent: Int?
    let resetsAt: String?
}

private struct AccountSummary: Decodable {
    let account: String
    let active: Bool
    let configured: Bool
    let email: String?
    let fiveHour: UsageWindow
    let sevenDay: UsageWindow
    let usageFetchedAtMs: Double?
}

private struct LatestSession: Decodable {
    let sessionId: String
    let cwd: String?
}

private struct StatusReport: Decodable {
    let active: String
    let accounts: [AccountSummary]
    let latestSession: LatestSession?
}

final class ClaudeAccountsModule: NSObject, ToolbeltModule, NSMenuDelegate {
    let identifier = "claudeAccounts"
    let title = "Contas do Claude"

    private let accountsCommand = NSString(string: "~/.local/bin/cca").expandingTildeInPath
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var report: StatusReport?
    private var refreshTimer: Timer?

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "toolbelt.claude"
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

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
    }

    private func refresh() {
        report = loadReport()
        updateTitle()
        rebuildMenu()
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
        guard let report, let active = report.accounts.first(where: { $0.active }) else {
            statusItem?.button?.title = "✳︎ ?"
            return
        }
        let usage = active.fiveHour.percent.map { " \($0)%" } ?? ""
        statusItem?.button?.title = "✳︎ \(active.account.uppercased())\(usage)"
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        guard let report else {
            menu.addItem(disabledMenuItem("Não consegui ler o cca (~/.local/bin/cca)"))
            return
        }

        for account in report.accounts {
            let name = account.account
            let item = ActionMenuItem(title: accountTitle(account)) { [weak self] in
                self?.runAccountsCommand(["use", name])
                self?.refresh()
            }
            item.state = account.active ? .on : .off
            menu.addItem(item)
            menu.addItem(disabledMenuItem("     " + usageLine(account)))
        }

        menu.addItem(.separator())
        if let session = report.latestSession, let cwd = session.cwd {
            menu.addItem(disabledMenuItem("Última conversa: " + (cwd as NSString).abbreviatingWithTildeInPath))
        }
        for account in report.accounts {
            let name = account.account
            let item = ActionMenuItem(title: "Retomar última conversa na conta \(name.uppercased())") { [weak self] in
                self?.runAccountsCommand(["use", name])
                Terminal.run("cca resume \(name)")
                self?.refresh()
            }
            item.isEnabled = account.email != nil && report.latestSession != nil
            menu.addItem(item)
        }

        let missingLogins = report.accounts.filter { $0.email == nil }
        if !missingLogins.isEmpty {
            menu.addItem(.separator())
            for account in missingLogins {
                let name = account.account
                menu.addItem(ActionMenuItem(title: "Entrar na conta \(name.uppercased())…") {
                    Terminal.run("cca setup >/dev/null && cca login \(name)")
                })
            }
        }
    }

    private func accountTitle(_ account: AccountSummary) -> String {
        let label = account.email ?? (account.configured ? "sem login" : "não configurada")
        return "Conta \(account.account.uppercased()) · \(label)"
    }

    private func usageLine(_ account: AccountSummary) -> String {
        guard account.email != nil else { return "—" }
        let fiveHour = account.fiveHour.percent.map { "\($0)%" } ?? "?"
        let sevenDay = account.sevenDay.percent.map { "\($0)%" } ?? "?"
        var line = "5h \(fiveHour)\(resetSuffix(account.fiveHour.resetsAt)) · semana \(sevenDay)"
        if let fetchedAtMs = account.usageFetchedAtMs {
            line += " · \(relativeAge(fetchedAtMs))"
        }
        return line
    }

    private func resetSuffix(_ isoDate: String?) -> String {
        guard let isoDate, let date = parseDate(isoDate), date > Date() else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return " (zera \(formatter.string(from: date)))"
    }

    private func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private func relativeAge(_ milliseconds: Double) -> String {
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
