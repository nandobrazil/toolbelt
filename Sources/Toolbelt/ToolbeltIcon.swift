import AppKit

enum ToolbeltIcon {
    static func image(isOpen: Bool, pointSize: CGFloat = 18) -> NSImage {
        let size = NSSize(width: pointSize, height: pointSize)
        let image = NSImage(size: size, flipped: false) { rect in
            let unit = rect.width / 18
            func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
                NSRect(x: x * unit, y: y * unit, width: width * unit, height: height * unit)
            }
            NSColor.black.set()

            let strap = NSBezierPath(roundedRect: box(7, 6.25, 10, 5.5), xRadius: 2.75 * unit, yRadius: 2.75 * unit)
            strap.fill()

            let buckleOuter = box(1.5, 3, 7, 12)
            let buckleInner = buckleOuter.insetBy(dx: 1.6 * unit, dy: 1.6 * unit)
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(roundedRect: buckleOuter.insetBy(dx: -0.9 * unit, dy: -0.9 * unit), xRadius: 3 * unit, yRadius: 3 * unit).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver

            let frame = NSBezierPath(roundedRect: buckleOuter, xRadius: 2.4 * unit, yRadius: 2.4 * unit)
            frame.append(NSBezierPath(roundedRect: buckleInner, xRadius: 1.2 * unit, yRadius: 1.2 * unit).reversed)
            frame.fill()

            if isOpen {
                NSBezierPath(roundedRect: buckleInner, xRadius: 1.2 * unit, yRadius: 1.2 * unit).fill()
            } else {
                let prong = NSBezierPath(roundedRect: box(3.1, 8.35, 4.6, 1.3), xRadius: 0.65 * unit, yRadius: 0.65 * unit)
                prong.fill()
            }

            NSGraphicsContext.current?.compositingOperation = .clear
            for x in [12.6, 15] {
                NSBezierPath(ovalIn: box(x - 0.7, 8.3, 1.4, 1.4)).fill()
            }
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            return true
        }
        image.isTemplate = true
        return image
    }
}
