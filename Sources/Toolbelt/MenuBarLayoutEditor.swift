import SwiftUI

struct MenuBarLayoutEditor: View {
    @ObservedObject var bridge: SettingsBridge

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if bridge.menuBarLayout.isEmpty {
                Text("Lendo os ícones da barra…")
                    .foregroundStyle(.secondary)
            } else {
                MenuBarLayoutRow(
                    title: "Na barra",
                    symbolName: "menubar.rectangle",
                    items: bridge.menuBarLayout.visible,
                    endTarget: .endOfVisible,
                    onDrop: bridge.requestMenuBarMove
                )
                MenuBarLayoutRow(
                    title: "Escondidos no cinto",
                    symbolName: "eye.slash",
                    items: bridge.menuBarLayout.hidden,
                    endTarget: .endOfHidden,
                    onDrop: bridge.requestMenuBarMove
                )
            }
            status
        }
        .disabled(bridge.isMovingMenuBarItem)
        .animation(.easeOut(duration: 0.15), value: bridge.menuBarLayout)
    }

    @ViewBuilder
    private var status: some View {
        if bridge.isMovingMenuBarItem {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Movendo na barra… não mexa no mouse por um instante.")
            }
            .font(.callout)
        } else if let outcome = bridge.menuBarMoveOutcome {
            Label(outcome.message, systemImage: outcome.isFailure ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(outcome.isFailure ? Color.orange : Color.green)
        }
    }
}

private struct MenuBarLayoutRow: View {
    let title: String
    let symbolName: String
    let items: [MenuBarLayoutItem]
    let endTarget: MenuBarLayoutTarget
    let onDrop: (String, MenuBarLayoutTarget) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(items) { item in
                    MenuBarChip(item: item) { identifier in
                        onDrop(identifier, .before(item.id))
                    }
                }
                if items.isEmpty {
                    Text("Arraste ícones para cá")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 5)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(isTargeted ? 0.08 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isTargeted ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isTargeted ? 2 : 1)
            )
            .dropDestination(for: String.self) { identifiers, _ in
                guard let identifier = identifiers.first else { return false }
                onDrop(identifier, endTarget)
                return true
            } isTargeted: { isTargeted = $0 }
        }
    }
}

private struct MenuBarChip: View {
    let item: MenuBarLayoutItem
    let onDropBefore: (String) -> Void

    @State private var isTargeted = false

    var body: some View {
        draggableChip
            .dropDestination(for: String.self) { identifiers, _ in
                guard let identifier = identifiers.first, identifier != item.id else { return false }
                onDropBefore(identifier)
                return true
            } isTargeted: { isTargeted = $0 }
    }

    @ViewBuilder
    private var draggableChip: some View {
        if item.isMovable {
            chip.draggable(item.id) { chip }
        } else {
            chip
        }
    }

    private var chip: some View {
        HStack(spacing: 5) {
            icon
                .frame(width: 16, height: 16)
            Text(item.title)
                .lineLimit(1)
            if item.isBehindNotch {
                Image(systemName: "eye.slash")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            if !item.isMovable {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.callout)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.12), radius: 0.5, y: 0.5)
        )
        .overlay(alignment: .leading) {
            if isTargeted {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .padding(.vertical, 2)
                    .offset(x: -5)
            }
        }
        .help(helpText)
    }

    @ViewBuilder
    private var icon: some View {
        if let symbolName = MenuBarChip.symbolName(for: item.systemIdentifier) {
            Image(systemName: symbolName)
                .imageScale(.small)
        } else if let image = item.icon {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "app")
        }
    }

    private var helpText: String {
        if !item.isMovable {
            return "\(item.label): o macOS deixa esse ícone fixo no fim da barra"
        }
        if item.isBehindNotch {
            return "\(item.label): está na barra, mas atrás do notch, então não aparece"
        }
        return item.label
    }

    private static let systemSymbols: [String: String] = [
        "wifi": "wifi",
        "battery": "battery.75percent",
        "bluetooth": "antenna.radiowaves.left.and.right",
        "now-playing": "play.circle",
        "controlcenter": "switch.2",
        "clock": "clock",
        "sound": "speaker.wave.2",
        "volume": "speaker.wave.2",
        "focusmodes": "moon",
        "display": "sun.max",
        "screenmirroring": "rectangle.on.rectangle",
        "keyboardbrightness": "light.max",
        "airdrop": "dot.radiowaves.up.forward",
        "user": "person.crop.circle",
        "spotlight": "magnifyingglass",
        "siri": "mic",
        "textinput": "keyboard",
        "timemachine": "clock.arrow.circlepath",
        "vpn": "network.badge.shield.half.filled",
        "accessibility": "accessibility",
        "hearing": "ear",
        "stagemanager": "rectangle.3.group"
    ]

    static func symbolName(for systemIdentifier: String?) -> String? {
        guard let systemIdentifier, systemIdentifier.hasPrefix("com.apple.menuextra.") else { return nil }
        let key = String(systemIdentifier.dropFirst("com.apple.menuextra.".count))
        return systemSymbols[key] ?? "circle.dashed"
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maximumWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maximumWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
