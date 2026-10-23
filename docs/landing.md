# Landing e prévia do app

A landing (https://toolbelt.oconde.dev, `site/index.html` em português e `site/en/index.html` em inglês) é a vitrine do app: as imagens, a janela de Configurações em modal e os textos precisam mostrar o app **como ele é na versão publicada**.

## Regra

Toda feature ou correção (hotfix) que muda algo visível ou descrito na landing atualiza a prévia **na mesma entrega**, antes ou junto do commit que sobe o `VERSION`:

- tela, painel, menu, notificação ou texto da interface novo ou alterado;
- atalho padrão, comportamento ou fluxo descrito nas seções e nas legendas "como funciona";
- página nova ou alterada nas Configurações (o modal da landing tem uma página por seção do app);
- requisito, instalação ou permissão.

Correção sem mudança visível: só conferir se os textos da landing continuam verdadeiros.

## Como atualizar

1. Instale o build com a mudança: `scripts/install.sh`.
2. Gere as imagens nas duas línguas: `scripts/landing-screenshots.sh` (renderiza a interface real fora da tela, com dados de exemplo, em `site/assets/shots/pt` e `site/assets/shots/en`). Seção nova nas Configurações entra também no modal da landing.
3. Revise os textos em português e em inglês (`site/index.html`, `site/en/index.html`), as legendas "como funciona" e, se mudou instalação ou recurso, os READMEs (`README.md`, `README.en.md`).
4. Suba o carimbo `?v=` do CSS e do JS e o `data-shots-version` do modal (os três com o mesmo valor) sempre que mudar CSS, JS ou imagens: o nginx deixa o navegador guardar CSS e JS por 1 h e imagens por 7 dias.
5. Confira no Chrome headless: desktop, 390 px de largura, claro e escuro, sem rolagem horizontal em 360 px.
6. Commit e push na `main`: o workflow `deploy-site.yml` publica a landing em produção.

## Nunca

- Citar outros apps (concorrentes ou os que o Toolbelt substitui) na landing.
- Usar prints da tela do usuário ou simular cliques e teclas para gerar imagens: só a renderização fora da tela.
- Dados pessoais nos exemplos (contas, e-mails, conteúdo copiado): use `pessoal / you@example.com` e textos neutros.
- Prometer na landing o que a versão publicada ainda não faz.
