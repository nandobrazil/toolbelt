import AppKit
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case menuBar
    case clipboard
    case windows
    case claude
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "Geral"
        case .menuBar: return "Barra de menus"
        case .clipboard: return "Área de transferência"
        case .windows: return "Janelas"
        case .claude: return "Contas do Claude"
        case .about: return "Sobre"
        }
    }

    var symbolName: String {
        switch self {
        case .general: return "gearshape"
        case .menuBar: return "menubar.arrow.up.rectangle"
        case .clipboard: return "doc.on.clipboard"
        case .windows: return "rectangle.split.2x1"
        case .claude: return "person.2.circle"
        case .about: return "info.circle"
        }
    }

    var moduleIdentifier: String? {
        switch self {
        case .menuBar: return "menuBarOverflow"
        case .clipboard: return "clipboard"
        case .windows: return "windowLayout"
        case .claude: return "claudeAccounts"
        case .general, .about: return nil
        }
    }
}

struct ModuleInfo: Identifiable {
    let id: String
    let title: String
    let summary: String
    let symbolName: String
    let requiresAccessibility: Bool
}

struct ClipboardStats {
    var itemCount = 0
    var imageCount = 0
    var imageBytes = 0
}

final class SettingsBridge: ObservableObject {
    @Published var selection: SettingsSection = .general
    @Published var clipboardStats = ClipboardStats()
    @Published var claudeEmails: [String: String] = [:]
    @Published var isAccessibilityTrusted = AccessibilityPermission.isTrusted

    var modules: [ModuleInfo] = []
    var loadClipboardStats: () -> ClipboardStats = { ClipboardStats() }
    var loadClaudeEmails: () -> [String: String] = { [:] }
    var clearClipboardHistory: () -> Void = {}
    var arrangeMenuBar: () -> Void = {}
    var loginClaude: (String) -> Void = { _ in }

    func refresh() {
        clipboardStats = loadClipboardStats()
        claudeEmails = loadClaudeEmails()
        isAccessibilityTrusted = AccessibilityPermission.isTrusted
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var bridge: SettingsBridge

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $bridge.selection) { section in
                Label(section.title, systemImage: section.symbolName)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 200, max: 240)
        } detail: {
            detail
                .navigationTitle(bridge.selection.title)
        }
        .frame(minWidth: 720, minHeight: 500)
        .onAppear(perform: bridge.refresh)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            bridge.refresh()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch bridge.selection {
        case .general: GeneralSettingsPage(settings: settings, bridge: bridge)
        case .menuBar: MenuBarSettingsPage(settings: settings, bridge: bridge)
        case .clipboard: ClipboardSettingsPage(settings: settings, bridge: bridge)
        case .windows: WindowSettingsPage(settings: settings)
        case .claude: ClaudeSettingsPage(settings: settings, bridge: bridge)
        case .about: AboutPage()
        }
    }
}

private struct ModuleToggleSection: View {
    @ObservedObject var settings: AppSettings
    let section: SettingsSection
    let summary: String

    var body: some View {
        if let identifier = section.moduleIdentifier {
            Section {
                Toggle(isOn: Binding(
                    get: { settings.isModuleEnabled(identifier) },
                    set: { settings.setModule(identifier, enabled: $0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ativar \(section.title.lowercased())")
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
        }
    }
}

private struct GeneralSettingsPage: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var bridge: SettingsBridge
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("Inicialização") {
                Toggle("Abrir o Toolbelt ao iniciar o Mac", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LaunchAtLogin.setEnabled(enabled)
                    }
            }

            Section("Módulos") {
                ForEach(bridge.modules) { module in
                    Toggle(isOn: Binding(
                        get: { settings.isModuleEnabled(module.id) },
                        set: { settings.setModule(module.id, enabled: $0) }
                    )) {
                        HStack(spacing: 10) {
                            Image(systemName: module.symbolName)
                                .frame(width: 22)
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(module.title)
                                Text(module.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .toggleStyle(.switch)
                }
            }

            Section {
                HStack {
                    Label("Acessibilidade", systemImage: "hand.raised")
                    Spacer()
                    if bridge.isAccessibilityTrusted {
                        Label("Permitida", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Necessária", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Button("Abrir Ajustes…") {
                            AccessibilityPermission.requestIfNeeded()
                            AccessibilityPermission.openSettings()
                        }
                    }
                }
            } header: {
                Text("Permissões")
            } footer: {
                Text("Usada para colar automaticamente, mover janelas e abrir os ícones escondidos da barra.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct MenuBarSettingsPage: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var bridge: SettingsBridge

    var body: some View {
        Form {
            ModuleToggleSection(settings: settings, section: .menuBar, summary: "Esconde ícones da barra e mostra todos num painel abaixo da setinha.")

            Section("Aparência") {
                Picker("Ícone do Toolbelt", selection: $settings.values.menuBar.iconStyle) {
                    ForEach(ChevronStyle.allCases) { style in
                        Label(style.title, systemImage: style.symbolName(isOpen: false))
                            .tag(style)
                    }
                }
                Stepper(
                    "Ícones por linha no painel: \(settings.values.menuBar.panelColumns)",
                    value: $settings.values.menuBar.panelColumns,
                    in: 4...16
                )
            }

            Section {
                Stepper(
                    "Duração do modo organizar: \(settings.values.menuBar.arrangeModeSeconds) s",
                    value: $settings.values.menuBar.arrangeModeSeconds,
                    in: 10...120,
                    step: 5
                )
                Button("Organizar a barra agora") {
                    bridge.arrangeMenuBar()
                }
                .disabled(!settings.isModuleEnabled("menuBarOverflow"))
            } header: {
                Text("Organizar")
            } footer: {
                Text("No modo organizar a barra aparece inteira com o traço ┊. Segure ⌘ e arraste para a esquerda do traço os ícones que devem ficar escondidos.")
            }

            Section("Como usar") {
                InstructionRow(symbol: "cursorarrow.click", text: "Clique no ícone do Toolbelt para abrir o painel com os ícones escondidos.")
                InstructionRow(symbol: "option", text: "⌥ clique no ícone liga e desliga o modo organizar.")
                InstructionRow(symbol: "contextualmenu.and.cursorarrow", text: "Clique direito mostra o menu rápido dos módulos.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct ClipboardSettingsPage: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var bridge: SettingsBridge

    var body: some View {
        Form {
            ModuleToggleSection(settings: settings, section: .clipboard, summary: "Histórico de textos, imagens e prints, com atalho para colar.")

            Section("Atalho e painel") {
                LabeledContent("Abrir o histórico") {
                    ShortcutRecorder(
                        combo: $settings.values.clipboard.activeShortcut,
                        defaultCombo: ClipboardSettings.defaultShortcut
                    )
                }
                Picker("Onde o painel abre", selection: $settings.values.clipboard.pickerPosition) {
                    ForEach(PickerPosition.allCases) { position in
                        Text(position.title).tag(position)
                    }
                }
                Toggle("Colar automaticamente ao escolher um item", isOn: $settings.values.clipboard.pasteAutomatically)
                    .toggleStyle(.switch)
            }

            Section {
                Stepper(
                    "Guardar até \(settings.values.clipboard.historyLimit) itens",
                    value: $settings.values.clipboard.historyLimit,
                    in: 10...200,
                    step: 10
                )
                Stepper(
                    "Dos quais até \(settings.values.clipboard.imageLimit) imagens",
                    value: $settings.values.clipboard.imageLimit,
                    in: 0...100,
                    step: 5
                )
                Toggle("Guardar imagens copiadas", isOn: $settings.values.clipboard.captureCopiedImages)
                    .toggleStyle(.switch)
                Toggle("Guardar prints salvos em arquivo (⌘⇧3, ⌘⇧4, ⌘⇧5)", isOn: $settings.values.clipboard.captureScreenshots)
                    .toggleStyle(.switch)
                LabeledContent("Em uso") {
                    Text("\(bridge.clipboardStats.itemCount) itens · \(bridge.clipboardStats.imageCount) imagens · \(ByteCountFormatter.string(fromByteCount: Int64(bridge.clipboardStats.imageBytes), countStyle: .file))")
                        .foregroundStyle(.secondary)
                }
                Button("Limpar histórico", role: .destructive) {
                    bridge.clearClipboardHistory()
                    bridge.refresh()
                }
            } header: {
                Text("Histórico")
            } footer: {
                Text("Cada print ocupa alguns MB. Senhas copiadas de gerenciadores como 1Password e Bitwarden nunca entram no histórico.")
            }

            IgnoredApplicationsSection(identifiers: $settings.values.clipboard.ignoredBundleIdentifiers)
        }
        .formStyle(.grouped)
    }
}

private struct IgnoredApplicationsSection: View {
    @Binding var identifiers: [String]

    var body: some View {
        Section {
            if identifiers.isEmpty {
                Text("Nenhum app ignorado")
                    .foregroundStyle(.secondary)
            }
            ForEach(identifiers, id: \.self) { identifier in
                HStack {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .frame(width: 18, height: 18)
                        Text(FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""))
                    } else {
                        Image(systemName: "app.dashed")
                        Text(identifier)
                    }
                    Spacer()
                    Button {
                        identifiers.removeAll { $0 == identifier }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            Button("Adicionar app…", action: addApplication)
        } header: {
            Text("Não guardar o que for copiado em")
        } footer: {
            Text("Útil para bancos, gerenciadores de senha sem marcação e apps com dados sensíveis.")
        }
    }

    private func addApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let identifier = Bundle(url: url)?.bundleIdentifier, !identifiers.contains(identifier) else { continue }
            identifiers.append(identifier)
        }
    }
}

private struct WindowSettingsPage: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            ModuleToggleSection(settings: settings, section: .windows, summary: "Atalhos de teclado para metades, terços, cantos e monitores.")

            Section("Espaçamento") {
                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(settings.values.windows.gap) },
                            set: { settings.values.windows.gap = Int($0.rounded()) }
                        ),
                        in: 0...40,
                        step: 2
                    ) {
                        Text("Espaço entre janelas")
                    }
                    Text("\(settings.values.windows.gap) px")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(WindowLayout.allCases) { layout in
                    LabeledContent(layout.title) {
                        ShortcutRecorder(
                            combo: Binding(
                                get: { settings.values.windows.shortcut(for: layout) },
                                set: { settings.values.windows.setShortcut($0, for: layout) }
                            ),
                            defaultCombo: layout.defaultCombo
                        )
                    }
                }
                Button("Restaurar todos os atalhos padrão") {
                    settings.values.windows.shortcutOverrides = [:]
                    settings.values.windows.disabledLayouts = []
                }
            } header: {
                Text("Atalhos")
            } footer: {
                Text("Clique num atalho e digite a nova combinação. ⌫ desativa, ⎋ cancela.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct ClaudeSettingsPage: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var bridge: SettingsBridge

    var body: some View {
        Form {
            ModuleToggleSection(settings: settings, section: .claude, summary: "Alterna entre duas contas do Claude Code e mostra o uso de cada uma.")

            Section("Barra de menus") {
                Toggle("Mostrar o uso das últimas 5 h no ícone", isOn: $settings.values.claude.showUsageInTitle)
                    .toggleStyle(.switch)
            }

            Section {
                ForEach(["a", "b"], id: \.self) { account in
                    LabeledContent("Conta \(account.uppercased())") {
                        HStack {
                            TextField("Nome", text: Binding(
                                get: { settings.values.claude.accountNames[account] ?? "" },
                                set: { settings.values.claude.accountNames[account] = $0 }
                            ), prompt: Text("Conta \(account.uppercased())"))
                            .frame(width: 140)
                            let email = bridge.claudeEmails[account] ?? ""
                            if email.isEmpty {
                                Button("Entrar…") {
                                    bridge.loginClaude(account)
                                }
                            } else {
                                Text(email)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            } header: {
                Text("Contas")
            } footer: {
                Text("O nome aparece no ícone e no menu. No terminal: cca use a|b, cca swap e cca resume.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutPage: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 54))
                .foregroundStyle(Color.accentColor)
            Text("Toolbelt")
                .font(.largeTitle.bold())
            Text("Versão \(version)")
                .foregroundStyle(.secondary)
            HStack {
                Link("Repositório no GitHub", destination: URL(string: "https://github.com/nandobrazil/toolbelt")!)
                Text("·").foregroundStyle(.tertiary)
                Button("Abrir log") {
                    let log = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Toolbelt.log")
                    NSWorkspace.shared.open(log)
                }
                .buttonStyle(.link)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct InstructionRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 22)
                .foregroundStyle(.secondary)
            Text(text)
        }
    }
}
