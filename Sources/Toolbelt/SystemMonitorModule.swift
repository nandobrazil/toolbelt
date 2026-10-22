import AppKit
import UserNotifications

final class SystemMonitorModule: NSObject, ToolbeltModule, NSMenuDelegate {
    let identifier = "systemMonitor"
    let title = "Monitor do sistema"
    let summary = "RAM, swap e disco na barra, alertas quando apertar e o relatório completo do macscan."
    let symbolName = "gauge.with.dots.needle.33percent"

    private enum Alert: String {
        case disk
        case swap
        case pressure
    }

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var sampleTimer: Timer?
    private var activeAlerts: Set<Alert> = []
    private(set) var snapshot = SystemSnapshot()
    private var registeredSettings: SystemMonitorSettings?
    var onOpenReport: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    private var settings: SystemMonitorSettings { AppSettings.shared.values.systemMonitor }

    func start() {
        applySettings()
    }

    func stop() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        removeStatusItem()
        registeredSettings = nil
        activeAlerts.removeAll()
    }

    func settingsDidChange() {
        applySettings()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        sample()
        rebuildMenu()
    }

    private func applySettings() {
        let current = settings
        guard current != registeredSettings else { return }
        let intervalChanged = current.refreshSeconds != registeredSettings?.refreshSeconds
        registeredSettings = current
        if current.showInMenuBar {
            createStatusItemIfNeeded()
        } else {
            removeStatusItem()
        }
        if current.alertsEnabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        if intervalChanged || sampleTimer == nil {
            sampleTimer?.invalidate()
            sampleTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(max(current.refreshSeconds, 5)), repeats: true) { [weak self] _ in
                self?.sample()
            }
            sampleTimer?.tolerance = TimeInterval(current.refreshSeconds) / 2
        }
        sample()
    }

    private func createStatusItemIfNeeded() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "toolbelt.system"
        item.button?.imagePosition = .imageLeading
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    private func removeStatusItem() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    private func sample() {
        snapshot = SystemMetrics.snapshot()
        updateTitle()
        evaluateAlerts()
    }

    private var warningLevel: Int {
        let current = settings
        if snapshot.pressureLevel >= 4 || snapshot.diskFreeRatio < 0.05 {
            return 2
        }
        let swapLimit = UInt64(current.swapWarningGigabytes) * 1_073_741_824
        if snapshot.pressureLevel >= 2
            || snapshot.diskFreeRatio * 100 < Double(current.diskWarningPercent)
            || snapshot.swapUsed >= swapLimit {
            return 1
        }
        return 0
    }

    private func updateTitle() {
        guard let button = statusItem?.button else { return }
        let current = settings
        var parts: [String] = []
        if current.showsMemory {
            parts.append("\(Int((snapshot.memoryUsedRatio * 100).rounded()))%")
        }
        if current.showsSwap {
            parts.append("swap \(ByteFormat.memory(snapshot.swapUsed))")
        }
        if current.showsDisk {
            parts.append(ByteFormat.storage(snapshot.diskFree))
        }
        let color: NSColor
        switch warningLevel {
        case 2: color = .systemRed
        case 1: color = .systemOrange
        default: color = .labelColor
        }
        let symbol = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "Monitor do sistema")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .medium))
        if warningLevel > 0 {
            button.image = symbol?.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [color]))
        } else {
            symbol?.isTemplate = true
            button.image = symbol
        }
        let text = parts.isEmpty ? "" : " " + parts.joined(separator: " · ")
        button.attributedTitle = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            ]
        )
        button.toolTip = "RAM \(ByteFormat.memory(snapshot.memoryUsed)) de \(ByteFormat.memory(snapshot.memoryTotal)) · disco livre \(ByteFormat.storage(snapshot.diskFree))"
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        menu.addItem(sectionHeader("Memória"))
        menu.addItem(disabledMenuItem("Em uso \(ByteFormat.memory(snapshot.memoryUsed)) de \(ByteFormat.memory(snapshot.memoryTotal)) (\(Int((snapshot.memoryUsedRatio * 100).rounded()))%)"))
        menu.addItem(disabledMenuItem("     apps \(ByteFormat.memory(snapshot.memoryApp)) · fixa \(ByteFormat.memory(snapshot.memoryWired)) · comprimida \(ByteFormat.memory(snapshot.memoryCompressed))"))
        menu.addItem(disabledMenuItem("     cache \(ByteFormat.memory(snapshot.memoryCached)) (liberado quando faltar)"))
        menu.addItem(disabledMenuItem("Pressão \(snapshot.pressureTitle)"))
        menu.addItem(disabledMenuItem("Swap \(ByteFormat.memory(snapshot.swapUsed)) de \(ByteFormat.memory(snapshot.swapTotal))"))
        menu.addItem(.separator())
        menu.addItem(sectionHeader("Disco"))
        menu.addItem(disabledMenuItem("Livre \(ByteFormat.storage(snapshot.diskFree)) de \(ByteFormat.storage(snapshot.diskTotal)) (\(Int((snapshot.diskFreeRatio * 100).rounded()))%)"))
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(title: "Relatório completo (macscan)…") { [weak self] in
            self?.onOpenReport?()
        })
        menu.addItem(ActionMenuItem(title: "Abrir o Monitor de Atividade") {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
        })
        menu.addItem(ActionMenuItem(title: "Configurar…") { [weak self] in
            self?.onOpenSettings?()
        })
    }

    private func evaluateAlerts() {
        let current = settings
        guard current.alertsEnabled else {
            activeAlerts.removeAll()
            return
        }
        let diskPercent = snapshot.diskFreeRatio * 100
        let swapLimit = UInt64(current.swapWarningGigabytes) * 1_073_741_824
        update(
            .disk,
            isActive: diskPercent < Double(current.diskWarningPercent),
            isCleared: diskPercent >= Double(current.diskWarningPercent) + 2,
            message: "Disco quase cheio: \(ByteFormat.storage(snapshot.diskFree)) livres (\(Int(diskPercent.rounded()))%)."
        )
        update(
            .swap,
            isActive: snapshot.swapUsed >= swapLimit,
            isCleared: snapshot.swapUsed < swapLimit * 3 / 4,
            message: "Swap alta: \(ByteFormat.memory(snapshot.swapUsed)) em uso. Fechar apps pesados ou reiniciar libera."
        )
        update(
            .pressure,
            isActive: snapshot.pressureLevel >= 2,
            isCleared: snapshot.pressureLevel < 2,
            message: "Memória sob pressão \(snapshot.pressureTitle)."
        )
    }

    private func update(_ alert: Alert, isActive: Bool, isCleared: Bool, message: String) {
        if isActive && !activeAlerts.contains(alert) {
            activeAlerts.insert(alert)
            notify(message, identifier: alert.rawValue)
        } else if isCleared {
            activeAlerts.remove(alert)
        }
    }

    private func notify(_ message: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "Toolbelt"
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(identifier: "toolbelt.system.\(identifier)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("Toolbelt: notification failed: \(error.localizedDescription)")
            }
        }
    }
}
