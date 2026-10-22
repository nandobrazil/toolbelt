import AppKit

enum WindowLayout: CaseIterable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case maximize, center
    case firstThird, centerThird, lastThird, firstTwoThirds, lastTwoThirds
    case topLeft, topRight, bottomLeft, bottomRight
    case nextDisplay, previousDisplay

    var title: String {
        switch self {
        case .leftHalf: return "Metade esquerda"
        case .rightHalf: return "Metade direita"
        case .topHalf: return "Metade de cima"
        case .bottomHalf: return "Metade de baixo"
        case .maximize: return "Maximizar"
        case .center: return "Centralizar"
        case .firstThird: return "Primeiro terço"
        case .centerThird: return "Terço do meio"
        case .lastThird: return "Último terço"
        case .firstTwoThirds: return "Dois terços à esquerda"
        case .lastTwoThirds: return "Dois terços à direita"
        case .topLeft: return "Canto superior esquerdo"
        case .topRight: return "Canto superior direito"
        case .bottomLeft: return "Canto inferior esquerdo"
        case .bottomRight: return "Canto inferior direito"
        case .nextDisplay: return "Próximo monitor"
        case .previousDisplay: return "Monitor anterior"
        }
    }

    var combo: KeyCombo {
        let controlOption = KeyCombo.control | KeyCombo.option
        let controlOptionCommand = controlOption | KeyCombo.command
        switch self {
        case .leftHalf: return KeyCombo(keyCode: 123, modifiers: controlOption, display: "⌃⌥←")
        case .rightHalf: return KeyCombo(keyCode: 124, modifiers: controlOption, display: "⌃⌥→")
        case .topHalf: return KeyCombo(keyCode: 126, modifiers: controlOption, display: "⌃⌥↑")
        case .bottomHalf: return KeyCombo(keyCode: 125, modifiers: controlOption, display: "⌃⌥↓")
        case .maximize: return KeyCombo(keyCode: 36, modifiers: controlOption, display: "⌃⌥↩")
        case .center: return KeyCombo(keyCode: 8, modifiers: controlOption, display: "⌃⌥C")
        case .firstThird: return KeyCombo(keyCode: 2, modifiers: controlOption, display: "⌃⌥D")
        case .centerThird: return KeyCombo(keyCode: 3, modifiers: controlOption, display: "⌃⌥F")
        case .lastThird: return KeyCombo(keyCode: 5, modifiers: controlOption, display: "⌃⌥G")
        case .firstTwoThirds: return KeyCombo(keyCode: 14, modifiers: controlOption, display: "⌃⌥E")
        case .lastTwoThirds: return KeyCombo(keyCode: 17, modifiers: controlOption, display: "⌃⌥T")
        case .topLeft: return KeyCombo(keyCode: 32, modifiers: controlOption, display: "⌃⌥U")
        case .topRight: return KeyCombo(keyCode: 34, modifiers: controlOption, display: "⌃⌥I")
        case .bottomLeft: return KeyCombo(keyCode: 38, modifiers: controlOption, display: "⌃⌥J")
        case .bottomRight: return KeyCombo(keyCode: 40, modifiers: controlOption, display: "⌃⌥K")
        case .nextDisplay: return KeyCombo(keyCode: 124, modifiers: controlOptionCommand, display: "⌃⌥⌘→")
        case .previousDisplay: return KeyCombo(keyCode: 123, modifiers: controlOptionCommand, display: "⌃⌥⌘←")
        }
    }

    func frame(for window: CGRect, in screen: CGRect) -> CGRect {
        let third = screen.width / 3
        let halfWidth = screen.width / 2
        let halfHeight = screen.height / 2
        switch self {
        case .leftHalf: return CGRect(x: screen.minX, y: screen.minY, width: halfWidth, height: screen.height)
        case .rightHalf: return CGRect(x: screen.midX, y: screen.minY, width: halfWidth, height: screen.height)
        case .topHalf: return CGRect(x: screen.minX, y: screen.midY, width: screen.width, height: halfHeight)
        case .bottomHalf: return CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: halfHeight)
        case .maximize: return screen
        case .center:
            let width = min(window.width, screen.width)
            let height = min(window.height, screen.height)
            return CGRect(x: screen.midX - width / 2, y: screen.midY - height / 2, width: width, height: height)
        case .firstThird: return CGRect(x: screen.minX, y: screen.minY, width: third, height: screen.height)
        case .centerThird: return CGRect(x: screen.minX + third, y: screen.minY, width: third, height: screen.height)
        case .lastThird: return CGRect(x: screen.minX + third * 2, y: screen.minY, width: third, height: screen.height)
        case .firstTwoThirds: return CGRect(x: screen.minX, y: screen.minY, width: third * 2, height: screen.height)
        case .lastTwoThirds: return CGRect(x: screen.minX + third, y: screen.minY, width: third * 2, height: screen.height)
        case .topLeft: return CGRect(x: screen.minX, y: screen.midY, width: halfWidth, height: halfHeight)
        case .topRight: return CGRect(x: screen.midX, y: screen.midY, width: halfWidth, height: halfHeight)
        case .bottomLeft: return CGRect(x: screen.minX, y: screen.minY, width: halfWidth, height: halfHeight)
        case .bottomRight: return CGRect(x: screen.midX, y: screen.minY, width: halfWidth, height: halfHeight)
        case .nextDisplay, .previousDisplay: return window
        }
    }
}

final class WindowLayoutModule: ToolbeltModule {
    let identifier = "windowLayout"
    let title = "Organizar janelas"
    let requiresAccessibility = true

    private var hotKeyIdentifiers: [UInt32] = []

    func start() {
        for layout in WindowLayout.allCases {
            if let identifier = HotKeyCenter.shared.register(layout.combo, handler: { [weak self] in
                self?.apply(layout)
            }) {
                hotKeyIdentifiers.append(identifier)
            }
        }
    }

    func stop() {
        hotKeyIdentifiers.forEach(HotKeyCenter.shared.unregister)
        hotKeyIdentifiers.removeAll()
    }

    func menuItems() -> [NSMenuItem] {
        let item = NSMenuItem(title: "Atalhos de janela", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for layout in WindowLayout.allCases {
            submenu.addItem(ActionMenuItem(title: "\(layout.title)\t\(layout.combo.display)") { [weak self] in
                self?.apply(layout)
            })
        }
        item.submenu = submenu
        return [item]
    }

    private func apply(_ layout: WindowLayout) {
        guard AccessibilityPermission.isTrusted else {
            AccessibilityPermission.requestIfNeeded()
            return
        }
        guard let window = FocusedWindow.current(), let windowFrame = window.frame else { return }
        let screens = NSScreen.screens
        guard let currentScreen = Self.screen(containing: windowFrame, among: screens) else { return }

        switch layout {
        case .nextDisplay, .previousDisplay:
            guard screens.count > 1, let index = screens.firstIndex(of: currentScreen) else { return }
            let offset = layout == .nextDisplay ? 1 : screens.count - 1
            let target = screens[(index + offset) % screens.count].visibleFrame
            let source = currentScreen.visibleFrame
            let relativeX = (windowFrame.minX - source.minX) / source.width
            let relativeY = (windowFrame.minY - source.minY) / source.height
            let width = min(windowFrame.width / source.width * target.width, target.width)
            let height = min(windowFrame.height / source.height * target.height, target.height)
            window.setFrame(CGRect(
                x: target.minX + relativeX * target.width,
                y: target.minY + relativeY * target.height,
                width: width,
                height: height
            ))
        default:
            window.setFrame(layout.frame(for: windowFrame, in: currentScreen.visibleFrame))
        }
    }

    private static func screen(containing frame: CGRect, among screens: [NSScreen]) -> NSScreen? {
        screens.max { first, second in
            area(first.frame.intersection(frame)) < area(second.frame.intersection(frame))
        } ?? NSScreen.main
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }
}

struct FocusedWindow {
    let element: AXUIElement

    static func current() -> FocusedWindow? {
        guard let application = NSWorkspace.shared.frontmostApplication else { return nil }
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(applicationElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return FocusedWindow(element: value as! AXUIElement)
    }

    var frame: CGRect? {
        guard let position = pointValue(kAXPositionAttribute), let size = sizeValue(kAXSizeAttribute) else { return nil }
        return CGRect(x: position.x, y: Self.flippedY(position.y + size.height), width: size.width, height: size.height)
    }

    func setFrame(_ frame: CGRect) {
        var size = frame.size
        var position = CGPoint(x: frame.minX, y: Self.flippedY(frame.maxY))
        guard let sizeValue = AXValueCreate(.cgSize, &size),
              let positionValue = AXValueCreate(.cgPoint, &position) else { return }
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue)
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
    }

    private static func flippedY(_ y: CGFloat) -> CGFloat {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return primaryHeight - y
    }

    private func pointValue(_ attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
    }

    private func sizeValue(_ attribute: String) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
    }
}
