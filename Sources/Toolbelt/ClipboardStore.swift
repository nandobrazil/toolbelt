import AppKit
import CryptoKit

struct ClipboardEntry: Codable, Equatable {
    enum Kind: String, Codable {
        case text
        case image
    }

    let id: UUID
    let kind: Kind
    let text: String?
    let imageFileName: String?
    let imageHash: String?
    let createdAt: Date

    static func text(_ value: String) -> ClipboardEntry {
        ClipboardEntry(id: UUID(), kind: .text, text: value, imageFileName: nil, imageHash: nil, createdAt: Date())
    }
}

final class ClipboardStore {

    private let directory: URL

    init(directory: URL = AppPaths.support) {
        self.directory = directory
    }
    private lazy var imagesDirectory: URL = {
        let url = directory.appendingPathComponent("clipboard-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    private lazy var indexURL = directory.appendingPathComponent("clipboard-history-v2.json")
    private var thumbnailCache: [UUID: NSImage] = [:]
    private(set) var entries: [ClipboardEntry] = []
    var onChange: (() -> Void)?

    func load() {
        if let data = try? Data(contentsOf: indexURL),
           let stored = try? JSONDecoder().decode([ClipboardEntry].self, from: data) {
            entries = stored.filter { $0.kind == .text || imageURL(for: $0).map(fileExists) == true }
        } else {
            migrateLegacyTextHistory()
        }
    }

    func addText(_ text: String) {
        entries.removeAll { $0.kind == .text && $0.text == text }
        insert(.text(text))
    }

    func addImage(pngData: Data) {
        let hash = SHA256.hash(data: pngData).map { String(format: "%02x", $0) }.joined()
        if let existingIndex = entries.firstIndex(where: { $0.imageHash == hash }) {
            let existing = entries.remove(at: existingIndex)
            entries.insert(existing, at: 0)
            save()
            return
        }
        let fileName = "\(hash.prefix(24)).png"
        do {
            let fileURL = imagesDirectory.appendingPathComponent(fileName)
            try pngData.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            NSLog("Toolbelt: failed to store clipboard image: \(error)")
            return
        }
        insert(ClipboardEntry(id: UUID(), kind: .image, text: nil, imageFileName: fileName, imageHash: hash, createdAt: Date()))
    }

    func promote(_ entry: ClipboardEntry) {
        guard let index = entries.firstIndex(of: entry) else { return }
        entries.insert(entries.remove(at: index), at: 0)
        save()
    }

    func clear() {
        entries.forEach(deleteImageFile)
        entries.removeAll()
        thumbnailCache.removeAll()
        save()
    }

    func imageURL(for entry: ClipboardEntry) -> URL? {
        entry.imageFileName.map { imagesDirectory.appendingPathComponent($0) }
    }

    func thumbnail(for entry: ClipboardEntry) -> NSImage? {
        if let cached = thumbnailCache[entry.id] {
            return cached
        }
        guard let url = imageURL(for: entry), let image = NSImage(contentsOf: url) else { return nil }
        thumbnailCache[entry.id] = image
        return image
    }

    func applyLimits() {
        let limits = AppSettings.shared.values.clipboard
        var changed = false
        while entries.count > max(limits.historyLimit, 1) {
            let removed = entries.removeLast()
            deleteImageFile(removed)
            thumbnailCache[removed.id] = nil
            changed = true
        }
        let imageEntries = entries.filter { $0.kind == .image }
        for removed in imageEntries.dropFirst(max(limits.imageLimit, 0)) {
            entries.removeAll { $0.id == removed.id }
            deleteImageFile(removed)
            thumbnailCache[removed.id] = nil
            changed = true
        }
        if changed {
            save()
        }
    }

    var imageBytes: Int {
        entries.compactMap(imageURL).reduce(0) { total, url in
            total + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    private func insert(_ entry: ClipboardEntry) {
        entries.insert(entry, at: 0)
        applyLimits()
        save()
    }


    private func deleteImageFile(_ entry: ClipboardEntry) {
        guard let url = imageURL(for: entry) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private func migrateLegacyTextHistory() {
        let legacyURL = directory.appendingPathComponent("clipboard-history.json")
        guard let data = try? Data(contentsOf: legacyURL),
              let texts = try? JSONDecoder().decode([String].self, from: data) else { return }
        entries = texts.prefix(AppSettings.shared.values.clipboard.historyLimit).map(ClipboardEntry.text)
        save()
        try? FileManager.default.removeItem(at: legacyURL)
    }

    private func save() {
        onChange?()
        guard let data = try? JSONEncoder().encode(entries) else { return }
        do {
            try data.write(to: indexURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: indexURL.path)
        } catch {
            NSLog("Toolbelt: failed to save clipboard history: \(error)")
        }
    }
}
