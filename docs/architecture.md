# Arquitetura do Toolbelt

App de barra de menus para macOS (Swift/AppKit + SwiftUI) que junta, num único processo leve (~15 MB), o que antes eram vários utilitários: Ice/Bartender, AltTab, Flycut, Rectangle, um monitor de RAM/disco e a troca de contas do Claude Code.

Código aberto (GPL-3.0) em github.com/nandobrazil/toolbelt; downloads nas releases do mesmo repositório; landing em `site/` (https://toolbelt.oconde.dev, VPS de produção, imagem no GHCR por commit). macOS 14+, binário universal (desenvolvido no macOS 26, MacBook Air M4 com notch).

## Módulos

| Módulo | Identificador | O que faz | Arquivos principais |
|---|---|---|---|
| Barra de menus | `menuBarOverflow` | Separador de 10.000 pt esconde ícones à esquerda; o clique no cinto abre o painel com os escondidos (lidos via AX `AXExtrasMenuBar`) e abre o menu do app soltando o separador por 0,6 s + `AXPress` | `MenuBarOverflowModule`, `MenuBarExtras`, `MenuBarLayout` (editor: mover ícones com ⌘-arrastar sintético), `MenuBarLayoutEditor`, `ToolbeltPanel`, `PanelSections`, `ToolbeltIcon` |
| Alternar janelas | `appSwitcher` | ⌥⇥ (todas) e ⌥\` (app atual), ou ⌘⇥/⌘\` no lugar dos do macOS; hover, busca com `/`, ações W/M/H/Q, miniaturas opcionais com cache | `AppSwitcherModule`, `WindowCatalog`, `WindowThumbnails`, `NativeWindowSwitching` |
| Área de transferência | `clipboard` | ⌥⌘V abre painel não ativador; texto, imagens e prints; arquivo diário `.md` opcional; aparência configurável | `ClipboardModule`, `ClipboardStore`, `ClipboardPicker`, `ClipboardArchive`, `ScreenshotWatcher` |
| Janelas | `windowLayout` | Atalhos ⌃⌥ estilo Rectangle via AX | `WindowLayoutModule` |
| Monitor do sistema | `systemMonitor` | RAM/swap/disco nativos, alertas, relatório do `bin/macscan --json` | `SystemMonitorModule`, `SystemMetrics`, `SystemReportWindow` |
| Contas do Claude | `claudeAccounts` | N contas do Claude Code via `bin/cca`, selo colorido, terminal preso a uma conta | `ClaudeAccountsModule`, `FileWatcher`, `bin/cca` |

Infra comum: `AppController` (orquestra módulos, cinto, painel), `AppSettings` (configurações persistidas, `LaunchAtLogin` via `SMAppService`), `HotKeyCenter` (atalhos globais Carbon; avisa o `NativeWindowSwitching` quando um atalho colide com ⌘⇥/⌘⇧⇥/⌘\` do macOS), `AppUpdater` (verificação diária, aviso no painel/notificação, download, conferência de SHA-256 e assinatura, troca do bundle e reabertura), `CrashReporter` (falhas `.ips` e travamentos do MetricKit, consentimento, avisos automáticos), `RadarClient` (protocolo v1 do Radar com fila em disco), `Diagnostics` (versões, modelo, módulos e log mascarado), `FeedbackWindow` (relatar problema ou sugestão), `NotificationRouter` (um delegado para as notificações de atualização e de falha), `SettingsView`/`SettingsWindowController` (janela de configurações), `ShortcutRecorder`, `ToolbeltModule` (protocolo e utilitários, `CommandLineTool` acha `cca`/`macscan` em `~/.local/bin` ou dentro do bundle).

## Ferramentas de linha de comando (em `bin/`, com link em `~/.local/bin` e cópia em `Contents/Resources/bin` do app)

- `cca`: contas do Claude Code. Registro em `~/.config/claude-accounts/accounts.json`; conta 1 = `~/.claude`, conta 2 = `~/.claude-b`, novas = `~/.claude-N`. Cada conta tem login próprio (Keychain com sufixo pelo `CLAUDE_CONFIG_DIR`) e compartilha `projects/` (conversas e memória), skills, `settings.json` e `CLAUDE.md` por symlink. `cca pin N` prende um terminal a uma conta (`CCA_ACCOUNT`). O `~/.zshrc` tem uma função `claude()` que usa `cca dir`.
- `macscan`: raio-x do Mac (bateria, disco, memória, CPU, processos, segurança, rede). `--json` alimenta a janela de relatório.

## Build e instalação

```bash
scripts/install.sh
```

Compila em release com `memcap` (teto de 2 GB; regra de memória do Mac de 16 GB), monta `/Applications/Toolbelt.app` (ou `~/Applications` sem Developer ID) com `scripts/assemble-app.sh` (Info.plist com `VERSION` e o número de commits como build, ícone `Resources/AppIcon.icns`, `cca` e `macscan` em `Contents/Resources/bin`), assina com o **Developer ID** do Keychain (ou, sem ele, com o certificado autoassinado **Toolbelt Local Signing**) com hardened runtime e `Resources/Toolbelt.entitlements`, encerra a cópia em execução (SIGTERM, que devolve o ⌘⇥ ao macOS) e abre a nova com `open`. Log em `~/Library/Logs/Toolbelt.log` (o próprio app redireciona o stderr para lá).

O app se registra como item de início pelo `SMAppService` na primeira abertura e apaga o LaunchAgent antigo `dev.oconde.toolbelt` se existir. Parar: `pkill -x Toolbelt`. Abrir: `open /Applications/Toolbelt.app`. Se o app mudar de lugar, ele refaz o item de início sozinho.

Em máquina nova, criar o certificado antes: `scripts/create-signing-identity.sh`. Assinatura ad-hoc faz o macOS esquecer Acessibilidade e Gravação de Tela a cada build.

Ícone: `scripts/make-icon.swift` desenha o cinto (mesma geometria do `ToolbeltIcon`) em todos os tamanhos; `iconutil` gera o `.icns`.

Versão pública (Developer ID, notarização, DMG, atualização): [releasing.md](releasing.md).

## Permissões

- **Acessibilidade**: obrigatória (colar, mover janelas, ícones escondidos, alternador).
- **Gravação de Tela**: só para as miniaturas do alternador (desligadas por padrão).
- **Pasta de prints** (Mesa): para guardar prints no histórico.
- **Notificações**: alertas do monitor do sistema.

## Mais

- `CLAUDE.md`: regras para agentes que forem mexer aqui.
- `docs/progress.md`: estado atual, decisões e pendências.
