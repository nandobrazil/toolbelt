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

## A cada versão

1. Suba `VERSION` (semver) e escreva a seção `## <versão>` no `CHANGELOG.md`; cada linha `- ` vira uma nota no aviso de atualização.
2. Commit.
3. `scripts/release.sh`: build universal (arm64 + x86_64, `memcap` de 4 GB), monta o bundle, assina com hardened runtime e timestamp, notariza e grampeia o app, gera o DMG (também assinado, notarizado e grampeado), o zip de atualização e o `dist/latest.json` com SHA-256.
4. `scripts/publish-release.sh`: cria a release `v<versão>` em `toolbelt-releases` com o DMG versionado, `Toolbelt.dmg` (nome fixo do `/download`), o zip e o `latest.json`; cria e envia a tag `v<versão>`; confere que o feed já anuncia a versão nova.

Variáveis opcionais: `TOOLBELT_RELEASE_IDENTITY`, `TOOLBELT_NOTARY_PROFILE` (padrão `toolbelt-notary`), `TOOLBELT_RELEASES_REPO`, `TOOLBELT_DOWNLOAD_BASE_URL`, `TOOLBELT_SITE_URL`, `TOOLBELT_BUILD_MEMORY_MB`.

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
