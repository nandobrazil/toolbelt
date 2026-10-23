import AppKit
import SwiftUI

enum OffscreenRendering {
    static var isActive = false

    static func background(material: NSVisualEffectView.Material) -> NSView {
        guard isActive else {
            let view = NSVisualEffectView()
            view.material = material
            view.blendingMode = .behindWindow
            view.state = .active
            return view
        }
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = solidColor(for: material).cgColor
        return view
    }

    private static func solidColor(for material: NSVisualEffectView.Material) -> NSColor {
        switch material {
        case .hudWindow: return NSColor(srgbRed: 0.13, green: 0.13, blue: 0.15, alpha: 0.96)
        case .menu: return NSColor(srgbRed: 0.17, green: 0.17, blue: 0.19, alpha: 0.98)
        default: return NSColor(srgbRed: 0.16, green: 0.16, blue: 0.18, alpha: 0.98)
        }
    }
}

enum LandingScreenshots {
    static let argument = "--landing-screenshots"
    private static let settingsSuite = "dev.oconde.toolbelt.landing-screenshots"
    private static let scale: CGFloat = 2
    private static let settingsPageWidth: CGFloat = 580
    private static let settingsPageTallHeight: CGFloat = 1900
    private static let aboutPageHeight: CGFloat = 470
    private static var keptAlive: [AnyObject] = []
    private static var temporaryDirectories: [URL] = []

    static func outputDirectory(in arguments: [String]) -> URL? {
        guard let index = arguments.firstIndex(of: argument), arguments.indices.contains(index + 1) else { return nil }
        return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
    }

    static func render(into directory: URL) -> Never {
        OffscreenRendering.isActive = true
        guard let suite = UserDefaults(suiteName: settingsSuite) else { exit(1) }
        suite.removePersistentDomain(forName: settingsSuite)
        AppSettings.storage = suite
        AppSettings.shared.values.appSwitcher.shortcut = KeyCombo(keyCode: 48, modifiers: KeyCombo.command)

        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        application.appearance = NSAppearance(named: .darkAqua)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let samples = Samples(english: Bundle.main.preferredLocalizations.first?.hasPrefix("en") == true)
        var written: [String] = []
        func save(_ name: String, _ data: Data?) {
            guard let data else {
                print("failed: \(name)")
                return
            }
            try? data.write(to: directory.appendingPathComponent("\(name).png"))
            written.append(name)
        }

        save("clipboard-picker", snapshot(appKit: clipboardPicker(samples)))
        save("window-switcher", snapshot(appKit: windowSwitcher(samples)))
        save("belt-panel", snapshot(appKit: beltPanel(samples, includesUpdate: false)))
        save("belt-panel-update", snapshot(appKit: beltPanel(samples, includesUpdate: true)))

        let bridge = settingsBridge(samples)
        let updater = AppUpdater()
        for section in SettingsSection.allCases {
            let isAbout = section == .about
            let view = SettingsPage(section: section, settings: AppSettings.shared, bridge: bridge, updater: updater)
            let height = isAbout ? aboutPageHeight : settingsPageTallHeight
            save("settings-\(section.rawValue)", snapshot(swiftUI: view, size: NSSize(width: settingsPageWidth, height: height), trimsBottom: !isAbout))
        }

        suite.removePersistentDomain(forName: settingsSuite)
        temporaryDirectories.forEach { try? FileManager.default.removeItem(at: $0) }
        print("rendered \(written.count) screenshots into \(directory.path): \(written.joined(separator: ", "))")
        exit(0)
    }

    private struct Samples {
        let english: Bool

        func text(_ portuguese: String, _ englishText: String) -> String {
            english ? englishText : portuguese
        }

        var clipboardTexts: [String] {
            [
                text("git commit -m \"Ajusta o editor da barra\" && git push", "git commit -m \"Polish the menu bar editor\" && git push"),
                "https://toolbelt.oconde.dev",
                text("Reunião remarcada para quinta às 15h", "Meeting moved to Thursday at 3 PM"),
                "brew install --cask nandobrazil/tap/toolbelt",
                text("Rua das Laranjeiras, 120, ap. 34 — Curitiba", "120 Orange Street, Apt 34 — Portland")
            ]
        }

        var windows: [(path: String, application: String, title: String)] {
            [
                ("/Applications/Safari.app", "Safari", "Toolbelt — toolbelt.oconde.dev"),
                ("/System/Applications/Utilities/Terminal.app", "Terminal", "toolbelt — zsh — 120×32"),
                ("/System/Applications/Notes.app", text("Notas", "Notes"), text("Ideias para o Toolbelt", "Toolbelt ideas")),
                ("/System/Applications/Mail.app", "Mail", text("Caixa de Entrada", "Inbox")),
                ("/System/Applications/Calendar.app", text("Calendário", "Calendar"), text("Outubro de 2026", "October 2026")),
                ("/System/Library/CoreServices/Finder.app", "Finder", text("Transferências", "Downloads"))
            ]
        }

        var hiddenApplications: [String] {
            [
                "/System/Applications/Music.app",
                "/System/Applications/Weather.app",
                "/System/Applications/Reminders.app",
                "/System/Applications/Photos.app",
                "/System/Applications/Podcasts.app",
                "/System/Applications/Clock.app",
                "/System/Applications/Stocks.app",
                "/System/Applications/Home.app",
                "/System/Applications/Maps.app",
                "/System/Applications/Books.app",
                "/System/Applications/News.app",
                "/System/Applications/Shortcuts.app"
            ]
        }

        var accounts: [ClaudeAccountSummary] {
            let formatter = ISO8601DateFormatter()
            let soon = formatter.string(from: Date().addingTimeInterval(2 * 3600 + 17 * 60))
            let later = formatter.string(from: Date().addingTimeInterval(4 * 86_400))
            return [
                ClaudeAccountSummary(
                    account: "1", alias: text("pessoal", "personal"), label: text("pessoal", "personal"), primary: true, active: true, configured: true,
                    configDir: "~/.claude", email: "you@example.com",
                    fiveHour: ClaudeUsageWindow(percent: 22, resetsAt: soon), sevenDay: ClaudeUsageWindow(percent: 41, resetsAt: later),
                    usageFetchedAtMs: Date().timeIntervalSince1970 * 1000
                ),
                ClaudeAccountSummary(
                    account: "2", alias: text("trabalho", "work"), label: text("trabalho", "work"), primary: false, active: false, configured: true,
                    configDir: "~/.claude-2", email: "you@company.com",
                    fiveHour: ClaudeUsageWindow(percent: 63, resetsAt: soon), sevenDay: ClaudeUsageWindow(percent: 18, resetsAt: later),
                    usageFetchedAtMs: Date().timeIntervalSince1970 * 1000
                )
            ]
        }

        var snapshot: SystemSnapshot {
            let gigabyte: UInt64 = 1_073_741_824
            return SystemSnapshot(
                memoryTotal: 16 * gigabyte,
                memoryApp: 7 * gigabyte + gigabyte / 2,
                memoryWired: 2 * gigabyte + gigabyte / 2,
                memoryCompressed: 2 * gigabyte,
                memoryCached: 2 * gigabyte,
                pressureLevel: 1,
                swapTotal: 2 * gigabyte,
                swapUsed: gigabyte + gigabyte / 5,
                diskTotal: 494 * gigabyte,
                diskFree: 210 * gigabyte
            )
        }

        var release: UpdateRelease {
            UpdateRelease(
                version: "0.3.0",
                build: 52,
                minimumSystemVersion: "14.0",
                archiveURL: URL(string: "https://toolbelt.oconde.dev/download")!,
                archiveSHA256: "",
                downloadPageURL: URL(string: "https://toolbelt.oconde.dev/")!,
                notes: [text("Alternador de janelas mais rápido e novos atalhos de janela.", "A faster window switcher and new window shortcuts.")]
            )
        }

        func icon(_ path: String) -> NSImage {
            let bundleIdentifier = Bundle(path: path)?.bundleIdentifier
            let resolved = bundleIdentifier.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)?.path } ?? path
            return NSWorkspace.shared.icon(forFile: (resolved as NSString).resolvingSymlinksInPath)
        }
    }

    private static func clipboardPicker(_ samples: Samples) -> NSView {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("toolbelt-landing-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = ClipboardStore(directory: directory)
        let texts = samples.clipboardTexts
        for text in texts.dropFirst().reversed() {
            store.addText(text)
        }
        if let image = sampleScreenshotPNG() {
            store.addImage(pngData: image)
        }
        store.addText(texts[0])
        let picker = ClipboardPicker(store: store)
        keptAlive.append(picker)
        temporaryDirectories.append(directory)
        return picker.makeSnapshotContent()
    }

    private static func windowSwitcher(_ samples: Samples) -> NSView {
        let windows = samples.windows.enumerated().map { index, item in
            SwitchableWindow(
                windowID: CGWindowID(index + 1),
                processIdentifier: 0,
                element: AXUIElementCreateApplication(0),
                title: item.title,
                applicationName: item.application,
                icon: samples.icon(item.path),
                isMinimized: false,
                frame: .zero
            )
        }
        let panel = SwitcherPanel()
        keptAlive.append(panel)
        return panel.makeContent(
            windows: windows,
            selectedIndex: 1,
            iconSize: 64,
            showsThumbnails: false,
            cachedThumbnails: [:],
            footer: AppSwitcherModule.keyHints,
            emptyMessage: nil,
            availableWidth: 1440
        )
    }

    private static func beltPanel(_ samples: Samples, includesUpdate: Bool) -> NSView {
        let extras = samples.hiddenApplications.map { path in
            MenuBarExtra(
                element: AXUIElementCreateApplication(0),
                processIdentifier: 0,
                applicationName: FileManager.default.displayName(atPath: path),
                systemIdentifier: nil,
                icon: samples.icon(path),
                title: FileManager.default.displayName(atPath: path),
                label: FileManager.default.displayName(atPath: path),
                frame: .zero
            )
        }
        var sections: [NSView] = []
        if includesUpdate, let update = PanelSections.update(state: .available(samples.release), onInstall: {}) {
            sections.append(update)
        }
        sections.append(PanelSections.claude(accounts: samples.accounts, onUse: { _ in }, onOpenTerminal: { _ in }))
        if !includesUpdate {
            sections.append(PanelSections.system(snapshot: samples.snapshot, onOpenReport: {}))
        }
        let panel = ToolbeltPanel()
        keptAlive.append(panel)
        let content = panel.makeContent(
            hiddenExtras: includesUpdate ? Array(extras.prefix(10)) : extras,
            columns: 10,
            sections: sections,
            quickActions: [
                PanelAction(title: "", symbolName: "doc.on.clipboard") {},
                PanelAction(title: "", symbolName: "arrow.left.and.right.square") {},
                PanelAction(title: "", symbolName: "rectangle.split.2x1") {}
            ],
            trailingActions: [
                PanelAction(title: "", symbolName: "exclamationmark.bubble") {},
                PanelAction(title: "", symbolName: "gearshape") {},
                PanelAction(title: "", symbolName: "power") {}
            ],
            onSelectExtra: { _ in }
        )
        let size = content.fittingSize
        content.frame = NSRect(x: 0, y: 0, width: max(size.width, 250), height: size.height)
        return content
    }

    private static func settingsBridge(_ samples: Samples) -> SettingsBridge {
        let bridge = SettingsBridge()
        let modules: [ToolbeltModule] = [MenuBarOverflowModule(), AppSwitcherModule(), ClipboardModule(), WindowLayoutModule(), SystemMonitorModule(), ClaudeAccountsModule()]
        bridge.modules = modules.map {
            ModuleInfo(id: $0.identifier, title: $0.title, summary: $0.summary, symbolName: $0.symbolName, requiresAccessibility: $0.requiresAccessibility)
        }
        bridge.isAccessibilityTrusted = true
        bridge.clipboardStats = ClipboardStats(itemCount: 38, imageCount: 6, imageBytes: 4_800_000)
        bridge.claudeAccounts = samples.accounts
        func item(_ id: String, _ title: String, system: String? = nil, icon: NSImage? = nil, movable: Bool = true) -> MenuBarLayoutItem {
            MenuBarLayoutItem(id: id, title: title, label: title, icon: icon, systemIdentifier: system, isMovable: movable, isBehindNotch: false)
        }
        bridge.menuBarLayout = MenuBarLayout(
            visible: [
                item("weather", samples.text("Tempo", "Weather"), icon: samples.icon("/System/Applications/Weather.app")),
                item("now-playing", samples.text("Tocando agora", "Now Playing"), system: "com.apple.menuextra.now-playing"),
                item("bluetooth", "Bluetooth", system: "com.apple.menuextra.bluetooth"),
                item("wifi", "Wi‑Fi", system: "com.apple.menuextra.wifi"),
                item("battery", samples.text("Bateria", "Battery"), system: "com.apple.menuextra.battery"),
                item("control-center", samples.text("Central de Controle", "Control Center"), system: "com.apple.menuextra.controlcenter", movable: false),
                item("clock", samples.text("Relógio", "Clock"), system: "com.apple.menuextra.clock", movable: false)
            ],
            hidden: [
                item("music", samples.text("Música", "Music"), icon: samples.icon("/System/Applications/Music.app")),
                item("reminders", samples.text("Lembretes", "Reminders"), icon: samples.icon("/System/Applications/Reminders.app")),
                item("photos", samples.text("Fotos", "Photos"), icon: samples.icon("/System/Applications/Photos.app")),
                item("shortcuts", samples.text("Atalhos", "Shortcuts"), icon: samples.icon("/System/Applications/Shortcuts.app")),
                item("home", samples.text("Casa", "Home"), icon: samples.icon("/System/Applications/Home.app"))
            ]
        )
        return bridge
    }

    private static func sampleScreenshotPNG() -> Data? {
        let size = NSSize(width: 640, height: 400)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor(srgbRed: 0.36, green: 0.42, blue: 0.62, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        let window = NSRect(x: 60, y: 50, width: 520, height: 300)
        NSColor(white: 0.97, alpha: 1).setFill()
        NSBezierPath(roundedRect: window, xRadius: 14, yRadius: 14).fill()
        NSColor(white: 0.88, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: window.minX, y: window.maxY - 34, width: window.width, height: 34), xRadius: 14, yRadius: 14).fill()
        for (index, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: window.minX + 16 + CGFloat(index) * 20, y: window.maxY - 23, width: 12, height: 12)).fill()
        }
        let bars: [(CGFloat, NSColor)] = [(0.8, .systemBlue), (0.55, .systemGray), (0.7, .systemGray), (0.4, .systemOrange), (0.62, .systemGray)]
        for (index, bar) in bars.enumerated() {
            bar.1.withAlphaComponent(0.75).setFill()
            NSBezierPath(roundedRect: NSRect(x: window.minX + 28, y: window.maxY - 72 - CGFloat(index) * 42, width: (window.width - 56) * bar.0, height: 18), xRadius: 6, yRadius: 6).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func snapshot(appKit view: NSView, drawsHierarchy: Bool = false) -> Data? {
        let window = offscreenWindow(size: view.frame.size)
        window.contentView = view
        view.frame = NSRect(origin: .zero, size: window.frame.size)
        settle()
        view.layoutSubtreeIfNeeded()
        view.display()
        guard drawsHierarchy else { return pngFromLayers(view) }
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func snapshot<Content: View>(swiftUI view: Content, size: NSSize, trimsBottom: Bool) -> Data? {
        let hostingView = NSHostingView(rootView: view.frame(width: size.width, height: size.height).background(Color(nsColor: .windowBackgroundColor)))
        hostingView.frame = NSRect(origin: .zero, size: size)
        let window = offscreenWindow(size: size)
        window.contentView = hostingView
        settle()
        hostingView.layoutSubtreeIfNeeded()
        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else { return nil }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        guard var image = bitmap.cgImage else { return nil }
        if trimsBottom, let trimmed = trimmingBottom(image) {
            image = trimmed
        }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    private static func offscreenWindow(size: NSSize) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -20_000, y: -20_000), size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        return window
    }

    private static func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
    }

    private static func pngFromLayers(_ view: NSView) -> Data? {
        let size = view.bounds.size
        let width = Int((size.width * scale).rounded())
        let height = Int((size.height * scale).rounded())
        guard let layer = view.layer,
              let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            layer.render(in: context)
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let image = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    private static func trimmingBottom(_ image: CGImage) -> CGImage? {
        guard let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return nil }
        let bytesPerRow = image.bytesPerRow
        let bytesPerPixel = image.bitsPerPixel / 8
        let width = image.width
        func pixel(_ x: Int, _ y: Int) -> (Int, Int, Int) {
            let offset = y * bytesPerRow + x * bytesPerPixel
            return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]))
        }
        let background = pixel(width - 4, image.height - 4)
        var lastContentRow = 0
        for row in stride(from: image.height - 1, through: 0, by: -1) {
            let differs = stride(from: 0, to: width, by: 3).contains { x in
                let value = pixel(x, row)
                return abs(value.0 - background.0) + abs(value.1 - background.1) + abs(value.2 - background.2) > 24
            }
            if differs {
                lastContentRow = row
                break
            }
        }
        let height = min(image.height, lastContentRow + Int(28 * scale))
        return image.cropping(to: CGRect(x: 0, y: 0, width: width, height: height))
    }
}
