import AppKit

enum PanelSections {
    static let width: CGFloat = 300

    static func header(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        return label
    }

    static func claude(
        accounts: [ClaudeAccountSummary],
        onUse: @escaping (String) -> Void,
        onOpenTerminal: @escaping (String) -> Void
    ) -> NSView {
        let stack = verticalStack()
        stack.addArrangedSubview(header("Claude"))
        for account in accounts {
            let name = account.account
            let row = HoverRow { onUse(name) }
            row.toolTip = account.active ? String(localized: "Conta ativa") : String(localized: "Usar esta conta")

            let badge = NSImageView(image: AccountBadge.image(for: name, diameter: 18))
            badge.translatesAutoresizingMaskIntoConstraints = false
            badge.widthAnchor.constraint(equalToConstant: 18).isActive = true

            let title = NSTextField(labelWithString: account.shortName)
            title.font = .systemFont(ofSize: 13, weight: account.active ? .semibold : .regular)
            let subtitle = NSTextField(labelWithString: usageLine(account))
            subtitle.font = .systemFont(ofSize: 11)
            subtitle.textColor = .secondaryLabelColor
            subtitle.lineBreakMode = .byTruncatingTail
            let texts = verticalStack(spacing: 1)
            texts.addArrangedSubview(title)
            texts.addArrangedSubview(subtitle)

            let checkmark = NSImageView(image: NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil) ?? NSImage())
            checkmark.contentTintColor = .controlAccentColor
            checkmark.isHidden = !account.active

            let content = NSStackView(views: [badge, texts, NSView(), checkmark])
            content.orientation = .horizontal
            content.spacing = 8
            if account.email != nil {
                let terminal = SmallIconButton(symbolName: "terminal", toolTip: String(localized: "Abrir terminal com esta conta")) {
                    onOpenTerminal(name)
                }
                content.addArrangedSubview(terminal)
            }
            row.setContent(content)
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    static func update(state: UpdateState, onInstall: @escaping () -> Void) -> NSView? {
        let release: UpdateRelease
        let status: String
        let isActionable: Bool
        switch state {
        case .available(let available):
            release = available
            status = available.notes.first ?? String(localized: "Você está na \(AppUpdater.currentVersion).")
            isActionable = true
        case .downloading(let downloading):
            release = downloading
            status = String(localized: "Baixando…")
            isActionable = false
        case .installing(let installing):
            release = installing
            status = String(localized: "Instalando e reabrindo…")
            isActionable = false
        default:
            return nil
        }
        let stack = verticalStack()
        stack.addArrangedSubview(header(String(localized: "Atualização")))
        let row = HoverRow { if isActionable { onInstall() } }
        row.toolTip = isActionable ? String(localized: "Baixar, instalar e reabrir o Toolbelt") : nil

        let icon = NSImageView(image: NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = .controlAccentColor
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)

        let title = NSTextField(labelWithString: String(localized: "Toolbelt \(release.version) disponível"))
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        let subtitle = NSTextField(labelWithString: status)
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail
        let texts = verticalStack(spacing: 1)
        texts.addArrangedSubview(title)
        texts.addArrangedSubview(subtitle)

        let content = NSStackView(views: [icon, texts, NSView()])
        content.orientation = .horizontal
        content.spacing = 8
        if isActionable {
            content.addArrangedSubview(TextActionButton(title: String(localized: "Atualizar"), handler: onInstall))
        } else {
            let spinner = NSProgressIndicator()
            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.startAnimation(nil)
            content.addArrangedSubview(spinner)
        }
        row.setContent(content)
        stack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stack.widthAnchor.constraint(greaterThanOrEqualToConstant: width).isActive = true
        return stack
    }

    static func crash(pending: [PendingCrash], onSend: @escaping () -> Void, onAlways: @escaping () -> Void, onDismiss: @escaping () -> Void) -> NSView? {
        guard !pending.isEmpty else { return nil }
        let stack = verticalStack()
        stack.addArrangedSubview(header(String(localized: "Relatório de falha")))

        let icon = NSImageView(image: NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = .systemOrange
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let onlyHangs = pending.allSatisfy { $0.kind == .hang }
        let headline = pending.count > 1
            ? String(localized: "\(pending.count) falhas desde a última vez")
            : (onlyHangs ? String(localized: "O Toolbelt travou") : String(localized: "O Toolbelt fechou inesperadamente"))
        let title = NSTextField(labelWithString: headline)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        let subtitle = NSTextField(wrappingLabelWithString: String(localized: "Enviar o relatório ajuda a corrigir. Vai só o técnico: versão, macOS e onde falhou."))
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.preferredMaxLayoutWidth = width - 30
        let texts = verticalStack(spacing: 1)
        texts.addArrangedSubview(title)
        texts.addArrangedSubview(subtitle)
        let line = NSStackView(views: [icon, texts])
        line.orientation = .horizontal
        line.alignment = .top
        line.spacing = 8
        stack.addArrangedSubview(line)

        let buttons = NSStackView(views: [
            TextActionButton(title: String(localized: "Enviar"), handler: onSend),
            TextActionButton(title: String(localized: "Sempre enviar"), isProminent: false, handler: onAlways),
            TextActionButton(title: String(localized: "Agora não"), isProminent: false, handler: onDismiss)
        ])
        buttons.orientation = .horizontal
        buttons.spacing = 6
        stack.addArrangedSubview(buttons)
        stack.widthAnchor.constraint(greaterThanOrEqualToConstant: width).isActive = true
        return stack
    }

    static func system(snapshot: SystemSnapshot, onOpenReport: @escaping () -> Void) -> NSView {
        let stack = verticalStack()
        stack.addArrangedSubview(header(String(localized: "Sistema")))

        let memoryRatio = snapshot.memoryUsedRatio
        stack.addArrangedSubview(meterRow(
            title: String(localized: "Memória"),
            value: String(localized: "\(ByteFormat.memory(snapshot.memoryUsed)) de \(ByteFormat.memory(snapshot.memoryTotal))"),
            ratio: memoryRatio,
            color: snapshot.pressureLevel >= 4 ? .systemRed : (snapshot.pressureLevel >= 2 ? .systemOrange : .controlAccentColor)
        ))
        let swap = NSTextField(labelWithString: String(localized: "Swap \(ByteFormat.memory(snapshot.swapUsed)) · pressão \(snapshot.pressureTitle)"))
        swap.font = .systemFont(ofSize: 11)
        swap.textColor = .secondaryLabelColor
        stack.addArrangedSubview(swap)

        let diskUsed = 1 - snapshot.diskFreeRatio
        stack.addArrangedSubview(meterRow(
            title: String(localized: "Disco"),
            value: String(localized: "\(ByteFormat.storage(snapshot.diskFree)) livres"),
            ratio: diskUsed,
            color: snapshot.diskFreeRatio < 0.05 ? .systemRed : (snapshot.diskFreeRatio < 0.1 ? .systemOrange : .controlAccentColor)
        ))

        let report = HoverRow(handler: onOpenReport)
        let label = NSTextField(labelWithString: String(localized: "Relatório completo (macscan)…"))
        label.font = .systemFont(ofSize: 12)
        let icon = NSImageView(image: NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: nil) ?? NSImage())
        let content = NSStackView(views: [icon, label, NSView()])
        content.orientation = .horizontal
        content.spacing = 6
        report.setContent(content)
        stack.addArrangedSubview(report)
        report.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private static func meterRow(title: String, value: String, ratio: Double, color: NSColor) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        let valueLabel = NSTextField(labelWithString: "\(value) · \(Int((ratio * 100).rounded()))%")
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        let line = NSStackView(views: [titleLabel, NSView(), valueLabel])
        line.orientation = .horizontal

        let meter = MeterView(ratio: ratio, color: color)
        meter.translatesAutoresizingMaskIntoConstraints = false
        meter.heightAnchor.constraint(equalToConstant: 5).isActive = true

        let stack = verticalStack(spacing: 3)
        stack.addArrangedSubview(line)
        stack.addArrangedSubview(meter)
        line.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        meter.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stack.widthAnchor.constraint(equalToConstant: width).isActive = true
        return stack
    }

    private static func usageLine(_ account: ClaudeAccountSummary) -> String {
        guard let email = account.email else { return String(localized: "sem login") }
        let fiveHour = account.fiveHour.currentPercent.map { "\($0)%" } ?? "?"
        let sevenDay = account.sevenDay.currentPercent.map { "\($0)%" } ?? "?"
        return String(localized: "\(email) · 5h \(fiveHour) · sem. \(sevenDay)")
    }

    private static func verticalStack(spacing: CGFloat = 4) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }
}

private final class MeterView: NSView {
    private let ratio: Double
    private let color: NSColor

    init(ratio: Double, color: NSColor) {
        self.ratio = min(max(ratio, 0), 1)
        self.color = color
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_ dirtyRect: NSRect) {
        let radius = bounds.height / 2
        NSColor.labelColor.withAlphaComponent(0.12).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
        color.setFill()
        let filled = NSRect(x: 0, y: 0, width: max(bounds.width * ratio, bounds.height), height: bounds.height)
        NSBezierPath(roundedRect: filled, xRadius: radius, yRadius: radius).fill()
    }
}

final class HoverRow: NSView {
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setContent(_ content: NSView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            content.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = nil
    }

    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            handler()
        }
    }
}

final class TextActionButton: NSButton {
    private let handler: () -> Void

    init(title: String, isProminent: Bool = true, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        self.title = title
        bezelStyle = .push
        controlSize = .small
        if isProminent {
            bezelColor = .controlAccentColor
        }
        target = self
        action = #selector(runHandler)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func runHandler() {
        handler()
    }
}

final class SmallIconButton: NSButton {
    private let handler: () -> Void

    init(symbolName: String, toolTip: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: toolTip)
        self.toolTip = toolTip
        isBordered = false
        imagePosition = .imageOnly
        contentTintColor = .secondaryLabelColor
        target = self
        action = #selector(runHandler)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func runHandler() {
        handler()
    }
}
