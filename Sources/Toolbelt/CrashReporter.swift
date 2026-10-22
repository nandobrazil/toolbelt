import AppKit
import MetricKit
import UserNotifications

struct PendingCrash: Identifiable {
    enum Kind {
        case crash
        case hang
    }

    let id: String
    let kind: Kind
    let title: String
    let occurredAt: Date
    let event: RadarEvent
    let release: String
}

final class CrashReporter: NSObject, ObservableObject {
    static let shared = CrashReporter()

    private static let baselineKey = "crashReports.baseline"
    private static let seenKey = "crashReports.seen"
    private static let notificationCategory = "toolbelt.crash"
    private static let notificationIdentifier = "toolbelt.crash.pending"
    private static let sendActionIdentifier = "toolbelt.crash.send"
    private static let alwaysActionIdentifier = "toolbelt.crash.always"
    private static let scanDelay: TimeInterval = 8
    private static let logFlushDelay: TimeInterval = 30
    private static let maximumSeen = 200
    private static let maximumQueuedLogs = 50
    private static let maximumFrames = 60
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SS Z"
        return formatter
    }()

    @Published private(set) var pending: [PendingCrash] = []
    var onChange: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    private var queuedLogs: [RadarEvent] = []
    private var isLogFlushScheduled = false
    private var currentMode = AppSettings.shared.values.reports.crashReportMode

    private var mode: CrashReportMode { AppSettings.shared.values.reports.crashReportMode }

    func start() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.baselineKey) == nil {
            defaults.set(Date(), forKey: Self.baselineKey)
        }
        registerNotificationCategory()
        MXMetricManager.shared.add(self)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + Self.scanDelay) { [weak self] in
            let found = Self.scanDiagnosticReports()
            DispatchQueue.main.async {
                self?.receive(found)
                RadarClient.flushOutbox()
            }
        }
    }

    func settingsDidChange() {
        guard mode != currentMode else { return }
        currentMode = mode
        switch mode {
        case .always: sendPending(rememberChoice: false)
        case .never: dismissPending()
        case .ask: break
        }
    }

    func sendPending(rememberChoice: Bool) {
        if rememberChoice {
            AppSettings.shared.values.reports.crashReportMode = .always
        }
        let crashes = pending
        pending.removeAll()
        onChange?()
        send(crashes)
    }

    func dismissPending() {
        markSeen(pending)
        pending.removeAll()
        onChange?()
    }

    func record(_ message: String, attrs: [String: JSONValue] = [:]) {
        guard mode == .always, RadarClient.isConfigured else { return }
        queuedLogs.append(.log(message, level: "warn", attrs: attrs))
        if queuedLogs.count > Self.maximumQueuedLogs {
            queuedLogs.removeFirst(queuedLogs.count - Self.maximumQueuedLogs)
        }
        guard !isLogFlushScheduled else { return }
        isLogFlushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.logFlushDelay) { [weak self] in
            guard let self else { return }
            self.isLogFlushScheduled = false
            let logs = self.queuedLogs
            self.queuedLogs.removeAll()
            RadarClient.send(logs)
        }
    }

    private func receive(_ crashes: [PendingCrash]) {
        let fresh = crashes.filter { crash in !pending.contains { $0.id == crash.id } }
        guard !fresh.isEmpty else { return }
        NSLog("Toolbelt: found \(fresh.count) unreported crash or hang report(s)")
        switch mode {
        case .never:
            markSeen(fresh)
        case .always:
            send(fresh)
        case .ask:
            pending.append(contentsOf: fresh)
            onChange?()
            notify(about: fresh)
        }
    }

    private func send(_ crashes: [PendingCrash]) {
        guard !crashes.isEmpty else { return }
        markSeen(crashes)
        guard RadarClient.isConfigured else {
            NSLog("Toolbelt: crash reports not sent, this build has no Radar key")
            return
        }
        for (release, group) in Dictionary(grouping: crashes, by: \.release) {
            RadarClient.send(group.map(\.event), release: release)
        }
    }

    private func markSeen(_ crashes: [PendingCrash]) {
        let defaults = UserDefaults.standard
        let seen = (defaults.stringArray(forKey: Self.seenKey) ?? []) + crashes.map(\.id)
        defaults.set(Array(seen.suffix(Self.maximumSeen)), forKey: Self.seenKey)
    }

    private func registerNotificationCategory() {
        let send = UNNotificationAction(identifier: Self.sendActionIdentifier, title: "Enviar", options: [])
        let always = UNNotificationAction(identifier: Self.alwaysActionIdentifier, title: "Sempre enviar", options: [])
        let category = UNNotificationCategory(identifier: Self.notificationCategory, actions: [send, always], intentIdentifiers: [], options: [])
        NotificationRouter.shared.register(category) { [weak self] action in
            switch action {
            case Self.sendActionIdentifier: self?.sendPending(rememberChoice: false)
            case Self.alwaysActionIdentifier: self?.sendPending(rememberChoice: true)
            case UNNotificationDefaultActionIdentifier: self?.onOpenSettings?()
            default: break
            }
        }
    }

    private func notify(about crashes: [PendingCrash]) {
        let onlyHangs = crashes.allSatisfy { $0.kind == .hang }
        NotificationRouter.shared.post(
            identifier: Self.notificationIdentifier,
            title: onlyHangs ? "O Toolbelt travou" : "O Toolbelt fechou inesperadamente",
            body: "Enviar o relatório ajuda a corrigir. Vai só o técnico: versão, macOS e onde falhou.",
            category: Self.notificationCategory
        )
    }

    private static func scanDiagnosticReports() -> [PendingCrash] {
        let defaults = UserDefaults.standard
        let baseline = defaults.object(forKey: baselineKey) as? Date ?? Date()
        let seen = Set(defaults.stringArray(forKey: seenKey) ?? [])
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports")
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files
            .filter { $0.lastPathComponent.hasPrefix("Toolbelt") && $0.pathExtension == "ips" }
            .filter { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast) > baseline }
            .compactMap(parseCrashReport)
            .filter { !seen.contains($0.id) }
            .sorted { $0.occurredAt < $1.occurredAt }
    }

    static func parseCrashReport(_ url: URL) -> PendingCrash? {
        guard let data = try? Data(contentsOf: url),
              let newline = data.firstIndex(of: 0x0A),
              let header = try? JSONSerialization.jsonObject(with: data[..<newline]) as? [String: Any],
              let body = try? JSONSerialization.jsonObject(with: data[data.index(after: newline)...]) as? [String: Any],
              header["bundleID"] as? String == AppUpdater.bundleIdentifier,
              header["bug_type"] as? String == "309" else { return nil }

        let identifier = header["incident_id"] as? String ?? body["incident"] as? String ?? url.lastPathComponent
        let exception = body["exception"] as? [String: Any] ?? [:]
        let type = [exception["type"] as? String, (exception["signal"] as? String).map { "(\($0))" }]
            .compactMap { $0 }
            .joined(separator: " ")
        let specificMessages = (body["asi"] as? [String: [String]])?.values.flatMap { $0 } ?? []
        let termination = (body["termination"] as? [String: Any])?["indicator"] as? String
        let message = specificMessages.first ?? exception["subtype"] as? String ?? termination ?? "O Toolbelt fechou inesperadamente"

        let images = body["usedImages"] as? [[String: Any]] ?? []
        let threads = body["threads"] as? [[String: Any]] ?? []
        let faultingIndex = body["faultingThread"] as? Int ?? threads.firstIndex { $0["triggered"] as? Bool == true } ?? 0
        let rawFrames = threads.indices.contains(faultingIndex) ? threads[faultingIndex]["frames"] as? [[String: Any]] ?? [] : []
        let frames = rawFrames.prefix(maximumFrames).map { frame -> RadarFrame in
            let imageIndex = frame["imageIndex"] as? Int ?? -1
            let image = images.indices.contains(imageIndex) ? images[imageIndex]["name"] as? String ?? "?" : "?"
            let offset = frame["imageOffset"] as? Int ?? 0
            return RadarFrame(
                fn: frame["symbol"] as? String ?? "\(image) + \(offset)",
                file: Diagnostics.sanitize(frame["sourceFile"] as? String ?? image),
                line: frame["sourceLine"] as? Int,
                inApp: image == "Toolbelt"
            )
        }

        let osVersion = body["osVersion"] as? [String: Any] ?? [:]
        let osTrain = osVersion["train"] as? String ?? ""
        let appVersion = header["app_version"] as? String ?? AppUpdater.currentVersion
        let appBuild = header["build_version"] as? String ?? "?"
        let occurredAt = (header["timestamp"] as? String).flatMap(timestampFormatter.date) ?? Date()
        let runtime = RadarRuntime(
            version: osTrain.components(separatedBy: " ").last ?? Diagnostics.macOSVersion,
            host: body["modelCode"] as? String,
            pid: body["pid"] as? Int
        )
        let attrs: [String: JSONValue] = [
            "kind": .string("crash"),
            "incident": .string(identifier),
            "appVersion": .string(appVersion),
            "appBuild": .string(appBuild),
            "osBuild": .string(osVersion["build"] as? String ?? "?"),
            "translated": .bool(body["translated"] as? Bool ?? false)
        ]
        let event = RadarEvent.error(
            RadarException(type: type.isEmpty ? "Crash" : type, message: Diagnostics.sanitize(message), frames: Array(frames)),
            runtime: runtime,
            attrs: attrs,
            at: occurredAt,
            level: "fatal"
        )
        return PendingCrash(id: identifier, kind: .crash, title: type, occurredAt: occurredAt, event: event, release: "\(appVersion)+\(appBuild)")
    }

    private static func pendingHang(_ diagnostic: MXHangDiagnostic, endedAt: Date) -> PendingCrash? {
        let seconds = diagnostic.hangDuration.converted(to: .seconds).value
        let tree = (try? JSONSerialization.jsonObject(with: diagnostic.callStackTree.jsonRepresentation())) as? [String: Any] ?? [:]
        let stacks = tree["callStacks"] as? [[String: Any]] ?? []
        let stack = stacks.first { $0["threadAttributed"] as? Bool == true } ?? stacks.first ?? [:]
        var frames: [RadarFrame] = []
        var level = stack["callStackRootFrames"] as? [[String: Any]] ?? []
        while let frame = level.first, frames.count < maximumFrames {
            let binary = frame["binaryName"] as? String ?? "?"
            let offset = frame["offsetIntoBinaryTextSegment"] as? Int ?? 0
            frames.append(RadarFrame(fn: "\(binary) + \(offset)", file: binary, inApp: binary == "Toolbelt"))
            level = frame["subFrames"] as? [[String: Any]] ?? []
        }
        let metadata = diagnostic.metaData
        let identifier = "hang-\(Int(endedAt.timeIntervalSince1970))-\(Int(seconds * 1000))"
        let event = RadarEvent.error(
            RadarException(type: "Hang", message: String(format: "A interface ficou travada por %.1f s", seconds), frames: frames),
            runtime: RadarRuntime(version: Diagnostics.macOSVersion, host: Diagnostics.modelIdentifier),
            attrs: [
                "kind": .string("hang"),
                "durationMs": .integer(Int(seconds * 1000)),
                "appBuild": .string(metadata.applicationBuildVersion),
                "architecture": .string(metadata.platformArchitecture)
            ],
            at: endedAt,
            level: "error"
        )
        return PendingCrash(id: identifier, kind: .hang, title: "Travamento de \(Int(seconds.rounded())) s", occurredAt: endedAt, event: event, release: "\(AppUpdater.currentVersion)+\(metadata.applicationBuildVersion)")
    }
}

extension CrashReporter: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let hangs = payloads.flatMap { payload in
            (payload.hangDiagnostics ?? []).compactMap { Self.pendingHang($0, endedAt: payload.timeStampEnd) }
        }
        guard !hangs.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            self?.receive(hangs)
        }
    }
}
