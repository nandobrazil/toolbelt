import AppKit

final class ClipboardArchive {
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    private let imageNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    private var settings: ClipboardSettings { AppSettings.shared.values.clipboard }

    func appendText(_ text: String, sourceApplication: String?) {
        guard settings.isArchiveEnabled else { return }
        let fence = Self.fence(for: text)
        append("\(header(sourceApplication))\n\n\(fence)\n\(text)\n\(fence)\n\n")
    }

    func appendImage(pngData: Data, sourceApplication: String?) {
        guard settings.isArchiveEnabled, settings.archiveIncludesImages else { return }
        let folder = URL(fileURLWithPath: settings.archiveFolderPath, isDirectory: true)
        let imagesFolder = folder.appendingPathComponent("images", isDirectory: true)
        let fileName = "\(imageNameFormatter.string(from: Date()))-\(UUID().uuidString.prefix(4)).png"
        do {
            try FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true)
            let imageURL = imagesFolder.appendingPathComponent(fileName)
            try pngData.write(to: imageURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: imageURL.path)
        } catch {
            NSLog("Toolbelt: failed to archive clipboard image: \(error)")
            return
        }
        append("\(header(sourceApplication))\n\n![imagem](images/\(fileName))\n\n")
    }

    private func header(_ sourceApplication: String?) -> String {
        let time = timeFormatter.string(from: Date())
        guard let sourceApplication, !sourceApplication.isEmpty else { return "## \(time)" }
        return "## \(time) · \(sourceApplication)"
    }

    private func append(_ entry: String) {
        let folder = URL(fileURLWithPath: settings.archiveFolderPath, isDirectory: true)
        let fileURL = folder.appendingPathComponent("\(dayFormatter.string(from: Date())).md")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                let title = "# Área de transferência — \(dayFormatter.string(from: Date()))\n\n"
                try Data(title.utf8).write(to: fileURL)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(entry.utf8))
        } catch {
            NSLog("Toolbelt: failed to archive clipboard text: \(error)")
        }
    }

    private static func fence(for text: String) -> String {
        var longestRun = 0
        var currentRun = 0
        for character in text {
            currentRun = character == "`" ? currentRun + 1 : 0
            longestRun = max(longestRun, currentRun)
        }
        return String(repeating: "`", count: max(3, longestRun + 1))
    }
}
