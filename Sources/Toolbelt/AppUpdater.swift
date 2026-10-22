import AppKit
import CryptoKit
import Security
import UserNotifications

struct UpdateRelease: Codable, Equatable {
    let version: String
    let build: Int
    let minimumSystemVersion: String
    let archiveURL: URL
    let archiveSHA256: String
    let downloadPageURL: URL
    let notes: [String]

    var isNewerThanRunningApp: Bool {
        let comparison = version.compare(AppUpdater.currentVersion, options: .numeric)
        return comparison == .orderedDescending || (comparison == .orderedSame && build > AppUpdater.currentBuild)
    }

    var supportsRunningSystem: Bool {
        let parts = minimumSystemVersion.split(separator: ".").compactMap { Int($0) }
        let required = OperatingSystemVersion(
            majorVersion: parts.first ?? 0,
            minorVersion: parts.count > 1 ? parts[1] : 0,
            patchVersion: parts.count > 2 ? parts[2] : 0
        )
        return ProcessInfo.processInfo.isOperatingSystemAtLeast(required)
    }
}

enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case available(UpdateRelease)
    case downloading(UpdateRelease)
    case installing(UpdateRelease)
    case failed(String)
}

private struct UpdateFailure: Error {
    let message: String
}

final class AppUpdater: NSObject, ObservableObject {
    static let relaunchArgument = "--relaunch-after"
    static let bundleIdentifier = "dev.oconde.toolbelt"
    private static let defaultFeedURL = "https://toolbelt.oconde.dev/updates/latest.json"
    private static let notificationCategory = "toolbelt.update"
    private static let installActionIdentifier = "toolbelt.update.install"
    private static let notificationIdentifier = "toolbelt.update.available"
    private static let checkInterval: TimeInterval = 24 * 60 * 60
    private static let launchDelay: TimeInterval = 60
    private static let lastCheckKey = "updates.lastCheck"
    private static let notifiedVersionKey = "updates.notifiedVersion"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var currentBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    }

    @Published private(set) var state: UpdateState = .idle {
        didSet { onChange?() }
    }
    @Published private(set) var lastCheck: Date?

    var onChange: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var checksAutomatically = AppSettings.shared.values.updates.checksAutomatically

    var availableRelease: UpdateRelease? {
        if case .available(let release) = state {
            return release
        }
        return nil
    }

    var isBusy: Bool {
        switch state {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }

    var canInstallInPlace: Bool {
        Self.teamIdentifier(of: Bundle.main.bundleURL) != nil
    }

    private var feedURL: URL? {
        let configured = Bundle.main.object(forInfoDictionaryKey: "ToolbeltUpdateFeedURL") as? String
        return URL(string: configured ?? Self.defaultFeedURL)
    }

    func start() {
        lastCheck = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
        configureNotifications()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkIfDue()
        }
        schedule(after: Self.launchDelay)
    }

    func settingsDidChange() {
        let enabled = AppSettings.shared.values.updates.checksAutomatically
        guard enabled != checksAutomatically else { return }
        checksAutomatically = enabled
        schedule(after: Self.launchDelay)
    }

    func check(userInitiated: Bool) {
        guard !isBusy, let feedURL else { return }
        let previousState = state
        state = .checking
        var request = URLRequest(url: feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("Toolbelt/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
        let session = URLSession(configuration: .ephemeral)
        session.dataTask(with: request) { [weak self] data, response, error in
            let release: Result<UpdateRelease, UpdateFailure>
            if let data, (response as? HTTPURLResponse)?.statusCode == 200,
               let decoded = try? JSONDecoder().decode(UpdateRelease.self, from: data) {
                release = .success(decoded)
            } else {
                NSLog("Toolbelt: update check failed: \(error?.localizedDescription ?? "status \((response as? HTTPURLResponse)?.statusCode ?? 0)")")
                release = .failure(UpdateFailure(message: String(localized: "Não consegui verificar agora. Confira a internet e tente de novo.")))
            }
            DispatchQueue.main.async {
                self?.finishCheck(release, userInitiated: userInitiated, previousState: previousState)
            }
        }.resume()
        session.finishTasksAndInvalidate()
    }

    func installAvailableUpdate() {
        guard let release = availableRelease else { return }
        let destination = Bundle.main.bundleURL
        guard let teamIdentifier = Self.teamIdentifier(of: destination) else {
            NSWorkspace.shared.open(release.downloadPageURL)
            return
        }
        guard FileManager.default.isWritableFile(atPath: destination.deletingLastPathComponent().path) else {
            state = .failed(String(localized: "Sem permissão para trocar o app em \(destination.deletingLastPathComponent().path). Baixe pelo site."))
            NSWorkspace.shared.open(release.downloadPageURL)
            return
        }
        state = .downloading(release)
        let session = URLSession(configuration: .ephemeral)
        session.downloadTask(with: release.archiveURL) { [weak self] location, response, error in
            let prepared: Result<URL, UpdateFailure>
            if let location, (response as? HTTPURLResponse)?.statusCode == 200 {
                prepared = Self.prepare(archive: location, for: release, replacing: destination, teamIdentifier: teamIdentifier)
            } else {
                NSLog("Toolbelt: update download failed: \(error?.localizedDescription ?? "status \((response as? HTTPURLResponse)?.statusCode ?? 0)")")
                prepared = .failure(UpdateFailure(message: String(localized: "Não consegui baixar a atualização.")))
            }
            DispatchQueue.main.async {
                self?.finishInstall(prepared, release: release, destination: destination)
            }
        }.resume()
        session.finishTasksAndInvalidate()
    }

    static func waitForExit(of processIdentifier: pid_t) {
        let deadline = Date().addingTimeInterval(10)
        while kill(processIdentifier, 0) == 0 && Date() < deadline {
            usleep(100_000)
        }
    }

    private func schedule(after delay: TimeInterval) {
        timer?.invalidate()
        timer = nil
        guard checksAutomatically else { return }
        let timer = Timer(timeInterval: max(delay, 60), repeats: false) { [weak self] _ in
            self?.checkIfDue()
        }
        timer.tolerance = 300
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func checkIfDue() {
        guard checksAutomatically else { return }
        if let lastCheck, Date().timeIntervalSince(lastCheck) < Self.checkInterval {
            schedule(after: Self.checkInterval - Date().timeIntervalSince(lastCheck))
            return
        }
        check(userInitiated: false)
    }

    private func finishCheck(_ result: Result<UpdateRelease, UpdateFailure>, userInitiated: Bool, previousState: UpdateState) {
        let now = Date()
        lastCheck = now
        UserDefaults.standard.set(now, forKey: Self.lastCheckKey)
        schedule(after: Self.checkInterval)
        switch result {
        case .failure(let failure):
            state = userInitiated ? .failed(failure.message) : previousState
        case .success(let release):
            guard release.isNewerThanRunningApp, release.supportsRunningSystem else {
                state = .upToDate
                return
            }
            state = .available(release)
            let notifiedVersion = UserDefaults.standard.string(forKey: Self.notifiedVersionKey)
            if !userInitiated && notifiedVersion != release.version && AppSettings.shared.values.updates.notifiesWithSystemNotification {
                UserDefaults.standard.set(release.version, forKey: Self.notifiedVersionKey)
                postNotification(for: release)
            }
        }
    }

    private func finishInstall(_ result: Result<URL, UpdateFailure>, release: UpdateRelease, destination: URL) {
        switch result {
        case .failure(let failure):
            state = .failed(failure.message)
            CrashReporter.shared.record("update.install_failed", attrs: ["reason": .string(failure.message), "target": .string(release.version)])
        case .success(let preparedApp):
            state = .installing(release)
            do {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: preparedApp)
            } catch {
                NSLog("Toolbelt: update replace failed: \(error.localizedDescription)")
                state = .failed(String(localized: "Não consegui trocar o app: \(error.localizedDescription)"))
                return
            }
            NSLog("Toolbelt: updated to \(release.version), relaunching")
            Self.relaunch(at: destination)
        }
    }

    static func relaunch(at url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = [Self.relaunchArgument, String(ProcessInfo.processInfo.processIdentifier)]
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                NSLog("Toolbelt: relaunch failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    private static func prepare(archive: URL, for release: UpdateRelease, replacing destination: URL, teamIdentifier: String) -> Result<URL, UpdateFailure> {
        guard let data = try? Data(contentsOf: archive) else {
            return .failure(UpdateFailure(message: String(localized: "Não consegui ler o arquivo baixado.")))
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest == release.archiveSHA256.lowercased() else {
            NSLog("Toolbelt: update checksum mismatch \(digest)")
            return .failure(UpdateFailure(message: String(localized: "O arquivo baixado não confere. Nada foi alterado.")))
        }
        let workDirectory: URL
        do {
            workDirectory = try FileManager.default.url(
                for: .itemReplacementDirectory,
                in: .userDomainMask,
                appropriateFor: destination,
                create: true
            )
        } catch {
            return .failure(UpdateFailure(message: String(localized: "Não consegui preparar a pasta temporária.")))
        }
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-x", "-k", archive.path, workDirectory.path]
        do {
            try unzip.run()
            unzip.waitUntilExit()
        } catch {
            return .failure(UpdateFailure(message: String(localized: "Não consegui abrir o arquivo da atualização.")))
        }
        let preparedApp = workDirectory.appendingPathComponent(destination.lastPathComponent)
        guard unzip.terminationStatus == 0, FileManager.default.fileExists(atPath: preparedApp.path) else {
            return .failure(UpdateFailure(message: String(localized: "O arquivo da atualização veio incompleto.")))
        }
        guard isTrusted(preparedApp, teamIdentifier: teamIdentifier) else {
            NSLog("Toolbelt: update signature rejected")
            return .failure(UpdateFailure(message: String(localized: "A assinatura da atualização não é do mesmo desenvolvedor. Nada foi alterado.")))
        }
        let preparedVersion = Bundle(url: preparedApp)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard preparedVersion == release.version else {
            return .failure(UpdateFailure(message: String(localized: "A versão baixada não é a anunciada. Nada foi alterado.")))
        }
        return .success(preparedApp)
    }

    private static func teamIdentifier(of url: URL) -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let dictionary = information as? [String: Any] else { return nil }
        return dictionary[kSecCodeInfoTeamIdentifier as String] as? String
    }

    private static func isTrusted(_ url: URL, teamIdentifier: String) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else { return false }
        let requirementText = "anchor apple generic and identifier \"\(bundleIdentifier)\" and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(requirementText as CFString, [], &requirement) == errSecSuccess else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        return SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess
    }

    private func configureNotifications() {
        let install = UNNotificationAction(identifier: Self.installActionIdentifier, title: String(localized: "Atualizar agora"), options: [])
        let category = UNNotificationCategory(identifier: Self.notificationCategory, actions: [install], intentIdentifiers: [], options: [])
        NotificationRouter.shared.register(category) { [weak self] action in
            if action == Self.installActionIdentifier {
                self?.installAvailableUpdate()
            } else if action == UNNotificationDefaultActionIdentifier {
                self?.onOpenSettings?()
            }
        }
    }

    private func postNotification(for release: UpdateRelease) {
        let body = release.notes.first.map { String(localized: "\($0) Você está na \(Self.currentVersion).") } ?? String(localized: "Você está na \(Self.currentVersion). Atualize com um clique.")
        NotificationRouter.shared.post(
            identifier: Self.notificationIdentifier,
            title: String(localized: "Toolbelt \(release.version) disponível"),
            body: body,
            category: Self.notificationCategory
        )
    }
}
