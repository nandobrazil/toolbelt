# Toolbelt: instruções para agentes

Leia `README.md` (arquitetura) e `docs/progress.md` (estado, decisões, pendências) antes de mexer.

## Regras do projeto

- **Leveza é requisito.** O app roda o tempo todo; hoje ~15 MB de footprint e 0% de CPU parado. Nada de polling quando existir gatilho (FileWatcher, notificações do NSWorkspace, timer para o próximo evento). Medir com `footprint $(pgrep -x Toolbelt)` depois de mudanças.
- **Build só pelo `scripts/install.sh`** (usa `memcap`). Build avulso: `memcap 2048 -- swift build -c release`. Nunca build sem teto no Mac (há um hook que bloqueia).
- **Não trocar a assinatura para ad-hoc.** O certificado "Toolbelt Local Signing" mantém as permissões entre builds.
- **Sem comentários no código**, nomes em inglês; textos da interface em português.
- **Não simular cliques/teclas na tela do usuário para testar.** Ele costuma estar em tela cheia (vídeo, outros apps) e um clique sintético já caiu no conteúdo dele. Para conferir: AX (ler títulos dos itens), `screencapture` só da faixa da barra, logs e `footprint`. Peça ao usuário para testar interações.
- **Configurações**: todo campo novo entra em `AppSettings.swift` com `init(from:)` tolerante (`decodeIfPresent ?? default`), senão configurações antigas quebram. Para mudar configuração por fora, pare o app (`launchctl bootout gui/$(id -u)/dev.oconde.toolbelt`), edite `settings.v1` via `defaults export/import` e suba de novo; com o app vivo ele sobrescreve.
- **Módulo novo**: implementar `ToolbeltModule` (start/stop/settingsDidChange/menuItems), registrar em `AppController.modules`, página em `SettingsView`, `SettingsSection` correspondente. Item próprio na barra precisa de posição padrão em `AppController.defaultItemPositions`, senão nasce atrás do notch.
- **Conflitos de atalho**: Flycut, Ice e AltTab originais foram fechados (não desinstalados) porque usavam os mesmos atalhos/função.
- Commits sem atribuição de IA; push para `origin main` quando o usuário pedir ou ao fechar uma entrega.

## Verificação rápida

```bash
scripts/install.sh && tail -3 ~/Library/Logs/Toolbelt.log
footprint $(pgrep -x Toolbelt) | grep phys_footprint
cca && macscan --json | head -c 200
```
