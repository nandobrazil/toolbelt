import AppKit

enum Diagnostics {
    private static let logLineCount = 40

    static var macOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    static var modelIdentifier: String {
        sysctlString("hw.model") ?? "Mac"
    }

    static var architecture: String {
        var info = utsname()
        uname(&info)
        let machine = withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
        return machine
    }

    static func runtime() -> RadarRuntime {
        RadarRuntime(
            version: macOSVersion,
            host: modelIdentifier,
            pid: Int(ProcessInfo.processInfo.processIdentifier),
            memoryMb: footprintMegabytes(),
            uptimeS: Int(Date().timeIntervalSince(launchDate))
        )
    }

    static func summary(enabledModules: [String]) -> [String: JSONValue] {
        let screens = NSScreen.screens
        return [
            "app": .object([
                "version": .string(AppUpdater.currentVersion),
                "build": .integer(AppUpdater.currentBuild),
                "environment": .string(RadarClient.environment)
            ]),
            "system": .object([
                "macOS": .string(ProcessInfo.processInfo.operatingSystemVersionString),
                "model": .string(modelIdentifier),
                "architecture": .string(architecture),
                "memoryGB": .integer(Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)),
                "language": .string(Locale.preferredLanguages.first ?? "?"),
                "displays": .integer(screens.count),
                "notch": .bool(screens.contains { $0.auxiliaryTopRightArea != nil })
            ]),
            "toolbelt": .object([
                "modules": .array(enabledModules.map(JSONValue.string)),
                "accessibility": .bool(AccessibilityPermission.isTrusted),
                "screenRecording": .bool(CGPreflightScreenCaptureAccess()),
                "memoryMB": .integer(footprintMegabytes() ?? 0)
            ]),
            "log": .array(recentLogLines().map(JSONValue.string))
        ]
    }

    static func recentLogLines() -> [String] {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Toolbelt.log")
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > 16_384 ? size - 16_384 : 0)
        let text = String(decoding: handle.readDataToEndOfFile(), as: UTF8.self)
        return text.split(separator: "\n").suffix(logLineCount).map { sanitize(String($0)) }
    }

    static func sanitize(_ text: String) -> String {
        var result = text.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
        let patterns = [
            (#"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, "<e-mail>"),
            (#"(rk|rpat|sk|ghp|gho)_[A-Za-z0-9]{12,}"#, "<chave>"),
            (#"eyJ[A-Za-z0-9_-]{20,}"#, "<token>")
        ]
        for (pattern, replacement) in patterns {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return result
    }

    static func footprintMegabytes() -> Int? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }
        return Int(info.phys_footprint / 1_048_576)
    }

    static let launchDate = Date()

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }
}
