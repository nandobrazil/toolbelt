# Publicar uma versão

O Toolbelt é distribuído fora da App Store (o sandbox dela bloqueia Acessibilidade e as APIs que o alternador e a barra usam), assinado com **Developer ID** e **notarizado pela Apple**. Assim o Gatekeeper abre o app sem o aviso de "não foi possível verificar".

Onde cada coisa fica:

| O quê | Onde |
|---|---|
| Landing | `site/`, servida em https://toolbelt.oconde.dev pelo VPS de produção (namespace `toolbelt`, prioridade `production`, só aceita tráfego da Cloudflare). Push em `main` mexendo na landing gera `ghcr.io/nandobrazil/toolbelt-site:<sha7>` no GitHub Actions e o runner `oconde-vps-toolbelt` publica com `infra/deploy.sh` + `infra/smoke.sh`; rollback: Actions → Redeploy da landing com o sha bom |
| DMG, zip de atualização e `latest.json` | assets da release em https://github.com/nandobrazil/toolbelt-releases (público) |
| `/download` e `/updates/latest.json` | redirecionamentos do nginx da landing para `releases/latest/download/...` |
| Endereço que o app consulta | `ToolbeltUpdateFeedURL` no `Info.plist` = https://toolbelt.oconde.dev/updates/latest.json |

## Uma vez por máquina

1. **Certificado Developer ID Application** (exige o papel Account Holder na conta da Apple): Xcode → Settings → Accounts → selecione o time → Manage Certificates → `+` → *Developer ID Application*. Conferir: `security find-identity -v -p codesigning` lista `Developer ID Application: <nome> (<TEAMID>)`.
2. **Credencial do notarytool**: crie uma senha de app em https://account.apple.com (Login e Segurança → Senhas de app) e guarde no Keychain:
   ```bash
   xcrun notarytool store-credentials toolbelt-notary --apple-id <email da conta> --team-id <TEAMID>
   ```
   (pede a senha de app de forma interativa; nada vai para o repositório).
3. **Repositório público das releases** (só na primeira vez): `gh repo create nandobrazil/toolbelt-releases --public --description "Downloads do Toolbelt"`.
4. **Chave do Radar** no Keychain, item **"Toolbelt Radar key"** (conta `toolbelt`): é a chave `rk_…` do projeto Toolbelt em https://radar.oconde.dev, que o `release.sh` embute no app (ambiente `production`) e o `install.sh` embute nos builds locais (ambiente `development`). Sem ela o `release.sh` recusa. Nova chave: Radar → projeto Toolbelt → Configurações → Chaves, e `security add-generic-password -U -a toolbelt -s "Toolbelt Radar key" -w` (pede a chave sem ecoar).
5. **Backup do certificado:** `Toolbelt - Developer ID Application (Fernando Conde) - backup.p12` no Google Drive; a senha está no Keychain, item "Toolbelt Developer ID .p12 (Google Drive)". Para restaurar noutro Mac: abrir o `.p12` com essa senha.

## Automático: push na main

O workflow `compatibility.yml` ("Compatibilidade e release") roda a cada push na `main` que mexa no app. Primeiro a matriz macOS 14/15/26 (build, testes, app aberto por 20 s); se ela passar e o `VERSION` ainda não tiver tag `v<versão>` (e o `CHANGELOG.md` tiver a seção `## <versão>`), o job **Release** num runner `macos-26`:

1. importa o Developer ID num keychain temporário (segredos `DEVELOPER_ID_P12`, `DEVELOPER_ID_P12_PASSWORD`);
2. roda `scripts/release.sh` (build universal, assinatura, notarização com `NOTARY_APPLE_ID`/`NOTARY_TEAM_ID`/`NOTARY_PASSWORD`, DMG, zip, `latest.json`, chave `RADAR_KEY` embutida);
3. roda `scripts/publish-release.sh` com `RELEASES_TOKEN` (token fino só com Contents: read/write em `toolbelt-releases`): release pública, tag `v<versão>` no código e conferência do feed;
4. manda `release.published` ao Radar (marca a versão nova no projeto Toolbelt);
5. apaga o keychain temporário.

Para lançar: subir o `VERSION`, escrever a seção no `CHANGELOG.md`, commit e push. Push sem versão nova só testa. Os apps instalados veem a versão no feed (ao abrir, ao acordar o Mac e a cada 24 h) e mostram o aviso e a notificação.

## Manual (sem CI)

### A cada versão

1. Suba `VERSION` (semver) e escreva a seção `## <versão>` no `CHANGELOG.md`; cada linha `- ` vira uma nota no aviso de atualização.
2. Commit.
3. `scripts/release.sh`: build universal (arm64 + x86_64, `memcap` de 4 GB), monta o bundle, assina com hardened runtime e timestamp, notariza e grampeia o app, gera o DMG (também assinado, notarizado e grampeado), o zip de atualização e o `dist/latest.json` com SHA-256.
4. `scripts/publish-release.sh`: cria a release `v<versão>` em `toolbelt-releases` com o DMG versionado, `Toolbelt.dmg` (nome fixo do `/download`), o zip e o `latest.json`; cria e envia a tag `v<versão>`; confere que o feed já anuncia a versão nova.

Variáveis opcionais: `TOOLBELT_RELEASE_IDENTITY`, `TOOLBELT_NOTARY_PROFILE` (padrão `toolbelt-notary`), `TOOLBELT_RELEASES_REPO`, `TOOLBELT_DOWNLOAD_BASE_URL`, `TOOLBELT_SITE_URL`, `TOOLBELT_BUILD_MEMORY_MB`.

## Falhas, travamentos e feedback (Radar)

- Projeto **Toolbelt** em https://radar.oconde.dev/projects/toolbelt. As falhas chegam como erros (agrupados, com runtime `macos`: versão do macOS e modelo do Mac), o feedback como logs `feedback.bug` e `feedback.suggestion`.
- Alertas por e-mail e push no celular: erro novo, erro que voltou e os limites "mais de 0 `feedback.*` em 5 min" (só ambiente `production`).
- No app: `CrashReporter` lê os `.ips` do Toolbelt em `~/Library/Logs/DiagnosticReports` (só os posteriores à primeira abertura com o recurso) e os travamentos do MetricKit; o padrão é perguntar na primeira falha. `RadarClient` envia o protocolo v1 e guarda o que falhar em `~/Library/Application Support/Toolbelt/outbox`.
- Testar sem esperar uma falha: compile um programa com `fatalError` dentro de um bundle com `CFBundleIdentifier dev.oconde.toolbelt` e execute o binário; o macOS grava `Toolbelt-*.ips` e o Toolbelt, ao reabrir, oferece o envio.

## Como o app se atualiza

- Verifica 60 s depois de abrir, a cada 24 h e ao acordar o Mac (se já passou um dia). Sem polling: um único timer até a próxima verificação.
- Versão nova: bolinha azul ao lado do cinto, seção "Atualização" no painel, item no menu do clique direito, Configurações → Geral → Atualizações e uma notificação do sistema com o botão "Atualizar agora" (uma vez por versão).
- Atualizar: baixa o zip, confere o SHA-256 do `latest.json`, abre com `ditto`, exige assinatura `anchor apple generic` do mesmo Team ID e o mesmo bundle id, confere a versão, troca o bundle no lugar (`replaceItemAt`) e reabre (`--relaunch-after <pid>` espera o processo antigo sair).
- Cópia compilada localmente (assinatura "Toolbelt Local Signing", sem Team ID): o botão abre a página de download em vez de instalar.

## Conferir uma release

```bash
spctl --assess --type execute --verbose dist/Toolbelt.app
spctl --assess --type open --context context:primary-signature --verbose dist/Toolbelt-<versão>.dmg
xcrun stapler validate dist/Toolbelt-<versão>.dmg
curl -sL https://toolbelt.oconde.dev/updates/latest.json
curl -sI https://toolbelt.oconde.dev/download | grep -i location
```
