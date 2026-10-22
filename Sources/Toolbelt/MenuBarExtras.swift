import AppKit

struct MenuBarExtra {
    let element: AXUIElement
    let processIdentifier: pid_t
    let applicationName: String
    let icon: NSImage?
    let label: String
    let frame: CGRect

    func press() {
        let element = element
        DispatchQueue.global(qos: .userInitiated).async {
            let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
            NSLog("Toolbelt: pressed menu bar item, result \(result.rawValue)")
        }
    }
}

enum MenuBarExtras {
    private static let maximumItemWidth: CGFloat = 300
    private static let messagingTimeout: Float = 0.1
    private static let stateQueue = DispatchQueue(label: "dev.oconde.toolbelt.menu-bar-extras")
    private static let skipListLifetime: TimeInterval = 60
    private static var processesWithoutExtras: Set<pid_t> = []
    private static var skipListCreatedAt = Date()

    static func hidden(from extras: [MenuBarExtra]) -> [MenuBarExtra] {
        let visibleStart = visibleAreaStart()
        return extras.filter { $0.frame.minX < visibleStart }
    }

    static func all() -> [MenuBarExtra] {
        let ownProcess = ProcessInfo.processInfo.processIdentifier
        let running = NSWorkspace.shared.runningApplications.filter { application in
            application.processIdentifier != ownProcess && !isHelperProcess(application)
        }
        let skipped = stateQueue.sync { () -> Set<pid_t> in
            if Date().timeIntervalSince(skipListCreatedAt) > skipListLifetime {
                processesWithoutExtras.removeAll()
                skipListCreatedAt = Date()
            }
            processesWithoutExtras.formIntersection(running.map(\.processIdentifier))
            return processesWithoutExtras
        }
        let candidates = running.filter { !skipped.contains($0.processIdentifier) }

        var results = [[MenuBarExtra]?](repeating: nil, count: candidates.count)
        let resultsLock = NSLock()
        DispatchQueue.concurrentPerform(iterations: candidates.count) { index in
            let found = extrasOf(candidates[index])
            resultsLock.lock()
            results[index] = found
            resultsLock.unlock()
        }

        var withoutExtras: [pid_t] = []
        var extras: [MenuBarExtra] = []
        for (index, result) in results.enumerated() {
            if let result {
                extras.append(contentsOf: result)
            } else {
                withoutExtras.append(candidates[index].processIdentifier)
            }
        }
        stateQueue.sync {
            processesWithoutExtras.formUnion(withoutExtras)
        }
        return extras.sorted { $0.frame.minX < $1.frame.minX }
    }

    private static func extrasOf(_ application: NSRunningApplication) -> [MenuBarExtra]? {
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(applicationElement, messagingTimeout)
        var barValue: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(applicationElement, "AXExtrasMenuBar" as CFString, &barValue)
        guard status == .success, let barValue, CFGetTypeID(barValue) == AXUIElementGetTypeID() else {
            return status == .cannotComplete ? [] : nil
        }
        let bar = barValue as! AXUIElement
        AXUIElementSetMessagingTimeout(bar, messagingTimeout)
        guard let children = copyAttribute(bar, kAXChildrenAttribute) as? [AXUIElement] else { return [] }
        let name = application.localizedName ?? application.bundleIdentifier ?? "App"
        return children.compactMap { child in
            guard let frame = frame(of: child), frame.width > 0, frame.width < maximumItemWidth else { return nil }
            let description = (copyAttribute(child, kAXDescriptionAttribute) as? String) ?? ""
            let title = (copyAttribute(child, kAXTitleAttribute) as? String) ?? ""
            let label = [title, description].first { !$0.isEmpty } ?? name
            return MenuBarExtra(
                element: child,
                processIdentifier: application.processIdentifier,
                applicationName: name,
                icon: application.icon,
                label: label == name ? name : "\(name) — \(label)",
                frame: frame
            )
        }
    }

    private static func isHelperProcess(_ application: NSRunningApplication) -> Bool {
        let path = application.bundleURL?.path ?? ""
        return path.contains(".xpc") || path.contains("/XPCServices/") || path.contains("/Frameworks/")
    }

    static func hasOpenPopup(for processIdentifier: pid_t) -> Bool {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.contains { window in
            (window[kCGWindowOwnerPID as String] as? pid_t) == processIdentifier
                && ((window[kCGWindowLayer as String] as? Int) ?? 0) > 0
        }
    }

    private static func visibleAreaStart() -> CGFloat {
        let notchedScreen = NSScreen.screens.first { $0.auxiliaryTopRightArea != nil }
        if let notchedScreen, let rightArea = notchedScreen.auxiliaryTopRightArea {
            return notchedScreen.frame.minX + rightArea.minX
        }
        return NSScreen.screens.first?.frame.minX ?? 0
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let positionValue = copyAttribute(element, kAXPositionAttribute),
              let sizeValue = copyAttribute(element, kAXSizeAttribute),
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }

    private static func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
    }

    private static func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copyAttribute(element, attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
}
