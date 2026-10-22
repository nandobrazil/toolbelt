import AppKit
import SwiftUI

struct MacscanFinding: Decodable, Hashable {
    let level: String
    let text: String
}

struct MacscanRow: Decodable, Hashable {
    let label: String
    let value: String
}

struct MacscanSection: Decodable, Hashable {
    let title: String
    let subtitle: String?
    let rows: [MacscanRow]
}

struct MacscanReport: Decodable {
    let generatedAt: String
    let machine: String
    let findings: [MacscanFinding]
    let sections: [MacscanSection]
}

final class SystemReportModel: ObservableObject {
    @Published var report: MacscanReport?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var includesDisk = false

    private let command = NSString(string: "~/.local/bin/macscan").expandingTildeInPath

    func load(includingDisk: Bool = false) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        includesDisk = includingDisk
        let command = command
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = includingDisk ? ["--json", "--disk"] : ["--json"]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            var report: MacscanReport?
            var failure: String?
            do {
                try process.run()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                report = try JSONDecoder().decode(MacscanReport.self, from: data)
            } catch {
                failure = "Não consegui rodar o macscan: \(error.localizedDescription)"
            }
            DispatchQueue.main.async {
                self.isLoading = false
                if let report {
                    self.report = report
                } else {
                    self.errorMessage = failure
                }
            }
        }
    }
}

struct SystemReportView: View {
    @ObservedObject var model: SystemReportModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let errorMessage = model.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    if let report = model.report {
                        FindingsView(findings: report.findings)
                        ForEach(report.sections, id: \.self) { section in
                            SectionCard(section: section)
                        }
                    } else if model.isLoading {
                        ProgressView("Analisando o Mac…")
                            .frame(maxWidth: .infinity, minHeight: 240)
                    }
                }
                .padding(18)
            }
        }
        .frame(minWidth: 620, minHeight: 520)
        .onAppear {
            if model.report == nil {
                model.load()
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.report?.machine ?? "macscan")
                    .font(.headline)
                Text(model.isLoading ? "Analisando…" : "Gerado às \(generatedTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isLoading {
                ProgressView().controlSize(.small)
            }
            Button("Analisar pastas") {
                model.load(includingDisk: true)
            }
            .help("Inclui as pastas que mais ocupam espaço; leva mais tempo")
            .disabled(model.isLoading)
            Button {
                model.load(includingDisk: model.includesDisk)
            } label: {
                Label("Atualizar", systemImage: "arrow.clockwise")
            }
            .disabled(model.isLoading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var generatedTime: String {
        guard let generatedAt = model.report?.generatedAt else { return "—" }
        let parts = generatedAt.split(separator: "T")
        guard parts.count == 2 else { return generatedAt }
        return String(parts[1].prefix(5))
    }
}

private struct FindingsView: View {
    let findings: [MacscanFinding]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if findings.isEmpty {
                Label("Tudo certo", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            } else {
                Text(findings.count == 1 ? "1 ponto de atenção" : "\(findings.count) pontos de atenção")
                    .font(.headline)
                ForEach(findings, id: \.self) { finding in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(color(for: finding.level))
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                        Text(finding.text)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
    }

    private func color(for level: String) -> Color {
        switch level {
        case "critical": return .red
        case "warning": return .orange
        default: return .blue
        }
    }
}

private struct SectionCard: View {
    let section: MacscanSection

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.title.capitalized)
                    .font(.headline)
                if let subtitle = section.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 12) {
                    Text(row.label)
                        .foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .leading)
                    Text(row.value)
                        .font(usesMonospace ? .system(.body, design: .monospaced) : .body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
    }

    private var usesMonospace: Bool {
        section.rows.contains { $0.value.contains("█") || $0.value.contains("  ") }
    }
}

final class SystemReportWindowController {
    private let model = SystemReportModel()
    private var window: NSWindow?

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        if !model.isLoading {
            model.load(includingDisk: model.includesDisk)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SystemReportView(model: model)))
        window.title = "Relatório do Mac"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 700, height: 640))
        window.center()
        window.setFrameAutosaveName("ToolbeltSystemReport")
        return window
    }
}
