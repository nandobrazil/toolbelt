# Toolbelt: instruções para agentes

Leia `docs/architecture.md` (arquitetura), `docs/progress.md` (estado, decisões, pendências) e, se for distribuir, `docs/releasing.md` antes de mexer. O `README.md` é a apresentação pública do produto.

## Regras do projeto

- **Grafo do repositório:** `graphify-out/graph.json` + `GRAPH_REPORT.md`; pergunta sobre arquitetura → `graphify query` antes de abrir arquivos; depois de mudanças grandes, rodar a skill `building-project-graph`.
- **Leveza é requisito.** O app roda o tempo todo; hoje ~15 MB de footprint e 0% de CPU parado. Nada de polling quando existir gatilho (FileWatcher, notificações do NSWorkspace, timer para o próximo evento). Medir com `footprint $(pgrep -x Toolbelt)` depois de mudanças.
- **Build só pelo `scripts/install.sh`** (usa `memcap`). Build avulso: `memcap 2048 -- swift build -c release`; universal (release): `memcap 4096`. Nunca build sem teto no Mac (há um hook que bloqueia).
- **Não trocar a assinatura para ad-hoc.** O certificado "Toolbelt Local Signing" mantém as permissões entre builds.
- **Sem comentários no código**, nomes em inglês; textos da interface em português como chave de tradução: literal em SwiftUI (`Text("…")`) ou `String(localized: "…")` em AppKit, notificações, mensagens e enums, nunca texto solto. Toda chave nova ganha a tradução em `Resources/Localization/en.lproj/Localizable.strings`.
- **Não simular cliques/teclas na tela de quem usa o Mac para testar.** Um clique sintético já caiu no conteúdo de outro app em tela cheia. Para conferir: AX (ler títulos dos itens), `screencapture` só da faixa da barra, logs e `footprint`. Peça ao usuário para testar interações.
- **Configurações**: todo campo novo entra em `AppSettings.swift` com `init(from:)` tolerante (`decodeIfPresent ?? default`), senão configurações antigas quebram. Para mudar configuração por fora, pare o app (`pkill -x Toolbelt`), edite `settings.v1` via `defaults export/import` e suba de novo (`open ~/Applications/Toolbelt.app`); com o app vivo ele sobrescreve. O login automático é do `SMAppService` (não existe mais LaunchAgent).
- **Módulo novo**: implementar `ToolbeltModule` (start/stop/settingsDidChange/menuItems), registrar em `AppController.modules`, página em `SettingsView`, `SettingsSection` correspondente. Item próprio na barra precisa de posição padrão em `AppController.defaultItemPositions`, senão nasce atrás do notch.
- **Conflitos de atalho**: Flycut, Ice e AltTab originais foram fechados (não desinstalados) porque usavam os mesmos atalhos/função.
- **Distribuição**: versão pública só por `scripts/release.sh` (Developer ID + notarização) e `scripts/publish-release.sh` (release em `nandobrazil/toolbelt-releases`). Nunca publicar build sem notarização. O formato do `latest.json` é lido por versões antigas do app: só acrescentar campos.
- **Prévia da landing:** toda feature ou correção que muda algo visível ou descrito na landing atualiza, na mesma entrega, as imagens (`scripts/landing-screenshots.sh`), o modal de Configurações e os textos em português e inglês. Processo e proibições em `docs/landing.md`.
- **Landing** em `site/`, no **VPS de produção** (skills `deploying-to-oconde-prod` e `deploying-to-oconde-vps-production`): push em `main` que mexa em `site/`, `infra/` ou no Dockerfile gera `ghcr.io/nandobrazil/toolbelt-site:<sha7>` e publica em https://toolbelt.oconde.dev (workflow `deploy-site.yml`, runner `oconde-vps-toolbelt`); rollback pelo workflow `redeploy-site.yml` com o sha bom. Os apps instalados leem `/updates/latest.json` de lá: quebrar a landing quebra a atualização. Textos da landing descrevem a interface real: mudou string no app, confira a landing.
- **Falhas e feedback vão para o Radar** (projeto `toolbelt` em https://radar.oconde.dev, protocolo v1, runtime `macos`). Nada automático sem consentimento: o padrão é perguntar na primeira falha. A chave `rk_` fica no Keychain ("Toolbelt Radar key"), nunca no repositório. Detalhes em `docs/releasing.md`.
- **Compatibilidade:** todo push em `Sources/`, `Tests/` ou `Package.swift` roda `swift build`, `swift test` e abre o app por 20 s no macOS 14, 15 e 26 (workflow `compatibility.yml`). API mais nova que o macOS 14 só com `#available`. Testes locais: `memcap 3072 -- swift test`.
- Commits sem atribuição de IA; push para `origin main` quando o usuário pedir ou ao fechar uma entrega.

## Verificação rápida

```bash
scripts/install.sh && tail -3 ~/Library/Logs/Toolbelt.log
footprint $(pgrep -x Toolbelt) | grep phys_footprint
cca && macscan --json | head -c 200
```
