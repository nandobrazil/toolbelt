import AppKit

@_silgen_name("_AXUIElementGetWindow")
private func axElementWindowIdentifier(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

struct SwitchableWindow {
    let windowID: CGWindowID
    let processIdentifier: pid_t
    let element: AXUIElement
    let title: String
    let applicationName: String
    let icon: NSImage?
    let isMinimized: Bool
    let frame: CGRect

    var displayTitle: String {
        title.isEmpty ? applicationName : title
    }

    func focus() {
        if isMinimized {
            AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        let application = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetAttributeValue(application, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }
}

enum WindowCatalog {
    private static let messagingTimeout: Float = 0.15
    private static let minimumSide: CGFloat = 60

    static func windows(includingMinimized: Bool) -> [SwitchableWindow] {
        let ownProcess = ProcessInfo.processInfo.processIdentifier
        let applications = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ownProcess && !$0.isTerminated
        }
        let onScreenOrder = onScreenWindowOrder()

        var perApplication = [[SwitchableWindow]](repeating: [], count: applications.count)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: applications.count) { index in
            let found = accessibilityWindows(of: applications[index])
            lock.lock()
            perApplication[index] = found
            lock.unlock()
        }

        let all = perApplication.flatMap { $0 }
        let visible = all
            .filter { !$0.isMinimized && onScreenOrder[$0.windowID] != nil }
            .sorted { (onScreenOrder[$0.windowID] ?? .max) < (onScreenOrder[$1.windowID] ?? .max) }
        guard includingMinimized else { return visible }
        let minimized = all.filter { $0.isMinimized }
        return visible + minimized
    }

    private static func onScreenWindowOrder() -> [CGWindowID: Int] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        var order: [CGWindowID: Int] = [:]
        for (index, window) in windows.enumerated() {
            guard (window[kCGWindowLayer as String] as? Int) == 0,
                  let identifier = window[kCGWindowNumber as String] as? CGWindowID else { continue }
            order[identifier] = index
        }
        return order
    }

    private static func accessibilityWindows(of application: NSRunningApplication) -> [SwitchableWindow] {
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(applicationElement, messagingTimeout)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(applicationElement, kAXWindowsAttribute as CFString, &value) == .success,
              let elements = value as? [AXUIElement] else { return [] }
        let name = application.localizedName ?? "App"
        return elements.compactMap { element in
            var identifier: CGWindowID = 0
            guard axElementWindowIdentifier(element, &identifier) == .success, identifier != 0 else { return nil }
            let subrole = stringAttribute(element, kAXSubroleAttribute) ?? ""
            guard subrole == kAXStandardWindowSubrole || subrole == kAXDialogSubrole else { return nil }
            let frame = frameOf(element)
            guard frame.width >= minimumSide, frame.height >= minimumSide else { return nil }
            return SwitchableWindow(
                windowID: identifier,
                processIdentifier: application.processIdentifier,
                element: element,
                title: stringAttribute(element, kAXTitleAttribute) ?? "",
                applicationName: name,
                icon: application.icon,
                isMinimized: boolAttribute(element, kAXMinimizedAttribute),
                frame: frame
            )
        }
    }

    private static func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }

    private static func frameOf(_ element: AXUIElement) -> CGRect {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return .zero }
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }
}
