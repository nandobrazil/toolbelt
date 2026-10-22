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
    private static let messagingTimeout: Float = 0.25

    static func hidden() -> [MenuBarExtra] {
        let visibleStart = visibleAreaStart()
        return all().filter { $0.frame.minX < visibleStart }
    }

    static func all() -> [MenuBarExtra] {
        let ownProcess = ProcessInfo.processInfo.processIdentifier
        var extras: [MenuBarExtra] = []
        for application in NSWorkspace.shared.runningApplications where application.processIdentifier != ownProcess {
            let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
            AXUIElementSetMessagingTimeout(applicationElement, messagingTimeout)
            guard let bar = copyElement(applicationElement, "AXExtrasMenuBar"),
                  let children = copyAttribute(bar, kAXChildrenAttribute) as? [AXUIElement] else { continue }
            for child in children {
                guard let frame = frame(of: child), frame.width > 0, frame.width < maximumItemWidth else { continue }
                let name = application.localizedName ?? application.bundleIdentifier ?? "App"
                let description = (copyAttribute(child, kAXDescriptionAttribute) as? String) ?? ""
                let title = (copyAttribute(child, kAXTitleAttribute) as? String) ?? ""
                let label = [title, description].first { !$0.isEmpty } ?? name
                extras.append(MenuBarExtra(
                    element: child,
                    processIdentifier: application.processIdentifier,
                    applicationName: name,
                    icon: application.icon,
                    label: label == name ? name : "\(name) — \(label)",
                    frame: frame
                ))
            }
        }
        return extras.sorted { $0.frame.minX < $1.frame.minX }
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
