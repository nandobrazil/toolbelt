import AppKit

@_silgen_name("CGSGetSymbolicHotKeyValue")
private func symbolicHotKeyValue(
    _ hotKey: UInt32,
    _ character: UnsafeMutablePointer<UInt16>,
    _ keyCode: UnsafeMutablePointer<UInt16>,
    _ modifiers: UnsafeMutablePointer<UInt32>
) -> CGError

@_silgen_name("CGSSetSymbolicHotKeyEnabled")
@discardableResult
private func setSymbolicHotKeyEnabled(_ hotKey: UInt32, _ isEnabled: Bool) -> CGError

enum NativeWindowSwitching {
    private static let commandTab: UInt32 = 1
    private static let commandShiftTab: UInt32 = 2
    private static let moveFocusToNextWindow: UInt32 = 27
    private static let hotKeys = [commandTab, commandShiftTab, moveFocusToNextWindow]
    private static let terminationSignals = [SIGTERM, SIGINT, SIGHUP, SIGQUIT]

    private static var appliedStates: [UInt32: Bool] = [:]
    private static var signalSources: [DispatchSourceSignal] = []
    private static var terminationObserver: NSObjectProtocol?

    static func restoreOnExit() {
        restore()
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            restore()
        }
        signalSources = terminationSignals.map { signalNumber in
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler {
                restore()
                exit(0)
            }
            source.resume()
            return source
        }
    }

    static func update(claimedCombos: Set<KeyCombo>, isRecordingShortcut: Bool) {
        for hotKey in hotKeys {
            let isClaimed = combo(of: hotKey).map(claimedCombos.contains) ?? false
            apply(!(isRecordingShortcut || isClaimed), to: hotKey)
        }
    }

    private static func restore() {
        hotKeys.forEach { apply(true, to: $0) }
    }

    private static func apply(_ isEnabled: Bool, to hotKey: UInt32) {
        guard appliedStates[hotKey] != isEnabled else { return }
        appliedStates[hotKey] = isEnabled
        let status = setSymbolicHotKeyEnabled(hotKey, isEnabled)
        if status != .success {
            NSLog("Toolbelt: native hotkey \(hotKey) enabled=\(isEnabled) failed, status \(status.rawValue)")
            CrashReporter.shared.record("native_switching.failed", attrs: ["hotKey": .integer(Int(hotKey)), "enabled": .bool(isEnabled), "status": .integer(Int(status.rawValue))])
        }
    }

    private static func combo(of hotKey: UInt32) -> KeyCombo? {
        var character: UInt16 = 0
        var keyCode: UInt16 = 0
        var flags: UInt32 = 0
        guard symbolicHotKeyValue(hotKey, &character, &keyCode, &flags) == .success else { return nil }
        let eventFlags = CGEventFlags(rawValue: UInt64(flags))
        var modifiers: UInt32 = 0
        if eventFlags.contains(.maskCommand) { modifiers |= KeyCombo.command }
        if eventFlags.contains(.maskAlternate) { modifiers |= KeyCombo.option }
        if eventFlags.contains(.maskControl) { modifiers |= KeyCombo.control }
        if eventFlags.contains(.maskShift) { modifiers |= KeyCombo.shift }
        return KeyCombo(keyCode: UInt32(keyCode), modifiers: modifiers)
    }
}
