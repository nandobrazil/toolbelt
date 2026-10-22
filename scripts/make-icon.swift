import AppKit

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func gradient(_ top: String, _ bottom: String) -> NSGradient {
    NSGradient(starting: color(top), ending: color(bottom))!
}

func color(_ hex: String, alpha: CGFloat = 1) -> NSColor {
    let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
    return NSColor(
        srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: alpha
    )
}

func drawIcon(in canvas: NSRect) {
    let scale = canvas.width / 1024
    let body = NSRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185 * scale, yRadius: 185 * scale)

    NSGraphicsContext.saveGraphicsState()
    let bodyShadow = NSShadow()
    bodyShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    bodyShadow.shadowBlurRadius = 24 * scale
    bodyShadow.shadowOffset = NSSize(width: 0, height: -10 * scale)
    bodyShadow.set()
    color("#1A1D23").setFill()
    bodyPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    bodyPath.addClip()
    gradient("#3A4150", "#16191F").draw(in: body, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    bodyPath.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.10), NSColor.white.withAlphaComponent(0)])!
        .draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    let unit = 36 * scale
    let origin = NSPoint(x: canvas.midX - 8.8 * unit, y: canvas.midY - 9 * unit)
    func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(x: origin.x + x * unit, y: origin.y + y * unit, width: width * unit, height: height * unit)
    }

    let buckleOuter = box(1.5, 3, 7, 12)
    let buckleInner = buckleOuter.insetBy(dx: 1.6 * unit, dy: 1.6 * unit)
    let buckleGap = buckleOuter.insetBy(dx: -0.9 * unit, dy: -0.9 * unit)

    NSGraphicsContext.saveGraphicsState()
    let beltShadow = NSShadow()
    beltShadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
    beltShadow.shadowBlurRadius = 18 * scale
    beltShadow.shadowOffset = NSSize(width: 0, height: -8 * scale)
    beltShadow.set()

    NSGraphicsContext.saveGraphicsState()
    let strapClip = NSBezierPath(rect: canvas)
    strapClip.append(NSBezierPath(roundedRect: buckleGap, xRadius: 3 * unit, yRadius: 3 * unit))
    strapClip.windingRule = .evenOdd
    strapClip.addClip()
    let strapRect = box(7, 6.25, 10, 5.5)
    let strap = NSBezierPath(roundedRect: strapRect, xRadius: 2.75 * unit, yRadius: 2.75 * unit)
    NSGraphicsContext.saveGraphicsState()
    strap.addClip()
    gradient("#C98446", "#7C4521").draw(in: strapRect, angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    color("#3A2213").setFill()
    for x in [12.6, 15] {
        NSBezierPath(ovalIn: box(x - 0.7, 8.3, 1.4, 1.4)).fill()
    }
    let stitch = NSBezierPath()
    stitch.move(to: NSPoint(x: strapRect.minX + 0.6 * unit, y: strapRect.maxY - 0.55 * unit))
    stitch.line(to: NSPoint(x: strapRect.maxX - 1.6 * unit, y: strapRect.maxY - 0.55 * unit))
    stitch.move(to: NSPoint(x: strapRect.minX + 0.6 * unit, y: strapRect.minY + 0.55 * unit))
    stitch.line(to: NSPoint(x: strapRect.maxX - 1.6 * unit, y: strapRect.minY + 0.55 * unit))
    stitch.lineWidth = 0.14 * unit
    stitch.setLineDash([0.5 * unit, 0.35 * unit], count: 2, phase: 0)
    color("#F1C79A", alpha: 0.75).setStroke()
    stitch.stroke()
    NSGraphicsContext.restoreGraphicsState()

    let frame = NSBezierPath(roundedRect: buckleOuter, xRadius: 2.4 * unit, yRadius: 2.4 * unit)
    frame.append(NSBezierPath(roundedRect: buckleInner, xRadius: 1.2 * unit, yRadius: 1.2 * unit).reversed)
    NSGraphicsContext.saveGraphicsState()
    frame.addClip()
    gradient("#FBE29A", "#C38A27").draw(in: buckleOuter, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    let prongRect = box(3.1, 8.35, 4.6, 1.3)
    let prong = NSBezierPath(roundedRect: prongRect, xRadius: 0.65 * unit, yRadius: 0.65 * unit)
    NSGraphicsContext.saveGraphicsState()
    prong.addClip()
    gradient("#F4D27E", "#B47C22").draw(in: prongRect, angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    let highlight = NSBezierPath(roundedRect: buckleOuter.insetBy(dx: 0.35 * unit, dy: 0.35 * unit), xRadius: 2.1 * unit, yRadius: 2.1 * unit)
    highlight.lineWidth = 0.18 * unit
    NSColor.white.withAlphaComponent(0.35).setStroke()
    let topHalf = NSRect(x: buckleOuter.minX, y: buckleOuter.midY, width: buckleOuter.width, height: buckleOuter.height / 2)
    NSBezierPath(rect: topHalf).addClip()
    highlight.stroke()
    NSGraphicsContext.restoreGraphicsState()
}

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for size in sizes {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size.pixels,
        pixelsHigh: size.pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { continue }
    bitmap.size = NSSize(width: size.pixels, height: size.pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    drawIcon(in: NSRect(x: 0, y: 0, width: size.pixels, height: size.pixels))
    NSGraphicsContext.restoreGraphicsState()
    let data = bitmap.representation(using: .png, properties: [:])
    try data?.write(to: outputDirectory.appendingPathComponent("\(size.name).png"))
}
print("wrote \(outputDirectory.path)")
