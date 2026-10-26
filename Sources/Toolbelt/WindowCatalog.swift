import AppKit

@_silgen_name("_AXUIElementGetWindow")
private func axElementWindowIdentifier(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

@_silgen_name("GetProcessForPID")
private func processSerialNumber(for processIdentifier: pid_t, _ serialNumber: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

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

    func matches(_ query: String) -> Bool {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return applicationName.range(of: query, options: options) != nil || title.range(of: query, options: options) != nil
    }

    func minimize() -> SwitchableWindow {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        return SwitchableWindow(
            windowID: windowID,
            processIdentifier: processIdentifier,
            element: element,
            title: title,
            applicationName: applicationName,
            icon: icon,
            isMinimized: true,
            frame: frame
        )
    }

    func close() {
        var button: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXCloseButtonAttribute as CFString, &button) == .success,
              let button, CFGetTypeID(button) == AXUIElementGetTypeID() else { return }
        AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
    }

    func focus() {
        if isMinimized {
            AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        if !WindowServerFocus.bringToFront(windowID: windowID, processIdentifier: processIdentifier) {
            let application = AXUIElementCreateApplication(processIdentifier)
            AXUIElementSetAttributeValue(application, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        }
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }
}

private enum WindowServerFocus {
    private typealias SetFrontProcess = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> CGError
    private typealias PostEventRecord = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError

    private static let userGeneratedMode: UInt32 = 0x200
    private static let eventRecordSize = 0xf8
    private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    private static let setFrontProcess = function(named: "_SLPSSetFrontProcessWithOptions", as: SetFrontProcess.self)
    private static let postEventRecord = function(named: "SLPSPostEventRecordTo", as: PostEventRecord.self)

    static func bringToFront(windowID: CGWindowID, processIdentifier: pid_t) -> Bool {
        guard let setFrontProcess, let postEventRecord else {
            NSLog("Toolbelt: window server focus unavailable, falling back to accessibility")
            return false
        }
        var process = ProcessSerialNumber()
        guard processSerialNumber(for: processIdentifier, &process) == noErr else { return false }
        let result = setFrontProcess(&process, windowID, userGeneratedMode)
        guard result == .success else {
            NSLog("Toolbelt: window server focus failed for window \(windowID): \(result.rawValue)")
            return false
        }
        for phase: UInt8 in [0x01, 0x02] {
            var record = keyWindowRecord(windowID: windowID, phase: phase)
            _ = postEventRecord(&process, &record)
        }
        return true
    }

    private static func keyWindowRecord(windowID: CGWindowID, phase: UInt8) -> [UInt8] {
        var record = [UInt8](repeating: 0, count: eventRecordSize)
        record[0x04] = 0xf8
        record[0x08] = phase
        record[0x3a] = 0x10
        record.replaceSubrange(0x20..<0x30, with: repeatElement(0xff, count: 0x10))
        withUnsafeBytes(of: windowID.littleEndian) { record.replaceSubrange(0x3c..<0x40, with: $0) }
        return record
    }

    private static func function<Function>(named name: String, as type: Function.Type) -> Function? {
        guard let skyLight, let symbol = dlsym(skyLight, name) else { return nil }
        return unsafeBitCast(symbol, to: type)
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

    static func frontWindowID(of processIdentifier: pid_t) -> CGWindowID? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.first {
            ($0[kCGWindowOwnerPID as String] as? pid_t) == processIdentifier && ($0[kCGWindowLayer as String] as? Int) == 0
        }?[kCGWindowNumber as String] as? CGWindowID
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
