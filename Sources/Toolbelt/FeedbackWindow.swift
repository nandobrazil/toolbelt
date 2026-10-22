import AppKit
import SwiftUI

enum FeedbackKind: String, CaseIterable, Identifiable {
    case bug
    case suggestion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bug: return "Problema"
        case .suggestion: return "Sugestão"
        }
    }

    var message: String { "feedback.\(rawValue)" }
}

final class FeedbackModel: ObservableObject {
    enum Status: Equatable {
        case editing
        case sending
        case sent
        case queued
        case unavailable
    }

    @Published var kind: FeedbackKind = .bug
    @Published var text = ""
    @Published var email = ""
    @Published var includesDiagnostics = true
    @Published var status: Status = .editing

    var enabledModules: () -> [String] = { [] }
    var onFinish: () -> Void = {}

    var canSend: Bool {
        status == .editing && text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5
    }

    var event: RadarEvent {
        var attrs: [String: JSONValue] = [
            "text": .string(text.trimmingCharacters(in: .whitespacesAndNewlines)),
            "appVersion": .string("\(AppUpdater.currentVersion) (\(AppUpdater.currentBuild))"),
            "macOS": .string(Diagnostics.macOSVersion)
        ]
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        if !trimmedEmail.isEmpty {
            attrs["email"] = .string(trimmedEmail)
        }
        if includesDiagnostics {
            attrs["diagnostics"] = .object(Diagnostics.summary(enabledModules: enabledModules()))
        }
        return .log(
            kind.message,
            level: kind == .bug ? "warn" : "info",
            attrs: attrs,
            user: trimmedEmail.isEmpty ? nil : RadarUser(email: trimmedEmail)
        )
    }

    var preview: String {
        guard let data = RadarClient.encodedBatch([event]),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else { return "" }
        return String(decoding: pretty, as: UTF8.self)
    }

    func send() {
        guard canSend else { return }
        guard RadarClient.isConfigured else {
            status = .unavailable
            return
        }
        status = .sending
        RadarClient.send([event]) { [weak self] delivered in
            guard let self else { return }
            self.status = delivered ? .sent : .queued
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.onFinish()
            }
        }
    }
}

final class FeedbackWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    var enabledModules: () -> [String] = { [] }

    func show(kind: FeedbackKind) {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let model = FeedbackModel()
        model.kind = kind
        model.enabledModules = enabledModules
        model.onFinish = { [weak self] in self?.window?.close() }
        let window = NSWindow(contentViewController: NSHostingController(rootView: FeedbackView(model: model)))
        window.title = "Relatar ao desenvolvedor"
        window.styleMask = [.titled, .closable, .resizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(NSSize(width: 520, height: 520))
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

private struct FeedbackView: View {
    @ObservedObject var model: FeedbackModel
    @State private var showsPreview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Tipo", selection: $model.kind) {
                ForEach(FeedbackKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(model.kind == .bug ? "O que aconteceu? O que você esperava que acontecesse?" : "O que faria o Toolbelt ficar melhor para você?")
                .font(.headline)
            TextEditor(text: $model.text)
                .font(.body)
                .frame(minHeight: 140)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.15)))

            TextField("E-mail para resposta (opcional)", text: $model.email)
                .textFieldStyle(.roundedBorder)

            Toggle("Incluir diagnóstico (versões, modelo do Mac, módulos ligados e as últimas linhas do log, sem dados pessoais)", isOn: $model.includesDiagnostics)
                .toggleStyle(.checkbox)

            DisclosureGroup("Ver exatamente o que será enviado", isExpanded: $showsPreview) {
                ScrollView {
                    Text(model.preview)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 160)
            }

            Spacer(minLength: 0)
            HStack {
                status
                Spacer()
                Button("Cancelar") { model.onFinish() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(model.status == .sending)
                Button("Enviar") { model.send() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canSend)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 460)
    }

    @ViewBuilder
    private var status: some View {
        switch model.status {
        case .editing:
            EmptyView()
        case .sending:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Enviando…")
            }
        case .sent:
            Label("Enviado. Obrigado!", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .queued:
            Label("Sem conexão agora: guardei e envio sozinho depois.", systemImage: "tray.and.arrow.up.fill")
                .foregroundStyle(.orange)
        case .unavailable:
            Label("Esta cópia foi compilada sem a chave de envio. Use a versão do site.", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}
