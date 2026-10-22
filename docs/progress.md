# Progresso

## Estado em 2026-10-22

Tudo instalado em `~/Applications/Toolbelt.app` e no GitHub (`main`). Módulos ligados: barra de menus, alternar janelas, área de transferência, janelas, monitor do sistema, contas do Claude.

Versão 0.2.0 preparada para distribuição: ícone do app, bundle com versão/build, `cca` e `macscan` dentro do app, hardened runtime e entitlements, login automático via `SMAppService`, atualizador (`AppUpdater`), scripts de release (Developer ID, notarização, DMG, zip, `latest.json`) e landing em https://toolbelt.oconde.dev. **Falta a primeira release**: depende do certificado Developer ID e da credencial do notarytool na máquina (passo a passo em `docs/releasing.md`).

Configuração atual do usuário: ícone "cinto", nada ao lado do cinto (`inlineInfo` vazio), ícones próprios do Claude e do monitor desligados (o usuário desligou ao ver o do Claude colado no cinto), painel com seções Claude e Sistema, alternador em ⌘⇥ (como no AltTab), miniaturas do alternador ligadas, arquivo da área de transferência desligado.

## Testado e não testado

| Item | Situação |
|---|---|
| Painel dos ícones escondidos, abrir item escondido atrás do notch | testado (AltTab/menu abriu) |
| Varredura AX dos itens da barra | 0,14–0,20 s, em segundo plano com cache |
| Área de transferência: colar via painel, imagens, prints | testado (TextEdit; print real ⌘⇧3) |
| Arquivo diário da área de transferência | testado numa pasta temporária |
| Contas do Claude: migração a/b → 1/2, `cca pin`, troca refletida no ícone | testado |
| Monitor: números batem com `macscan`; relatório | testado no binário; janela não vista pela tela |
| Alternador ⌥⇥: catálogo de janelas (9 janelas, 0,04 s) | testado isoladamente |
| Alternador: painel, hover, busca, ações W/M/H/Q, ⌥\`, cache de miniaturas | **compilado e instalado, não testado pela tela**; depende do usuário |
| Janela de Configurações e painel com seções | **não vistos pela tela** |
| ⌘⇥ no alternador: desliga/religa os atalhos nativos (1, 2) ao subir/parar o app | testado (`CGSGetSymbolicHotKeyValue`/`CGSIsSymbolicHotKeyEnabled`) |
| Atualizador: verificação 60 s após abrir, versão nova detectada, bolinha no cinto, notificação registrada | testado com feed local (http://127.0.0.1) |
| Atualizador: conferência de assinatura (Team ID, bundle id) | testado contra o AltTab (Developer ID); instalar no lugar e reabrir **só testável com a primeira release assinada** |
| Build universal (arm64 + x86_64) | testado (pico de 1,6 GB) |
| Landing | conferida no Chrome headless (claro, escuro, 360–1440 px); Safari e Firefox não vistos |

## Decisões

- Barra: o notch esconde ícones que não cabem; a solução foi o painel abaixo do cinto em vez de só expandir o separador.
- Área de transferência: `NSPanel` não ativador; o `NSMenu` com troca de foco atrasava a colagem em ~1 s.
- Prints: observar a pasta do `screencapture` e filtrar pelo xattr `kMDItemIsScreenCapture`; `NSMetadataQuery` não devolvia resultados para o app.
- Uso do Claude: lido do `cachedUsageUtilization` de cada `.claude.json` (só muda quando o Claude Code roda). Atualiza por FileWatcher + timer no horário do reset; sem polling e sem chamar endpoint não documentado.
- Monitor: leituras nativas (host_statistics64, `vm.swapusage`, statfs); o relatório completo reutiliza o `macscan` (fonte única para terminal e app).
- Alternador: `WindowCatalog` usa AX + `_AXUIElementGetWindow` (API privada estável, também usada pelo AltTab/Rectangle) e a ordem do `CGWindowList`. Foco via `kAXFrontmostAttribute` + `AXRaise` (evita a ativação cooperativa do macOS 14). Busca entra com `/` porque W/M/H/Q são ações.
- ⌘⇥ no alternador: o macOS pega ⌘⇥/⌘⇧⇥/⌘` antes do app (symbolic hotkeys 1, 2 e 27, conferidos com `CGSGetSymbolicHotKeyValue`). `NativeWindowSwitching` desliga só o que algum atalho do Toolbelt usa (e tudo durante a gravação de atalho), como o AltTab, e religa ao sair (willTerminate + SIGTERM/INT/HUP/QUIT) e ao iniciar. Se o app travar, o ⌘⇥ do macOS só volta quando o Toolbelt abrir de novo.
- Miniaturas: ScreenCaptureKit, prints estáticos; cache de 24 imagens (~6 MB) só com a opção ligada.
- Barra limpa: o usuário escolhe o que aparece ao lado do cinto (`InlineInfo`); ícones próprios são opcionais; o conteúdo também aparece no painel do cinto.
- Distribuição fora da App Store (sandbox impede Acessibilidade e as APIs privadas): Developer ID + notarização + hardened runtime. Binários como assets em `toolbelt-releases` (público); o app consulta `toolbelt.oconde.dev/updates/latest.json`, que o nginx redireciona para `releases/latest/download/latest.json`, então dá para mudar onde ficam os arquivos sem lançar versão.
- Atualizador próprio em vez do Sparkle: menos memória, UI no painel e nas Configurações, e a segurança vem do SHA-256 do manifesto mais a exigência de assinatura Apple do mesmo Team ID e bundle id. Build local (sem Team ID) só abre a página de download.
- Reabrir depois de atualizar via `NSWorkspace.openApplication` com `createsNewApplicationInstance` e `--relaunch-after <pid>`: um processo filho morreria junto com o job do launchd.
- Log: o app redireciona o stderr para `~/Library/Logs/Toolbelt.log` (sem LaunchAgent não há `StandardErrorPath`).

## Pendências e ideias

- Primeira release 0.2.0: criar o certificado Developer ID Application e a credencial `toolbelt-notary`, criar o repositório público `nandobrazil/toolbelt-releases`, rodar `scripts/release.sh` e `scripts/publish-release.sh`. Até lá o botão de download da landing dá 404.
- Depois da primeira release, testar a troca de versão de verdade (0.2.0 → 0.2.1) pelo botão Atualizar.

- Investigar por que `panelShowsClaude`/`panelShowsSystem` apareceram `false` sem ação do usuário (foram religados). Se repetir, pode ser bug ao salvar.
- "Abrir terminal com esta conta" usa o Terminal do macOS; o usuário também usa Ghostty: oferecer escolha do terminal.
- ⌥\` (keyCode 50) pode não existir no teclado ABNT do usuário; ele pode regravar nas Configurações.
- Alternador: janelas de outros espaços (exige APIs privadas frágeis), modo "apps sem janela".
- Codenotch (app de terceiros) já lê várias contas (`~/.claude-*`), mas só procura pastas novas ao abrir: reiniciá-lo após `cca add`.
- Ícone do app (Dock/Finder) e tela de boas-vindas pedindo as permissões.
- Disco do usuário com ~7% livre: alerta do monitor ativo por isso.
