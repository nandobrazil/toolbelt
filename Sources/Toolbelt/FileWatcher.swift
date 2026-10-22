import Foundation

final class FileWatcher {
    private static let rearmDelay: TimeInterval = 0.5

    private let path: String
    private let throttleInterval: TimeInterval
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var pendingNotification: DispatchWorkItem?

    init(path: String, throttleInterval: TimeInterval = 3, onChange: @escaping () -> Void) {
        self.path = path
        self.throttleInterval = throttleInterval
        self.onChange = onChange
        arm()
    }

    deinit {
        source?.cancel()
        pendingNotification?.cancel()
    }

    private func arm() {
        source?.cancel()
        source = nil
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in self?.arm() }
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self, weak source] in
            guard let self, let source else { return }
            let replaced = !source.data.isDisjoint(with: [.rename, .delete])
            self.scheduleNotification()
            if replaced {
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.rearmDelay) { [weak self] in self?.arm() }
            }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    private func scheduleNotification() {
        guard pendingNotification == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.pendingNotification = nil
            self?.onChange()
        }
        pendingNotification = work
        DispatchQueue.main.asyncAfter(deadline: .now() + throttleInterval, execute: work)
    }
}
