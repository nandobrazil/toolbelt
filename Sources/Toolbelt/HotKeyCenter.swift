import AppKit
import Carbon

struct KeyCombo: Codable, Equatable, Hashable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let control = UInt32(controlKey)
    static let option = UInt32(optionKey)
    static let command = UInt32(cmdKey)
    static let shift = UInt32(shiftKey)

    private static let specialKeyNames: [UInt32: String] = [
        123: "←", 124: "→", 125: "↓", 126: "↑",
        36: "↩", 76: "⌤", 48: "⇥", 49: "Espaço", 51: "⌫", 53: "⎋", 117: "⌦",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]

    var display: String {
        var symbols = ""
        if modifiers & Self.control != 0 { symbols += "⌃" }
        if modifiers & Self.option != 0 { symbols += "⌥" }
        if modifiers & Self.shift != 0 { symbols += "⇧" }
        if modifiers & Self.command != 0 { symbols += "⌘" }
        return symbols + Self.keyName(for: keyCode)
    }

    var hasRequiredModifier: Bool {
        modifiers & (Self.control | Self.option | Self.command) != 0
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= control }
        if flags.contains(.option) { modifiers |= option }
        if flags.contains(.shift) { modifiers |= shift }
        if flags.contains(.command) { modifiers |= command }
        return modifiers
    }

    static func keyName(for keyCode: UInt32) -> String {
        if let special = specialKeyNames[keyCode] {
            return special
        }
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "#\(keyCode)"
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPointer).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = layoutData.withUnsafeBytes { buffer -> OSStatus in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }
        guard status == noErr, length > 0 else { return "#\(keyCode)" }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }
}

final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private struct Registration {
        let combo: KeyCombo
        let handler: () -> Void
        var reference: EventHotKeyRef?
    }

    private var registrations: [UInt32: Registration] = [:]
    private var nextIdentifier: UInt32 = 1
    private var isHandlerInstalled = false
    private var isSuspended = false

    @discardableResult
    func register(_ combo: KeyCombo, handler: @escaping () -> Void) -> UInt32? {
        installHandlerIfNeeded()
        let identifier = nextIdentifier
        nextIdentifier += 1
        var registration = Registration(combo: combo, handler: handler, reference: nil)
        if !isSuspended {
            guard let reference = registerSystemHotKey(combo, identifier: identifier) else { return nil }
            registration.reference = reference
        }
        registrations[identifier] = registration
        syncNativeWindowSwitching()
        return identifier
    }

    func unregister(_ identifier: UInt32) {
        if let reference = registrations.removeValue(forKey: identifier)?.reference {
            UnregisterEventHotKey(reference)
        }
        syncNativeWindowSwitching()
    }

    func suspend() {
        guard !isSuspended else { return }
        isSuspended = true
        for identifier in registrations.keys {
            if let reference = registrations[identifier]?.reference {
                UnregisterEventHotKey(reference)
            }
            registrations[identifier]?.reference = nil
        }
        syncNativeWindowSwitching()
    }

    func resume() {
        guard isSuspended else { return }
        isSuspended = false
        for (identifier, registration) in registrations {
            registrations[identifier]?.reference = registerSystemHotKey(registration.combo, identifier: identifier)
        }
        syncNativeWindowSwitching()
    }

    private func syncNativeWindowSwitching() {
        NativeWindowSwitching.update(
            claimedCombos: Set(registrations.values.map(\.combo)),
            isRecordingShortcut: isSuspended
        )
    }

    fileprivate func handle(_ identifier: UInt32) {
        guard !isSuspended else { return }
        registrations[identifier]?.handler()
    }

    private func registerSystemHotKey(_ combo: KeyCombo, identifier: UInt32) -> EventHotKeyRef? {
        var reference: EventHotKeyRef?
        let hotKeyIdentifier = EventHotKeyID(signature: OSType(0x544C_4254), id: identifier)
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.modifiers,
            hotKeyIdentifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            NSLog("Toolbelt: hotkey \(combo.display) not registered, status \(status)")
            CrashReporter.shared.record("hotkey.register_failed", attrs: ["shortcut": .string(combo.display), "status": .integer(Int(status))])
            return nil
        }
        return reference
    }

    private func installHandlerIfNeeded() {
        guard !isHandlerInstalled else { return }
        isHandlerInstalled = true
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyIdentifier = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyIdentifier
            )
            let identifier = hotKeyIdentifier.id
            DispatchQueue.main.async {
                HotKeyCenter.shared.handle(identifier)
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}
