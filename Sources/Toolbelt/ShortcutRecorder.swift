import AppKit
import SwiftUI

struct ShortcutRecorder: View {
    @Binding var combo: KeyCombo?
    let defaultCombo: KeyCombo?

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var rejected = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggleRecording) {
                Text(label)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(combo == nil && !isRecording ? .secondary : .primary)
                    .frame(minWidth: 120)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? .accentColor : (rejected ? .red : nil))

            if combo != nil && !isRecording {
                Button {
                    combo = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Desativar atalho")
            }

            if let defaultCombo, combo != defaultCombo, !isRecording {
                Button {
                    combo = defaultCombo
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Voltar para \(defaultCombo.display)")
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private var label: String {
        if isRecording {
            return rejected ? "Use ⌘, ⌥ ou ⌃" : "Digite o atalho…"
        }
        return combo?.display ?? "Desativado"
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        rejected = false
        HotKeyCenter.shared.suspend()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = KeyCombo.carbonModifiers(from: event.modifierFlags)
            if event.keyCode == 53 && modifiers == 0 {
                stopRecording()
                return nil
            }
            if (event.keyCode == 51 || event.keyCode == 117) && modifiers == 0 {
                combo = nil
                stopRecording()
                return nil
            }
            let candidate = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            guard candidate.hasRequiredModifier else {
                rejected = true
                NSSound.beep()
                return nil
            }
            combo = candidate
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        if isRecording {
            HotKeyCenter.shared.resume()
        }
        isRecording = false
        rejected = false
    }
}
