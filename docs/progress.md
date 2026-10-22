# Progresso

## Estado em 2026-10-22

Tudo instalado em `~/Applications/Toolbelt.app` e no GitHub (`main`). Módulos ligados: barra de menus, alternar janelas, área de transferência, janelas, monitor do sistema, contas do Claude.

Configuração atual do usuário: ícone "cinto", nada ao lado do cinto (`inlineInfo` vazio), ícones próprios do Claude e do monitor ligados, painel com seções Claude e Sistema, miniaturas do alternador desligadas, arquivo da área de transferência desligado.

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

## Decisões

- Barra: o notch esconde ícones que não cabem; a solução foi o painel abaixo do cinto em vez de só expandir o separador.
- Área de transferência: `NSPanel` não ativador; o `NSMenu` com troca de foco atrasava a colagem em ~1 s.
- Prints: observar a pasta do `screencapture` e filtrar pelo xattr `kMDItemIsScreenCapture`; `NSMetadataQuery` não devolvia resultados para o app.
- Uso do Claude: lido do `cachedUsageUtilization` de cada `.claude.json` (só muda quando o Claude Code roda). Atualiza por FileWatcher + timer no horário do reset; sem polling e sem chamar endpoint não documentado.
- Monitor: leituras nativas (host_statistics64, `vm.swapusage`, statfs); o relatório completo reutiliza o `macscan` (fonte única para terminal e app).
- Alternador: `WindowCatalog` usa AX + `_AXUIElementGetWindow` (API privada estável, também usada pelo AltTab/Rectangle) e a ordem do `CGWindowList`. Foco via `kAXFrontmostAttribute` + `AXRaise` (evita a ativação cooperativa do macOS 14). Busca entra com `/` porque W/M/H/Q são ações.
- Miniaturas: ScreenCaptureKit, prints estáticos; cache de 24 imagens (~6 MB) só com a opção ligada.
- Barra limpa: o usuário escolhe o que aparece ao lado do cinto (`InlineInfo`); ícones próprios são opcionais; o conteúdo também aparece no painel do cinto.

## Pendências e ideias

- Investigar por que `panelShowsClaude`/`panelShowsSystem` apareceram `false` sem ação do usuário (foram religados). Se repetir, pode ser bug ao salvar.
- "Abrir terminal com esta conta" usa o Terminal do macOS; o usuário também usa Ghostty: oferecer escolha do terminal.
- ⌥\` (keyCode 50) pode não existir no teclado ABNT do usuário; ele pode regravar nas Configurações.
- Alternador: janelas de outros espaços (exige APIs privadas frágeis), modo "apps sem janela".
- Codenotch (app de terceiros) já lê várias contas (`~/.claude-*`), mas só procura pastas novas ao abrir: reiniciá-lo após `cca add`.
- Ícone do app (Dock/Finder) e tela de boas-vindas pedindo as permissões.
- Disco do usuário com ~7% livre: alerta do monitor ativo por isso.
