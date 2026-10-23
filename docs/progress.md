# Progresso

## Estado em 2026-10-22

O app do dono é a release oficial instalada pelo Homebrew em `/Applications/Toolbelt.app` (0.2.1); os builds locais do `install.sh` são assinados com o Developer ID e substituem essa mesma cópia. Código aberto no GitHub (`main`). Módulos ligados: barra de menus, alternar janelas, área de transferência, janelas, monitor do sistema, contas do Claude.

Versão 0.2.0 preparada para distribuição: ícone do app, bundle com versão/build, `cca` e `macscan` dentro do app, hardened runtime e entitlements, login automático via `SMAppService`, atualizador (`AppUpdater`), scripts de release (Developer ID, notarização, DMG, zip, `latest.json`) e landing em https://toolbelt.oconde.dev, no VPS de produção desde 22/10/2026 (ficou algumas horas no de dev; o namespace de lá está parado em zero réplicas esperando o OK do dono para apagar). O projeto também aparece no portfólio em https://oconde.dev/projetos/toolbelt/. **Falta a primeira release**: depende do certificado Developer ID e da credencial do notarytool na máquina (passo a passo em `docs/releasing.md`).

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
| Relatório de falha ponta a ponta | testado: sonda com `fatalError` e o bundle id do Toolbelt gerou `.ips` real, o app detectou, perguntou (bolinha laranja e notificação) e, com "Sempre enviar", o Radar recebeu a falha agrupada com o culpado `failDeliberately(_:) (probe.swift:4)` e runtime `macos` |
| Feedback (log `feedback.bug`) | lote aceito pelo Radar (202); a janela não foi usada pela tela |
| Compatibilidade | CI verde no macOS 14.8 (Swift 5.10), 15 e 26.6 (Swift 6.3): build, 9 testes e app aberto por 20 s |
| Editor "O que fica na barra" (arrastar e soltar) | **compilado e instalado, não testado**: o movimento é um ⌘-arrastar sintético e o projeto não simula cliques para testar; o teste de posição (`AXUIElementCopyElementAtPosition`) acerta dono e elemento de todos os ícones visíveis. Depende do usuário |

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
- Editor da barra: o macOS não tem API para mover ícone de outro app, então o Toolbelt faz o que Ice e Bartender fazem, um ⌘-arrastar sintético (cursor escondido e desacoplado do mouse por ~0,4 s, devolvido ao lugar). Travas: só com a janela de Configurações ativa e a barra visível; antes de clicar, o teste de posição exige o dono certo debaixo do ponto (ou o ponto atrás do notch, onde não há conteúdo); depois, confere pela Acessibilidade que o ícone ficou colado no vizinho esperado. Relógio e Central de Controle são fixos. O modo organizar continua como plano B.

## Pendências e ideias

- 0.2.0 publicada em 22/10/2026 (notarizada, DMG e zip em `toolbelt-releases`). Próxima: 0.3.0 com inglês, editor da barra e relatórios, depois de o dono confirmar o arrasto do editor.
- Testar a atualização no lugar de verdade: a próxima release (0.2.2) deve atualizar sozinha a 0.2.1 do Homebrew em `/Applications`.
- Depois da primeira release, testar a troca de versão de verdade (0.2.0 → 0.2.1) pelo botão Atualizar.

- Investigar por que `panelShowsClaude`/`panelShowsSystem` apareceram `false` sem ação do usuário (foram religados). Se repetir, pode ser bug ao salvar.
- Contas do Codex (adiado pelo dono em 22/10/2026), igual às do Claude: uma pasta por conta via `CODEX_HOME` (login em `auth.json`), compartilhando `config.toml`, `AGENTS.md`, skills, rules, prompts, `sessions/` e `history.jsonl`. O uso não fica em disco no Codex 0.163: ler pelo `codex app-server` (experimental), método `account/rateLimits/read` (`planType`, `primary`/`secondary` com `usedPercent`, `windowDurationMins`, `resetsAt`), ao abrir o painel, quando o histórico da conta muda e no reset. Testar antes de compartilhar os SQLite de estado entre contas. App desktop do Codex e app do ChatGPT ficam fora (o refresh token gira e uma cópia velha do `auth.json` derruba a sessão).
- "Abrir terminal com esta conta" usa o Terminal do macOS: oferecer escolha do terminal (Ghostty, iTerm, WezTerm).
- ⌥\` (keyCode 50) pode não existir em teclados ABNT; dá para regravar nas Configurações.
- Alternador: janelas de outros espaços (exige APIs privadas frágeis), modo "apps sem janela".
- Codenotch (app de terceiros) já lê várias contas (`~/.claude-*`), mas só procura pastas novas ao abrir: reiniciá-lo após `cca add`.
- Ícone do app (Dock/Finder) e tela de boas-vindas pedindo as permissões.
