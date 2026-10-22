import AppKit

struct MenuBarLayoutItem: Identifiable, Equatable {
    let id: String
    let title: String
    let label: String
    let icon: NSImage?
    let systemIdentifier: String?
    let isMovable: Bool
    let isBehindNotch: Bool
}

struct MenuBarLayout: Equatable {
    var visible: [MenuBarLayoutItem] = []
    var hidden: [MenuBarLayoutItem] = []

    var isEmpty: Bool { visible.isEmpty && hidden.isEmpty }
}

enum MenuBarLayoutTarget: Equatable {
    case before(String)
    case endOfVisible
    case endOfHidden
}

enum MenuBarMoveOutcome {
    case moved(String)
    case unchanged
    case failed(String)

    var message: String {
        switch self {
        case .moved(let title): return String(localized: "\(title) foi movido.")
        case .unchanged: return String(localized: "Esse ícone já estava nesse lugar.")
        case .failed(let reason): return reason
        }
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

enum MenuBarItemMover {
    private static let adjacencyTolerance: CGFloat = 3
    private static let settleDelay: TimeInterval = 0.4
    private static let menuBarMaximumY: CGFloat = 60

    static func move(
        itemWithID id: String,
        to target: MenuBarLayoutTarget,
        separatorFrame: () -> CGRect?
    ) -> MenuBarMoveOutcome {
        let extras = MenuBarExtras.all()
        let identifiers = MenuBarExtras.identifiers(for: extras)
        guard let sourceIndex = identifiers.firstIndex(of: id) else {
            return .failed(String(localized: "Não achei esse ícone na barra agora. A lista foi atualizada; tente de novo."))
        }
        let source = extras[sourceIndex]
        guard source.isMovable else {
            return .failed(String(localized: "O macOS não deixa mover \(source.title)."))
        }
        guard let screen = NSScreen.screens.first, isOnMenuBar(source.frame, of: screen) else {
            return .failed(String(localized: "\(source.title) não cabe na barra agora (está fora da tela). Esconda outro ícone antes ou use o modo organizar."))
        }
        guard let destination = destination(for: target, extras: extras, identifiers: identifiers, separatorFrame: separatorFrame()) else {
            return .failed(String(localized: "Não achei o lugar de destino na barra. A lista foi atualizada; tente de novo."))
        }
        let isRightOfSource = destination.edge > source.frame.minX
        if isRightOfSource && abs(destination.edge - source.frame.maxX) <= adjacencyTolerance {
            return .unchanged
        }

        let width = source.frame.width
        let start = CGPoint(x: source.frame.midX, y: source.frame.midY)
        let endX = isRightOfSource ? destination.edge - width / 2 : destination.edge + width / 2
        let end = CGPoint(x: min(max(endX, screen.frame.minX + width / 2), screen.frame.maxX - width / 2), y: start.y)

        let isUnderNotch = MenuBarExtras.notchRange()?.contains(start.x) ?? false
        guard MenuBarExtras.owner(at: start) == source.processIdentifier || isUnderNotch else {
            NSLog("Toolbelt: menu bar move aborted, \(source.title) is not under \(start)")
            return .failed(String(localized: "\(source.title) não estava onde eu esperava. Nada foi clicado; tente de novo."))
        }

        NSLog("Toolbelt: moving menu bar item \(source.title) from \(Int(start.x)) to \(Int(end.x))")
        SyntheticMenuBarDrag.perform(from: start, to: end)
        Thread.sleep(forTimeInterval: settleDelay)
        return verify(source: source, destination: destination, separatorFrame: separatorFrame())
    }

    private struct Destination {
        let edge: CGFloat
        let rightNeighbor: AXUIElement?
        let isSeparator: Bool
    }

    private static func destination(
        for target: MenuBarLayoutTarget,
        extras: [MenuBarExtra],
        identifiers: [String],
        separatorFrame: CGRect?
    ) -> Destination? {
        switch target {
        case .before(let id):
            guard let index = identifiers.firstIndex(of: id) else { return nil }
            return Destination(edge: extras[index].frame.minX, rightNeighbor: extras[index].element, isSeparator: false)
        case .endOfHidden:
            guard let separatorFrame else { return nil }
            return Destination(edge: separatorFrame.minX, rightNeighbor: nil, isSeparator: true)
        case .endOfVisible:
            let separatorX = separatorFrame?.minX ?? -.infinity
            if let fixed = extras.first(where: { !$0.isMovable && $0.frame.minX > separatorX }) {
                return Destination(edge: fixed.frame.minX, rightNeighbor: fixed.element, isSeparator: false)
            }
            guard let last = extras.last else { return nil }
            return Destination(edge: last.frame.maxX + 1, rightNeighbor: nil, isSeparator: false)
        }
    }

    private static func verify(source: MenuBarExtra, destination: Destination, separatorFrame: CGRect?) -> MenuBarMoveOutcome {
        let extras = MenuBarExtras.all()
        guard let moved = extras.first(where: { CFEqual($0.element, source.element) }) else {
            return .failed(String(localized: "\(source.title) sumiu da barra durante o movimento. Confira a barra e tente de novo."))
        }
        guard abs(moved.frame.minX - source.frame.minX) > 1 else {
            return .failed(String(localized: "O macOS não deixou mover \(source.title). Nada mudou; ainda dá para usar o modo organizar (⌥ clique no cinto)."))
        }
        let expectedEdge: CGFloat?
        if destination.isSeparator {
            expectedEdge = separatorFrame?.minX
        } else if let rightNeighbor = destination.rightNeighbor {
            expectedEdge = extras.first { CFEqual($0.element, rightNeighbor) }?.frame.minX
        } else {
            expectedEdge = nil
        }
        if let expectedEdge, abs(expectedEdge - moved.frame.maxX) > adjacencyTolerance {
            NSLog("Toolbelt: menu bar item \(source.title) ended at \(Int(moved.frame.maxX)), expected \(Int(expectedEdge))")
            return .failed(String(localized: "\(source.title) se mexeu, mas não ficou exatamente onde você soltou. Arraste de novo."))
        }
        return .moved(source.title)
    }

    private static func isOnMenuBar(_ frame: CGRect, of screen: NSScreen) -> Bool {
        frame.minX >= screen.frame.minX
            && frame.maxX <= screen.frame.maxX
            && frame.minY >= 0
            && frame.maxY <= menuBarMaximumY
    }
}

enum SyntheticMenuBarDrag {
    private static let commandKeyCode: CGKeyCode = 0x37
    private static let dragSteps = 12

    static func perform(from start: CGPoint, to end: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        let originalLocation = CGEvent(source: nil)?.location ?? start
        let display = CGMainDisplayID()
        CGAssociateMouseAndMouseCursorPosition(0)
        CGDisplayHideCursor(display)

        postCommandKey(isDown: true, source: source)
        postMouse(.mouseMoved, at: start, source: source)
        pause(0.03)
        postMouse(.leftMouseDown, at: start, source: source)
        pause(0.08)
        for step in 1...dragSteps {
            let progress = CGFloat(step) / CGFloat(dragSteps)
            let point = CGPoint(x: start.x + (end.x - start.x) * progress, y: start.y + (end.y - start.y) * progress)
            postMouse(.leftMouseDragged, at: point, source: source)
            pause(0.012)
        }
        pause(0.05)
        postMouse(.leftMouseUp, at: end, source: source)
        pause(0.05)
        postCommandKey(isDown: false, source: source)

        CGWarpMouseCursorPosition(originalLocation)
        CGAssociateMouseAndMouseCursorPosition(1)
        CGDisplayShowCursor(display)
    }

    private static func postMouse(_ type: CGEventType, at point: CGPoint, source: CGEventSource?) {
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else { return }
        event.flags = .maskCommand
        if type == .leftMouseDown || type == .leftMouseUp || type == .leftMouseDragged {
            event.setIntegerValueField(.mouseEventClickState, value: 1)
        }
        event.post(tap: .cghidEventTap)
    }

    private static func postCommandKey(isDown: Bool, source: CGEventSource?) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: commandKeyCode, keyDown: isDown) else { return }
        event.flags = isDown ? .maskCommand : []
        event.post(tap: .cghidEventTap)
    }

    private static func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }
}
