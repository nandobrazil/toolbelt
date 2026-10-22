# Toolbelt

App pessoal de barra de menus para macOS (Swift/AppKit + SwiftUI) que junta, num único processo leve (~15 MB), o que antes eram vários utilitários: Ice/Bartender, AltTab, Flycut, Rectangle, um monitor de RAM/disco e a troca de contas do Claude Code.

Repositório privado: github.com/nandobrazil/toolbelt. macOS 14+ (desenvolvido no macOS 26, MacBook Air M4 com notch).

## Módulos

| Módulo | Identificador | O que faz | Arquivos principais |
|---|---|---|---|
| Barra de menus | `menuBarOverflow` | Separador de 10.000 pt esconde ícones à esquerda; o clique no cinto abre o painel com os escondidos (lidos via AX `AXExtrasMenuBar`) e abre o menu do app soltando o separador por 0,6 s + `AXPress` | `MenuBarOverflowModule`, `MenuBarExtras`, `ToolbeltPanel`, `PanelSections`, `ToolbeltIcon` |
| Alternar janelas | `appSwitcher` | ⌥⇥ (todas) e ⌥\` (app atual); hover, busca com `/`, ações W/M/H/Q, miniaturas opcionais com cache | `AppSwitcherModule`, `WindowCatalog`, `WindowThumbnails` |
| Área de transferência | `clipboard` | ⌥⌘V abre painel não ativador; texto, imagens e prints; arquivo diário `.md` opcional; aparência configurável | `ClipboardModule`, `ClipboardStore`, `ClipboardPicker`, `ClipboardArchive`, `ScreenshotWatcher` |
| Janelas | `windowLayout` | Atalhos ⌃⌥ estilo Rectangle via AX | `WindowLayoutModule` |
| Monitor do sistema | `systemMonitor` | RAM/swap/disco nativos, alertas, relatório do `bin/macscan --json` | `SystemMonitorModule`, `SystemMetrics`, `SystemReportWindow` |
| Contas do Claude | `claudeAccounts` | N contas do Claude Code via `bin/cca`, selo colorido, terminal preso a uma conta | `ClaudeAccountsModule`, `FileWatcher`, `bin/cca` |

Infra comum: `AppController` (orquestra módulos, cinto, painel), `AppSettings` (configurações persistidas), `HotKeyCenter` (atalhos globais Carbon), `SettingsView`/`SettingsWindowController` (janela de configurações), `ShortcutRecorder`, `ToolbeltModule` (protocolo e utilitários).

## Ferramentas de linha de comando (em `bin/`, com link em `~/.local/bin`)

- `cca`: contas do Claude Code. Registro em `~/.config/claude-accounts/accounts.json`; conta 1 = `~/.claude`, conta 2 = `~/.claude-b`, novas = `~/.claude-N`. Cada conta tem login próprio (Keychain com sufixo pelo `CLAUDE_CONFIG_DIR`) e compartilha `projects/` (conversas e memória), skills, `settings.json` e `CLAUDE.md` por symlink. `cca pin N` prende um terminal a uma conta (`CCA_ACCOUNT`). O `~/.zshrc` tem uma função `claude()` que usa `cca dir`.
- `macscan`: raio-x do Mac (bateria, disco, memória, CPU, processos, segurança, rede). `--json` alimenta a janela de relatório.

## Build e instalação

```bash
scripts/install.sh
```

Compila em release com `memcap` (teto de 2 GB; regra de memória do Mac de 16 GB), monta `~/Applications/Toolbelt.app`, assina com o certificado autoassinado **Toolbelt Local Signing** e (re)carrega o LaunchAgent `dev.oconde.toolbelt`. Log em `~/Library/Logs/Toolbelt.log`.

Em máquina nova, criar o certificado antes: `scripts/create-signing-identity.sh`. Assinatura ad-hoc faz o macOS esquecer Acessibilidade e Gravação de Tela a cada build.

## Permissões

- **Acessibilidade**: obrigatória (colar, mover janelas, ícones escondidos, alternador).
- **Gravação de Tela**: só para as miniaturas do alternador (desligadas por padrão).
- **Pasta de prints** (Mesa): para guardar prints no histórico.
- **Notificações**: alertas do monitor do sistema.

## Mais

- `CLAUDE.md`: regras para agentes que forem mexer aqui.
- `docs/progress.md`: estado atual, decisões e pendências.
