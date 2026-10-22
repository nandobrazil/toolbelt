import AppKit

final class ScreenshotWatcher {
    private static let screenshotAttribute = "com.apple.metadata:kMDItemIsScreenCapture"
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff"]
    private static let rescanDelay: TimeInterval = 0.4

    private var source: DispatchSourceFileSystemObject?
    private var knownNames: Set<String> = []
    private var directory: URL?
    private var pendingRescan: DispatchWorkItem?
    var onScreenshot: ((URL) -> Void)?

    func start() {
        let directory = Self.screenshotDirectory()
        self.directory = directory
        knownNames = Set(fileNames(in: directory))
        let descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else {
            NSLog("Toolbelt: cannot watch screenshot folder \(directory.path)")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in self?.scheduleRescan() }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
        NSLog("Toolbelt: watching screenshots in \(directory.path)")
    }

    func stop() {
        source?.cancel()
        source = nil
        pendingRescan?.cancel()
        knownNames.removeAll()
    }

    private func scheduleRescan() {
        pendingRescan?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.rescan() }
        pendingRescan = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.rescanDelay, execute: work)
    }

    private func rescan() {
        guard let directory else { return }
        let names = fileNames(in: directory)
        let newNames = names.filter { !knownNames.contains($0) }
        knownNames = Set(names)
        for name in newNames {
            let url = directory.appendingPathComponent(name)
            if Self.isScreenshot(url) {
                onScreenshot?(url)
            }
        }
    }

    private func fileNames(in directory: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path))?.filter { !$0.hasPrefix(".") } ?? []
    }

    private static func isScreenshot(_ url: URL) -> Bool {
        guard imageExtensions.contains(url.pathExtension.lowercased()) else { return false }
        return getxattr(url.path, screenshotAttribute, nil, 0, 0, 0) >= 0
    }

    private static func screenshotDirectory() -> URL {
        let configured = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
        if let configured, !configured.isEmpty {
            return URL(fileURLWithPath: NSString(string: configured).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    }
}
