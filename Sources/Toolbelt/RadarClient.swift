import Foundation

enum JSONValue: Encodable, Equatable {
    case string(String)
    case number(Double)
    case integer(Int)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        }
    }
}

struct RadarFrame: Encodable {
    var fn: String?
    var file: String
    var line: Int?
    var inApp: Bool
}

struct RadarException: Encodable {
    var type: String
    var message: String
    var frames: [RadarFrame]
}

struct RadarRuntime: Encodable {
    var name = "macos"
    var version: String
    var host: String?
    var pid: Int?
    var memoryMb: Int?
    var uptimeS: Int?
}

struct RadarUser: Encodable {
    var email: String?
}

struct RadarEvent: Encodable {
    var type: String
    var ts: Int64
    var level: String
    var message: String?
    var handled: Bool?
    var exception: RadarException?
    var runtime: RadarRuntime?
    var attrs: [String: JSONValue]?
    var user: RadarUser?

    static func log(_ message: String, level: String, attrs: [String: JSONValue], user: RadarUser? = nil, at date: Date = Date()) -> RadarEvent {
        RadarEvent(type: "log", ts: Int64(date.timeIntervalSince1970 * 1000), level: level, message: message, attrs: attrs, user: user)
    }

    static func error(_ exception: RadarException, runtime: RadarRuntime, attrs: [String: JSONValue], at date: Date, level: String) -> RadarEvent {
        RadarEvent(type: "error", ts: Int64(date.timeIntervalSince1970 * 1000), level: level, handled: false, exception: exception, runtime: runtime, attrs: attrs)
    }
}

private struct RadarBatch: Encodable {
    let v = 1
    let sdk: [String: String]
    let environment: String
    let release: String
    let events: [RadarEvent]
}

enum RadarClient {
    private static let sdkName = "toolbelt-radar"
    private static let defaultEndpoint = "https://radar-ingest.oconde.dev/api/v1/events"
    private static let maximumOutboxFiles = 50
    private static let outboxQueue = DispatchQueue(label: "dev.oconde.toolbelt.radar-outbox")

    static var isConfigured: Bool { key != nil }

    static var environment: String {
        Bundle.main.object(forInfoDictionaryKey: "RadarEnvironment") as? String ?? "development"
    }

    private static var key: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "RadarKey") as? String, value.hasPrefix("rk_") else { return nil }
        return value
    }

    private static var endpoint: URL? {
        URL(string: Bundle.main.object(forInfoDictionaryKey: "RadarIngestURL") as? String ?? defaultEndpoint)
    }

    private static var outbox: URL {
        let directory = AppPaths.support.appendingPathComponent("outbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func encodedBatch(_ events: [RadarEvent], release: String? = nil) -> Data? {
        let batch = RadarBatch(
            sdk: ["name": sdkName, "version": AppUpdater.currentVersion],
            environment: environment,
            release: release ?? "\(AppUpdater.currentVersion)+\(AppUpdater.currentBuild)",
            events: events
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(batch)
    }

    static func send(_ events: [RadarEvent], release: String? = nil, completion: @escaping (Bool) -> Void = { _ in }) {
        guard !events.isEmpty, let body = encodedBatch(events, release: release) else {
            completion(false)
            return
        }
        deliver(body) { outcome in
            if outcome == .retry {
                store(body)
            }
            if outcome == .delivered {
                flushOutbox()
            }
            completion(outcome == .delivered)
        }
    }

    static func flushOutbox() {
        outboxQueue.async {
            let files = ((try? FileManager.default.contentsOfDirectory(at: outbox, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            guard let file = files.first, let body = try? Data(contentsOf: file) else { return }
            deliver(body) { outcome in
                guard outcome != .retry else { return }
                outboxQueue.async {
                    try? FileManager.default.removeItem(at: file)
                    if files.count > 1 {
                        flushOutbox()
                    }
                }
            }
        }
    }

    private enum Outcome {
        case delivered
        case rejected
        case retry
    }

    private static func deliver(_ body: Data, completion: @escaping (Outcome) -> Void) {
        guard let key, let endpoint else {
            completion(.rejected)
            return
        }
        var request = URLRequest(url: endpoint, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("Toolbelt/\(AppUpdater.currentVersion)", forHTTPHeaderField: "User-Agent")
        let session = URLSession(configuration: .ephemeral)
        session.dataTask(with: request) { _, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let outcome: Outcome
            switch status {
            case 200..<300: outcome = .delivered
            case 400, 401, 403, 413, 422: outcome = .rejected
            default: outcome = .retry
            }
            if outcome != .delivered {
                NSLog("Toolbelt: radar delivery status \(status) \(error?.localizedDescription ?? "")")
            }
            DispatchQueue.main.async { completion(outcome) }
        }.resume()
        session.finishTasksAndInvalidate()
    }

    private static func store(_ body: Data) {
        outboxQueue.async {
            let name = "\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(8)).json"
            try? body.write(to: outbox.appendingPathComponent(name), options: .atomic)
            let files = ((try? FileManager.default.contentsOfDirectory(at: outbox, includingPropertiesForKeys: nil)) ?? [])
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            for file in files.dropLast(maximumOutboxFiles) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
