🇺🇸 [English](README.en.md)

<p align="center">
  <img src="docs/images/icon.png" width="128" height="128" alt="Ícone do Toolbelt: uma fivela dourada com a ponta de um cinto de couro">
</p>

<h1 align="center">Toolbelt</h1>

<p align="center">
  <b>Seis utilitários de barra de menus num único app de ~13 MB para macOS.</b><br>
  Ícones escondidos atrás do notch, alternador de janelas, histórico da área de transferência,<br>
  atalhos de janela, monitor do sistema e contas do Claude Code.
</p>

<p align="center">
  <a href="https://toolbelt.oconde.dev/download"><b>⬇︎ Baixar para macOS</b></a>
  &nbsp;·&nbsp;
  <a href="https://toolbelt.oconde.dev">Site</a>
  &nbsp;·&nbsp;
  <a href="CHANGELOG.md">Novidades</a>
</p>

<p align="center">
  <img alt="macOS 14 ou mais recente" src="https://img.shields.io/badge/macOS-14%2B-111?logo=apple&logoColor=white">
  <img alt="Apple Silicon e Intel" src="https://img.shields.io/badge/Apple%20Silicon%20%2B%20Intel-universal-111">
  <img alt="Notarizado pela Apple" src="https://img.shields.io/badge/notarizado-Developer%20ID-2ea44f">
  <img alt="Versão 0.2.1" src="https://img.shields.io/badge/vers%C3%A3o-0.2.1-C98446">
  <img alt="Licença GPL-3.0" src="https://img.shields.io/badge/licen%C3%A7a-GPL--3.0-2b6cb0">
</p>

---

## Instalação

Pelo [Homebrew](https://brew.sh):

```bash
brew install --cask nandobrazil/tap/toolbelt
```

Se o Homebrew avisar que o tap não é confiável, rode `brew trust --tap nandobrazil/tap` uma vez.

Ou à mão:

1. **Baixe** o [Toolbelt.dmg](https://toolbelt.oconde.dev/download).
2. **Abra o DMG e arraste** o Toolbelt para a pasta Aplicativos.
3. **Abra o Toolbelt.** O cinto aparece na barra de menus. Quando o macOS pedir, libere em **Ajustes do Sistema → Privacidade e Segurança → Acessibilidade**.

Pronto. O app é assinado com Developer ID e notarizado pela Apple, então abre sem aviso de software não verificado. Ele entra nos Itens de Início e se atualiza sozinho: quando sai versão nova, aparece um aviso no painel do cinto e uma notificação com o botão **Atualizar agora**.

> **Vindo do AltTab, Ice/Bartender, Flycut ou Rectangle?** Feche-os antes (não precisa desinstalar): os atalhos e a função são os mesmos e um rouba o atalho do outro.

**Requisitos:** macOS 14 Sonoma ou mais recente, Apple Silicon ou Intel. As contas do Claude e o relatório completo do sistema usam `python3` (vem com as Ferramentas de Linha de Comando do Xcode).

**Desinstalar:** feche pelo menu do cinto (**Sair do Toolbelt**) e apague o app de Aplicativos. As configurações ficam em `~/Library/Preferences/dev.oconde.toolbelt.plist` e o histórico em `~/Library/Application Support/Toolbelt`.

## O que vem no cinto

| | Módulo | O que faz |
|---|---|---|
| 🧷 | **Barra de menus** | Esconde os ícones que não cabem (inclusive os que somem atrás do notch) e mostra todos num painel abaixo do cinto. Ao lado do cinto, opcionalmente: conta e uso do Claude, RAM, swap ou disco livre. ⌥ clique organiza a barra. |
| 🪟 | **Alternar janelas** | ⌥⇥ mostra todas as janelas abertas, com ⇧ para voltar. Também aceita ⌘⇥, substituindo o alternador do macOS enquanto o Toolbelt estiver aberto. ⌥\` alterna só entre as janelas do app atual. `/` busca; W fecha a janela, M minimiza, H esconde o app e Q fecha o app. Miniaturas opcionais. |
| 📋 | **Área de transferência** | ⌥⌘V abre o histórico de textos, imagens e prints sem tirar o foco do app em que você está; um clique cola. Ignora apps escolhidos (gerenciadores de senha) e, se quiser, guarda um arquivo `.md` por dia. |
| ▦ | **Janelas** | Atalhos ⌃⌥ estilo Rectangle: metades, terços, cantos, maximizar, centralizar e mover entre monitores, com espaçamento configurável. |
| 📈 | **Monitor do sistema** | RAM, swap e disco livres, com alertas quando a memória aperta ou o disco enche, e um relatório completo (bateria, armazenamento, CPU, processos, segurança, rede). |
| ✳︎ | **Contas do Claude** | Várias contas do Claude Code lado a lado, com o uso da janela de 5 h e da semana, um selo colorido por conta e um terminal já preso a cada uma. |

Cada módulo liga e desliga em **Configurações → Geral**, e todo atalho pode ser regravado.

### Atalhos padrão

| Ação | Atalho |
|---|---|
| Alternar entre todas as janelas | ⌥⇥ (ou ⌘⇥, se você escolher) |
| Alternar entre as janelas do app atual | ⌥\` |
| Histórico da área de transferência | ⌥⌘V |
| Metade esquerda / direita / de cima / de baixo | ⌃⌥ ← → ↑ ↓ |
| Maximizar · centralizar | ⌃⌥ ↩ · ⌃⌥ C |
| Terços: primeiro · meio · último | ⌃⌥ D · F · G |
| Dois terços: à esquerda · à direita | ⌃⌥ E · T |
| Cantos | ⌃⌥ U · I · J · K |
| Próximo · anterior monitor | ⌃⌥⌘ → · ⌃⌥⌘ ← |

## Leve de verdade

O Toolbelt fica aberto o dia todo, então cada megabyte conta: **~13 MB de memória e 0% de CPU parado**. Ele não fica perguntando nada de tempos em tempos. Reage a eventos do sistema (arquivos mudando, apps abrindo, a próxima hora de reset do Claude) e dorme no resto do tempo.

## Privacidade

Tudo fica no seu Mac: sem conta, sem telemetria, sem analytics. O app só usa a internet para:

- **Atualizações:** uma consulta por dia a `toolbelt.oconde.dev/updates/latest.json` (dá para desligar em **Configurações → Geral → Atualizações**). Cada atualização baixada tem o SHA-256 e a assinatura conferidos antes de substituir o app.
- **Relatórios de falha, só com a sua permissão:** quando o Toolbelt fecha ou trava, ele pergunta se pode mandar o relatório técnico (tipo do erro, onde falhou, versão do app e do macOS, modelo do Mac). Você escolhe **Enviar**, **Sempre enviar** ou **Agora não**, e muda depois em **Configurações → Ajuda e relatórios**.
- **Relatar um problema ou sugestão:** pelo menu do cinto, com prévia exata do que vai ser enviado. O e-mail é opcional.

Nada do que você copia, abre ou digita sai do Mac.

## Permissões

| Permissão | Para quê | Obrigatória |
|---|---|---|
| Acessibilidade | Colar, mover janelas, abrir ícones escondidos e alternar janelas | Sim |
| Gravação de Tela | Só para as miniaturas do alternador (desligadas por padrão) | Não |
| Notificações | Alertas do monitor e aviso de atualização | Não |
| Automação (Terminal) | Abrir o Terminal já logado numa conta do Claude | Não |

## Para desenvolvedores

```bash
git clone https://github.com/nandobrazil/toolbelt.git && cd toolbelt
scripts/create-signing-identity.sh
scripts/install.sh
```

O `create-signing-identity.sh` cria uma vez o certificado local, que mantém as permissões entre builds. O `install.sh` compila em release (Swift 5.9, sem dependências), monta `~/Applications/Toolbelt.app` e abre o app; com um certificado Developer ID no Keychain, assina com ele e instala em `/Applications`.

- [Arquitetura e módulos](docs/architecture.md)
- [Como publicar uma versão](docs/releasing.md): Developer ID, notarização, DMG e atualização automática
- [Estado e decisões](docs/progress.md)
- [Landing e prévia do app](docs/landing.md)

Contribuições são bem-vindas: abra uma issue para bugs e ideias, ou um pull request. Os testes (`swift test`) rodam no macOS 14, 15 e 26 a cada mudança. Falhas e sugestões também podem ser enviadas de dentro do app, em **Configurações → Ajuda e relatórios**.

## Licença

[GPL-3.0](LICENSE): use, estude, modifique e redistribua à vontade; versões modificadas distribuídas precisam manter o código aberto sob a mesma licença. O nome "Toolbelt" e o ícone identificam este projeto.

<p align="center"><sub>Feito por Fernando Conde · © 2026</sub></p>
