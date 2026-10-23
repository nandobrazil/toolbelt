import AppKit
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case menuBar
    case switcher
    case clipboard
    case windows
    case system
    case claude
    case support
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return String(localized: "Geral")
        case .menuBar: return String(localized: "Barra de menus")
        case .switcher: return String(localized: "Alternar janelas")
        case .clipboard: return String(localized: "Área de transferência")
        case .windows: return String(localized: "Janelas")
        case .system: return String(localized: "Monitor do sistema")
        case .claude: return String(localized: "Contas do Claude")
        case .support: return String(localized: "Ajuda e relatórios")
        case .about: return String(localized: "Sobre")
        }
    }

    var symbolName: String {
        switch self {
        case .general: return "gearshape"
        case .menuBar: return "menubar.arrow.up.rectangle"
        case .switcher: return "rectangle.on.rectangle"
        case .clipboard: return "doc.on.clipboard"
        case .windows: return "rectangle.split.2x1"
        case .system: return "gauge.with.dots.needle.33percent"
        case .claude: return "sparkle"
        case .support: return "lifepreserver"
        case .about: return "info.circle"
        }
    }

    var enableTitle: String {
        switch self {
        case .menuBar: return String(localized: "Ativar a barra de menus")
        case .switcher: return String(localized: "Ativar o alternador de janelas")
        case .clipboard: return String(localized: "Ativar o histórico da área de transferência")
        case .windows: return String(localized: "Ativar os atalhos de janela")
        case .system: return String(localized: "Ativar o monitor do sistema")
        case .claude: return String(localized: "Ativar as contas do Claude")
        case .general, .support, .about: return title
        }
    }

    var moduleIdentifier: String? {
        switch self {
        case .menuBar: return "menuBarOverflow"
        case .switcher: return "appSwitcher"
        case .clipboard: return "clipboard"
        case .windows: return "windowLayout"
        case .system: return "systemMonitor"
        case .claude: return "claudeAccounts"
        case .general, .support, .about: return nil
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
    @Published var claudeAccounts: [ClaudeAccountSummary] = []
    @Published var isAccessibilityTrusted = AccessibilityPermission.isTrusted
    @Published var menuBarLayout = MenuBarLayout()
    @Published var isMovingMenuBarItem = false
    @Published var menuBarMoveOutcome: MenuBarMoveOutcome?

    var modules: [ModuleInfo] = []
    var loadClipboardStats: () -> ClipboardStats = { ClipboardStats() }
    var loadClaudeAccounts: () -> [ClaudeAccountSummary] = { [] }
    var renameClaudeAccount: (String, String) -> Void = { _, _ in }
    var addClaudeAccount: (String) -> Void = { _ in }
    var removeClaudeAccount: (String) -> Void = { _ in }
    var useClaudeAccount: (String) -> Void = { _ in }
    var openClaudeTerminal: (String) -> Void = { _ in }
    var clearClipboardHistory: () -> Void = {}
    var previewClipboard: () -> Void = {}
    var arrangeMenuBar: () -> Void = {}
    var openSystemReport: () -> Void = {}
    var loginClaude: (String) -> Void = { _ in }
    var loadMenuBarLayout: () -> MenuBarLayout = { MenuBarLayout() }
    var openFeedback: (FeedbackKind) -> Void = { _ in }
    var moveMenuBarItem: (String, MenuBarLayoutTarget, @escaping (MenuBarMoveOutcome) -> Void) -> Void = { _, _, completion in
        completion(.unchanged)
    }

    func refresh() {
        clipboardStats = loadClipboardStats()
        claudeAccounts = loadClaudeAccounts()
        isAccessibilityTrusted = AccessibilityPermission.isTrusted
        if !isMovingMenuBarItem {
            let layout = loadMenuBarLayout()
            if layout != menuBarLayout {
                menuBarLayout = layout
            }
        }
    }

    func requestMenuBarMove(_ identifier: String, to target: MenuBarLayoutTarget) {
        NSLog("Toolbelt: menu bar move requested for \(identifier) to \(target)")
        guard !isMovingMenuBarItem else { return }
        isMovingMenuBarItem = true
        menuBarMoveOutcome = nil
        moveMenuBarItem(identifier, target) { [weak self] outcome in
            NSLog("Toolbelt: menu bar move finished: \(outcome.message)")
            guard let self else { return }
            self.isMovingMenuBarItem = false
            self.menuBarLayout = self.loadMenuBarLayout()
            self.menuBarMoveOutcome = outcome
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var bridge: SettingsBridge
    @ObservedObject var updater: AppUpdater

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $bridge.selection) { section in
                Label(section.title, systemImage: section.symbolName)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 200, max: 240)
        } detail: {
            SettingsPage(section: bridge.selection, settings: settings, bridge: bridge, updater: updater)
                .navigationTitle(bridge.selection.title)
        }
        .frame(minWidth: 720, minHeight: 500)
        .onAppear(perform: bridge.refresh)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            bridge.refresh()
        }
    }
}

struct SettingsPage: View {
    let section: SettingsSection
    @ObservedObject var settings: AppSettings
    @ObservedObject var bridge: SettingsBridge
    @ObservedObject var updater: AppUpdater

    var body: some View {
        switch section {
        case .general: GeneralSettingsPage(settings: settings, bridge: bridge, updater: updater)
        case .menuBar: MenuBarSettingsPage(settings: settings, bridge: bridge)
        case .switcher: AppSwitcherSettingsPage(settings: settings)
        case .clipboard: ClipboardSettingsPage(settings: settings, bridge: bridge)
        case .windows: WindowSettingsPage(settings: settings)
        case .system: SystemMonitorSettingsPage(settings: settings, bridge: bridge)
        case .claude: ClaudeSettingsPage(settings: settings, bridge: bridge)
        case .support: SupportSettingsPage(settings: settings, bridge: bridge, reporter: CrashReporter.shared)
        case .about: AboutPage()
        }
    }
}

private struct ModuleToggleSection: View {
    @ObservedObject var settings: AppSettings
    let section: SettingsSection
    let summary: LocalizedStringKey

    var body: some View {
        if let identifier = section.moduleIdentifier {
            Section {
                Toggle(isOn: Binding(
                    get: { settings.isModuleEnabled(identifier) },
                    set: { settings.setModule(identifier, enabled: $0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.enableTitle)
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
    @ObservedObject var updater: AppUpdater
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

            Section {
                Picker("Idioma do app", selection: Binding(
                    get: { settings.values.appLanguage },
                    set: { language in
                        settings.values.appLanguage = language
                        language.apply()
                    }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                if settings.values.appLanguage != AppLanguage.atLaunch {
                    HStack {
                        Text("Vale depois de reabrir o Toolbelt.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Reabrir agora") {
                            AppUpdater.relaunch(at: Bundle.main.bundleURL)
                        }
                    }
                }
            } header: {
                Text("Idioma")
            } footer: {
                Text("Automático usa o idioma do Mac quando ele é português ou inglês; nos outros idiomas, fica em português.")
            }

            UpdateSettingsSection(settings: settings, updater: updater)

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

            if settings.isModuleEnabled("menuBarOverflow") {
                Section {
                    MenuBarLayoutEditor(bridge: bridge)
                } header: {
                    Text("O que fica na barra")
                } footer: {
                    MenuBarLayoutFooter()
                }
            }

            Section {
                ForEach(InlineInfo.allCases) { info in
                    Toggle(info.title, isOn: Binding(
                        get: { settings.values.menuBar.inlineInfo.contains(info) },
                        set: { enabled in
                            var selected = Set(settings.values.menuBar.inlineInfo)
                            if enabled { selected.insert(info) } else { selected.remove(info) }
                            settings.values.menuBar.inlineInfo = InlineInfo.allCases.filter { selected.contains($0) }
                        }
                    ))
                    .toggleStyle(.switch)
                }
            } header: {
                Text("Ao lado do ícone do Toolbelt")
            } footer: {
                Text("Mostra essas informações junto do cinto, num único item. Combine com desligar os ícones próprios do Claude e do monitor para deixar a barra limpa.")
            }

            Section {
                Toggle("Contas do Claude (trocar, uso, abrir terminal)", isOn: $settings.values.menuBar.panelShowsClaude)
                    .toggleStyle(.switch)
                Toggle("Sistema (memória, disco, relatório do macscan)", isOn: $settings.values.menuBar.panelShowsSystem)
                    .toggleStyle(.switch)
            } header: {
                Text("No painel do Toolbelt")
            } footer: {
                Text("O painel abre ao clicar no cinto.")
            }

            Section {
                Toggle("Ícone próprio das contas do Claude", isOn: $settings.values.claude.showInMenuBar)
                    .toggleStyle(.switch)
                Toggle("Ícone próprio do monitor do sistema", isOn: $settings.values.systemMonitor.showInMenuBar)
                    .toggleStyle(.switch)
            } header: {
                Text("Ícones separados na barra")
            }

            Section("Aparência") {
                Picker("Ícone do Toolbelt", selection: $settings.values.menuBar.iconStyle) {
                    ForEach(ChevronStyle.allCases) { style in
                        Label {
                            Text(style.title)
                        } icon: {
                            if let image = style.image(isOpen: false) {
                                Image(nsImage: image)
                            }
                        }
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

            ClipboardAppearanceSection(appearance: $settings.values.clipboard.appearance, onPreview: bridge.previewClipboard)

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
                Text("Cada print ocupa alguns MB. Senhas copiadas de gerenciadores de senha nunca entram no histórico.")
            }

            ClipboardArchiveSection(settings: settings)

            IgnoredApplicationsSection(identifiers: $settings.values.clipboard.ignoredBundleIdentifiers)
        }
        .formStyle(.grouped)
    }
}

private struct ClipboardAppearanceSection: View {
    @Binding var appearance: ClipboardPanelAppearance
    let onPreview: () -> Void

    var body: some View {
        Section {
            Picker("Tema", selection: $appearance.theme) {
                ForEach(PanelTheme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            Picker("Fundo", selection: $appearance.background) {
                ForEach(PanelBackground.allCases) { background in
                    Text(background.title).tag(background)
                }
            }
            SliderRow(title: "Opacidade do fundo", value: $appearance.backgroundOpacity, range: 0.2...1, step: 0.05) {
                "\(Int(($0 * 100).rounded()))%"
            }
            SliderRow(title: "Largura", value: $appearance.width, range: 300...720, step: 10) { "\(Int($0)) pt" }
            SliderRow(title: "Altura máxima", value: $appearance.maximumHeight, range: 240...900, step: 20) { "\(Int($0)) pt" }
            SliderRow(title: "Tamanho do texto", value: $appearance.fontSize, range: 11...18, step: 1) { "\(Int($0)) pt" }
            SliderRow(title: "Altura das imagens", value: $appearance.imageHeight, range: 40...200, step: 8) { "\(Int($0)) pt" }
            SliderRow(title: "Cantos arredondados", value: $appearance.cornerRadius, range: 0...24, step: 1) { "\(Int($0)) pt" }
            Toggle("Mostrar os números de atalho (1–9, 0)", isOn: $appearance.showsShortcutNumbers)
                .toggleStyle(.switch)
            HStack {
                Button("Pré-visualizar", action: onPreview)
                Spacer()
                Button("Restaurar aparência padrão") {
                    appearance = ClipboardPanelAppearance()
                }
            }
        } header: {
            Text("Aparência do painel")
        } footer: {
            Text("Vidro transparente com opacidade baixa deixa ver o que está atrás. Na pré-visualização, ⎋ fecha sem colar.")
        }
    }
}

private struct SliderRow: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        HStack {
            Slider(value: $value, in: range, step: step) {
                Text(title)
            }
            Text(format(value))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
    }
}

private struct ClipboardArchiveSection: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Section {
            Toggle("Salvar tudo que for copiado em arquivo", isOn: $settings.values.clipboard.isArchiveEnabled)
                .toggleStyle(.switch)
            LabeledContent("Pasta") {
                HStack {
                    Text((settings.values.clipboard.archiveFolderPath as NSString).abbreviatingWithTildeInPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Escolher…", action: chooseFolder)
                    Button("Abrir") {
                        let url = URL(fileURLWithPath: settings.values.clipboard.archiveFolderPath, isDirectory: true)
                        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .disabled(!settings.values.clipboard.isArchiveEnabled)
            Toggle("Incluir imagens copiadas", isOn: $settings.values.clipboard.archiveIncludesImages)
                .toggleStyle(.switch)
                .disabled(!settings.values.clipboard.isArchiveEnabled)
        } header: {
            Text("Arquivo")
        } footer: {
            Text("Um arquivo por dia (AAAA-MM-DD.md) com a hora e o app de origem; imagens vão para a subpasta images. Senhas e apps ignorados não são salvos. O arquivo não tem limite de tamanho nem é apagado com o histórico.")
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Usar esta pasta")
        panel.directoryURL = URL(fileURLWithPath: settings.values.clipboard.archiveFolderPath).deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.values.clipboard.archiveFolderPath = url.path
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

private struct AppSwitcherSettingsPage: View {
    @ObservedObject var settings: AppSettings
    @State private var screenRecordingGranted = ScreenRecordingPermission.isGranted

    private var shortcutDisplay: String {
        settings.values.appSwitcher.activeShortcut?.display ?? String(localized: "O atalho")
    }

    var body: some View {
        Form {
            ModuleToggleSection(settings: settings, section: .switcher, summary: "\(shortcutDisplay) mostra todas as janelas abertas e troca entre elas.")

            Section {
                LabeledContent("Todas as janelas") {
                    ShortcutRecorder(
                        combo: $settings.values.appSwitcher.activeShortcut,
                        defaultCombo: AppSwitcherSettings.defaultShortcut
                    )
                }
                LabeledContent("Só janelas do app atual") {
                    ShortcutRecorder(
                        combo: $settings.values.appSwitcher.activeSameApplicationShortcut,
                        defaultCombo: AppSwitcherSettings.defaultSameApplicationShortcut
                    )
                }
                Toggle("Mostrar as teclas de ação no rodapé do painel", isOn: $settings.values.appSwitcher.showsKeyHints)
                    .toggleStyle(.switch)
                Toggle("Incluir janelas minimizadas", isOn: $settings.values.appSwitcher.includesMinimized)
                    .toggleStyle(.switch)
                Picker("Mostrar o painel após", selection: $settings.values.appSwitcher.showDelayMilliseconds) {
                    Text("Imediatamente").tag(0)
                    Text("80 ms").tag(80)
                    Text("120 ms").tag(120)
                    Text("200 ms").tag(200)
                    Text("300 ms").tag(300)
                }
                Picker("Tamanho dos ícones", selection: $settings.values.appSwitcher.iconSize) {
                    Text("Pequeno").tag(48)
                    Text("Médio").tag(64)
                    Text("Grande").tag(88)
                }
            } header: {
                Text("Atalho e painel")
            } footer: {
                Text("Segure a tecla modificadora e aperte o atalho para avançar; com ⇧ volta. Solte para trocar. \(shortcutDisplay) rápido vai direto para a janela anterior. Com o painel aberto: W fecha a janela, M minimiza, H esconde o app, Q fecha o app e / abre a busca (aí pode soltar a tecla modificadora, digitar e confirmar com ⏎). O mouse também seleciona e clicar troca. Atalhos com ⌘⇥ ou ⌘` substituem os do macOS enquanto o Toolbelt estiver aberto.")
            }

            Section {
                Toggle("Mostrar miniaturas das janelas", isOn: Binding(
                    get: { settings.values.appSwitcher.showsThumbnails },
                    set: { enabled in
                        settings.values.appSwitcher.showsThumbnails = enabled
                        if enabled {
                            ScreenRecordingPermission.request()
                        }
                    }
                ))
                .toggleStyle(.switch)
                if settings.values.appSwitcher.showsThumbnails && !screenRecordingGranted {
                    HStack {
                        Label("Falta a permissão de Gravação de Tela", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Abrir Ajustes…") {
                            ScreenRecordingPermission.openSettings()
                        }
                    }
                }
            } header: {
                Text("Miniaturas")
            } footer: {
                Text("Ao sair de uma janela, o Toolbelt tira um print pequeno dela; assim o ⌥⇥ já abre com as prévias e atualiza em seguida. Guarda no máximo 24 prévias na memória (~6 MB), nada vai para o disco. Usa a permissão de Gravação de Tela só para isso.")
            }
        }
        .formStyle(.grouped)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            screenRecordingGranted = ScreenRecordingPermission.isGranted
        }
    }
}

private struct SystemMonitorSettingsPage: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var bridge: SettingsBridge

    var body: some View {
        Form {
            ModuleToggleSection(settings: settings, section: .system, summary: "RAM, swap e disco na barra, alertas quando apertar e o relatório completo do macscan.")

            Section("Na barra de menus") {
                Toggle("Mostrar na barra", isOn: $settings.values.systemMonitor.showInMenuBar)
                    .toggleStyle(.switch)
                Toggle("RAM em uso (%)", isOn: $settings.values.systemMonitor.showsMemory)
                    .toggleStyle(.switch)
                    .disabled(!settings.values.systemMonitor.showInMenuBar)
                Toggle("Swap em uso", isOn: $settings.values.systemMonitor.showsSwap)
                    .toggleStyle(.switch)
                    .disabled(!settings.values.systemMonitor.showInMenuBar)
                Toggle("Espaço livre no disco", isOn: $settings.values.systemMonitor.showsDisk)
                    .toggleStyle(.switch)
                    .disabled(!settings.values.systemMonitor.showInMenuBar)
                Picker("Atualizar a cada", selection: $settings.values.systemMonitor.refreshSeconds) {
                    Text("5 s").tag(5)
                    Text("15 s").tag(15)
                    Text("30 s").tag(30)
                    Text("1 min").tag(60)
                }
            }

            Section {
                Toggle("Avisar quando apertar", isOn: $settings.values.systemMonitor.alertsEnabled)
                    .toggleStyle(.switch)
                Stepper(
                    "Disco com menos de \(settings.values.systemMonitor.diskWarningPercent)% livre",
                    value: $settings.values.systemMonitor.diskWarningPercent,
                    in: 3...30
                )
                .disabled(!settings.values.systemMonitor.alertsEnabled)
                Stepper(
                    "Swap acima de \(settings.values.systemMonitor.swapWarningGigabytes) GB",
                    value: $settings.values.systemMonitor.swapWarningGigabytes,
                    in: 1...32
                )
                .disabled(!settings.values.systemMonitor.alertsEnabled)
            } header: {
                Text("Alertas")
            } footer: {
                Text("Também avisa quando a pressão de memória fica alta. Cada aviso aparece uma vez e só volta depois que a situação normalizar. O ícone fica laranja ou vermelho enquanto houver algo errado.")
            }

            Section {
                Button("Abrir o relatório completo") {
                    bridge.openSystemReport()
                }
            } header: {
                Text("Relatório do Mac")
            } footer: {
                Text("Usa o macscan: bateria, armazenamento, memória, CPU, processos, segurança e rede. Roda só quando você abre, leva alguns segundos.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct ClaudeSettingsPage: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var bridge: SettingsBridge
    @State private var newAlias = ""
    @State private var accountPendingRemoval: ClaudeAccountSummary?

    var body: some View {
        Form {
            ModuleToggleSection(settings: settings, section: .claude, summary: "Alterna entre contas do Claude Code e mostra o uso de cada uma.")

            Section("Ícone na barra") {
                Toggle("Ícone próprio na barra", isOn: $settings.values.claude.showInMenuBar)
                    .toggleStyle(.switch)
                Toggle("Mostrar o nome da conta ativa (apelido ou início do e-mail)", isOn: $settings.values.claude.showNameInTitle)
                    .toggleStyle(.switch)
                Toggle("Mostrar o uso das últimas 5 h", isOn: $settings.values.claude.showUsageInTitle)
                    .toggleStyle(.switch)
            }

            Section {
                ForEach(bridge.claudeAccounts) { account in
                    ClaudeAccountRow(
                        account: account,
                        onRename: { alias in
                            bridge.renameClaudeAccount(account.account, alias)
                            bridge.refresh()
                        },
                        onUse: {
                            bridge.useClaudeAccount(account.account)
                            bridge.refresh()
                        },
                        onLogin: { bridge.loginClaude(account.account) },
                        onRemove: { accountPendingRemoval = account },
                        onOpenTerminal: { bridge.openClaudeTerminal(account.account) }
                    )
                }
                HStack {
                    TextField("Apelido da nova conta (opcional)", text: $newAlias)
                        .onSubmit(addAccount)
                    Button("Adicionar conta", action: addAccount)
                }
            } header: {
                Text("Contas")
            } footer: {
                Text("Cada conta tem seu próprio login; conversas, memória, skills e configurações são compartilhadas. No terminal: cca use <número ou apelido>, cca swap, cca resume.")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Remover \(accountPendingRemoval?.label ?? "")?",
            isPresented: Binding(get: { accountPendingRemoval != nil }, set: { if !$0 { accountPendingRemoval = nil } }),
            presenting: accountPendingRemoval
        ) { account in
            Button("Remover e sair da conta", role: .destructive) {
                bridge.removeClaudeAccount(account.account)
                bridge.refresh()
            }
        } message: { _ in
            Text("O login dessa conta é encerrado; a pasta de configuração fica no disco.")
        }
    }

    private func addAccount() {
        bridge.addClaudeAccount(newAlias.trimmingCharacters(in: .whitespaces))
        newAlias = ""
        bridge.refresh()
    }
}

private struct ClaudeAccountRow: View {
    let account: ClaudeAccountSummary
    let onRename: (String) -> Void
    let onUse: () -> Void
    let onLogin: () -> Void
    let onRemove: () -> Void
    let onOpenTerminal: () -> Void
    @ObservedObject var settings = AppSettings.shared

    @State private var alias = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            accountLine
            if account.email != nil {
                HStack {
                    Button(action: onOpenTerminal) {
                        Label("Abrir terminal com esta conta", systemImage: "terminal")
                    }
                    Spacer()
                    Text("Atalho")
                        .foregroundStyle(.secondary)
                    ShortcutRecorder(
                        combo: Binding(
                            get: { settings.values.claude.terminalShortcuts[account.account] },
                            set: { settings.values.claude.terminalShortcuts[account.account] = $0 }
                        ),
                        defaultCombo: nil
                    )
                }
                .padding(.leading, 66)
            }
        }
    }

    private var accountLine: some View {
        HStack(spacing: 10) {
            ColorPicker("", selection: color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 28)
                .help("Cor do selo desta conta")
            Image(nsImage: AccountBadge.image(for: account.account, diameter: 24))
            VStack(alignment: .leading, spacing: 2) {
                TextField("Apelido", text: $alias, prompt: Text(account.shortName))
                    .textFieldStyle(.plain)
                    .font(.body.weight(.medium))
                    .focused($isEditing)
                    .onSubmit(commit)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if account.email == nil {
                Button("Entrar…", action: onLogin)
            } else if account.active {
                Text("Ativa")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            } else {
                Button("Usar", action: onUse)
            }
            if !account.primary {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remover conta")
            }
        }
        .onAppear { alias = account.alias }
        .onChange(of: account.alias) { _, newValue in
            if !isEditing { alias = newValue }
        }
        .onChange(of: isEditing) { _, editing in
            if !editing { commit() }
        }
    }

    private var color: Binding<Color> {
        Binding(
            get: { Color(nsColor: NSColor(hex: settings.values.claude.colorHex(for: account.account))) },
            set: { settings.values.claude.accountColors[account.account] = NSColor($0).hexString }
        )
    }

    private var subtitle: String {
        guard let email = account.email else { return String(localized: "sem login") }
        let fiveHour = account.fiveHour.currentPercent.map { "\($0)%" } ?? "?"
        let sevenDay = account.sevenDay.currentPercent.map { "\($0)%" } ?? "?"
        return String(localized: "\(email) · 5h \(fiveHour) · semana \(sevenDay)")
    }

    private func commit() {
        let trimmed = alias.trimmingCharacters(in: .whitespaces)
        guard trimmed != account.alias else { return }
        onRename(trimmed)
    }
}

private struct UpdateSettingsSection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var updater: AppUpdater

    var body: some View {
        Section {
            LabeledContent("Versão instalada", value: "\(AppUpdater.currentVersion) (\(AppUpdater.currentBuild))")
            status
            HStack {
                Button("Verificar agora") {
                    updater.check(userInitiated: true)
                }
                .disabled(updater.isBusy)
                if let lastCheck = updater.lastCheck {
                    Text("Última verificação \(lastCheck.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Toggle("Verificar automaticamente (uma vez por dia)", isOn: $settings.values.updates.checksAutomatically)
                .toggleStyle(.switch)
            Toggle("Avisar com notificação do sistema", isOn: $settings.values.updates.notifiesWithSystemNotification)
                .toggleStyle(.switch)
                .disabled(!settings.values.updates.checksAutomatically)
        } header: {
            Text("Atualizações")
        } footer: {
            Text(updater.canInstallInPlace
                ? "A atualização é baixada de toolbelt.oconde.dev, conferida (SHA-256 e assinatura do mesmo desenvolvedor) e instalada no lugar; o Toolbelt reabre sozinho."
                : "Esta cópia foi compilada localmente, sem assinatura Developer ID: o botão de atualizar abre a página de download.")
        }
    }

    @ViewBuilder
    private var status: some View {
        switch updater.state {
        case .idle:
            Label("Ainda não verificado nesta sessão", systemImage: "clock")
                .foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Verificando…")
            }
        case .upToDate:
            Label("Você está na versão mais recente", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .available(let release):
            VStack(alignment: .leading, spacing: 8) {
                Label("Versão \(release.version) disponível", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                ForEach(release.notes, id: \.self) { note in
                    Text("• \(note)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Button("Atualizar agora") {
                    updater.installAvailableUpdate()
                }
                .buttonStyle(.borderedProminent)
            }
        case .downloading(let release):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Baixando a versão \(release.version)…")
            }
        case .installing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Instalando e reabrindo…")
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}

private struct SupportSettingsPage: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var bridge: SettingsBridge
    @ObservedObject var reporter: CrashReporter

    var body: some View {
        Form {
            Section {
                Button {
                    bridge.openFeedback(.bug)
                } label: {
                    Label("Relatar um problema…", systemImage: "ladybug")
                }
                Button {
                    bridge.openFeedback(.suggestion)
                } label: {
                    Label("Enviar uma sugestão…", systemImage: "lightbulb")
                }
            } header: {
                Text("Falar com o desenvolvedor")
            } footer: {
                Text("Vai direto para o desenvolvedor, com uma prévia exata do que é enviado. O e-mail é opcional, só se você quiser resposta.")
            }

            Section {
                Picker("Relatórios de falha", selection: $settings.values.reports.crashReportMode) {
                    ForEach(CrashReportMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                if !reporter.pending.isEmpty {
                    HStack {
                        Label("\(reporter.pending.count) relatório(s) esperando sua decisão", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Descartar") { reporter.dismissPending() }
                        Button("Enviar") { reporter.sendPending(rememberChoice: false) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            } header: {
                Text("Falhas e travamentos")
            } footer: {
                Text("Quando o Toolbelt fecha ou trava, o macOS guarda um relatório técnico. Com a sua permissão, ele vai para o desenvolvedor: tipo do erro, onde falhou, versão do app e do macOS e o modelo do Mac. Nunca o que você copia, abre ou digita. Com \"Enviar automaticamente\", avisos de erro do próprio app também vão junto.")
            }

            Section("Arquivos") {
                Button("Abrir o log do Toolbelt") {
                    NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Toolbelt.log"))
                }
                Button("Mostrar os relatórios do macOS no Finder") {
                    NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports"))
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutPage: View {
    private static let repositoryURL = URL(string: "https://github.com/nandobrazil/toolbelt")!

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: ToolbeltIcon.image(isOpen: false, pointSize: 72))
                .renderingMode(.template)
                .foregroundStyle(Color.accentColor)
            Text("Toolbelt")
                .font(.largeTitle.bold())
            Text("Versão \(version)")
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("Gostou do Toolbelt? Uma estrela no GitHub ajuda mais gente a encontrá-lo.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Link(destination: Self.repositoryURL) {
                    Label("Deixe uma estrela no GitHub", systemImage: "star")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.top, 6)
            HStack {
                Link("Repositório no GitHub", destination: Self.repositoryURL)
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
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 22)
                .foregroundStyle(.secondary)
            Text(text)
        }
    }
}
