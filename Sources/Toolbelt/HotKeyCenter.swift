import AppKit
import Carbon

struct KeyCombo {
    let keyCode: UInt32
    let modifiers: UInt32
    let display: String

    static let control = UInt32(controlKey)
    static let option = UInt32(optionKey)
    static let command = UInt32(cmdKey)
    static let shift = UInt32(shiftKey)
}

final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var handlers: [UInt32: () -> Void] = [:]
    private var references: [UInt32: EventHotKeyRef] = [:]
    private var nextIdentifier: UInt32 = 1
    private var isHandlerInstalled = false

    @discardableResult
    func register(_ combo: KeyCombo, handler: @escaping () -> Void) -> UInt32? {
        installHandlerIfNeeded()
        let identifier = nextIdentifier
        nextIdentifier += 1
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
            return nil
        }
        handlers[identifier] = handler
        references[identifier] = reference
        return identifier
    }

    func unregister(_ identifier: UInt32) {
        if let reference = references.removeValue(forKey: identifier) {
            UnregisterEventHotKey(reference)
        }
        handlers[identifier] = nil
    }

    fileprivate func handle(_ identifier: UInt32) {
        handlers[identifier]?()
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
