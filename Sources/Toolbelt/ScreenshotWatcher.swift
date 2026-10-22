import AppKit

final class ScreenshotWatcher {
    private let query = NSMetadataQuery()
    private var knownPaths: Set<String> = []
    private var isPrimed = false
    var onScreenshot: ((URL) -> Void)?

    func start() {
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryFinishedGathering),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryUpdated),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )
        query.start()
    }

    func stop() {
        query.stop()
        NotificationCenter.default.removeObserver(self)
        knownPaths.removeAll()
        isPrimed = false
    }

    @objc private func queryFinishedGathering() {
        query.disableUpdates()
        knownPaths = Set(currentPaths())
        isPrimed = true
        query.enableUpdates()
    }

    @objc private func queryUpdated() {
        guard isPrimed else { return }
        query.disableUpdates()
        let paths = currentPaths()
        let newPaths = paths.filter { !knownPaths.contains($0) }
        knownPaths.formUnion(newPaths)
        query.enableUpdates()
        for path in newPaths {
            onScreenshot?(URL(fileURLWithPath: path))
        }
    }

    private func currentPaths() -> [String] {
        (0..<query.resultCount).compactMap { index in
            (query.result(at: index) as? NSMetadataItem)?.value(forAttribute: NSMetadataItemPathKey) as? String
        }
    }
}
