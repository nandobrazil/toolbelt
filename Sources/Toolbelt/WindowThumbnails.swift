import AppKit
import ScreenCaptureKit

enum ScreenRecordingPermission {
    static var isGranted: Bool { CGPreflightScreenCaptureAccess() }

    static func request() {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

enum WindowThumbnails {
    static func capture(
        windowIDs: [CGWindowID],
        maximumSize: CGSize,
        scale: CGFloat = 1.5,
        deliver: @escaping (CGWindowID, NSImage) -> Void
    ) -> Task<Void, Never>? {
        guard ScreenRecordingPermission.isGranted, !windowIDs.isEmpty else { return nil }
        return Task.detached(priority: .userInitiated) {
            guard let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false) else { return }
            let wanted = Set(windowIDs)
            let windows = content.windows.filter { wanted.contains($0.windowID) }
            await withTaskGroup(of: Void.self) { group in
                for window in windows {
                    group.addTask {
                        guard !Task.isCancelled, let image = await thumbnail(of: window, maximumSize: maximumSize, scale: scale) else { return }
                        let identifier = window.windowID
                        await MainActor.run {
                            deliver(identifier, image)
                        }
                    }
                }
            }
        }
    }

    private static func thumbnail(of window: SCWindow, maximumSize: CGSize, scale pixelScale: CGFloat) async -> NSImage? {
        guard window.frame.width > 0, window.frame.height > 0 else { return nil }
        let scale = min(maximumSize.width / window.frame.width, maximumSize.height / window.frame.height, 1)
        let configuration = SCStreamConfiguration()
        configuration.width = max(Int(window.frame.width * scale * pixelScale), 1)
        configuration.height = max(Int(window.frame.height * scale * pixelScale), 1)
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        let filter = SCContentFilter(desktopIndependentWindow: window)
        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) else {
            return nil
        }
        return NSImage(cgImage: image, size: NSSize(width: window.frame.width * scale, height: window.frame.height * scale))
    }
}

final class ThumbnailCache {
    private static let limit = 24

    private var images: [CGWindowID: NSImage] = [:]
    private var order: [CGWindowID] = []

    var all: [CGWindowID: NSImage] { images }

    func store(_ image: NSImage, for windowID: CGWindowID) {
        images[windowID] = image
        order.removeAll { $0 == windowID }
        order.append(windowID)
        while order.count > Self.limit {
            images[order.removeFirst()] = nil
        }
    }

    func clear() {
        images.removeAll()
        order.removeAll()
    }
}
