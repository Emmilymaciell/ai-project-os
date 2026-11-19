# ADR-0019 — Exceção pública de infraestrutura: páginas do app OAuth do rclone

- **Data:** 2026-10-16
- **Status:** Aceita
- **Não altera:** o ADR-0003 (GitHub **privado por padrão**). Esta é uma exceção **específica e nomeada**,
  não uma mudança da política global. Nenhum projeto existente ou futuro fica público por causa dela.

## Contexto

O rclone passou a usar um client OAuth próprio da titular (projeto Google Cloud `emmily-os-rclone`, app
`Emmily OS rclone`), porque o client compartilhado do rclone deixa de funcionar em 2026 (ADR-0013). Em modo
*Testing*, o Google expira a autorização em cerca de 7 dias, o que quebraria backup e recovery sem aviso. Para
publicar o app (*In production*), o Google exige uma **homepage** e uma **política de privacidade** em
endereços públicos.

## Decisão

1. A titular aprovou em 2026-10-16 um repositório **público, separado e mínimo**:
   `(repositório separado de páginas OAuth)`, servido por GitHub Pages em
   `https://emmilymaciell.github.io/emmily-os-oauth-pages/`.
2. O repositório contém **somente** `index.html` (homepage), `privacy.html` (privacidade) e `.nojekyll`.
   Commits com o e-mail `users.noreply.github.com` (o e-mail pessoal não aparece) e assinados.
3. Antes do primeiro push: `security-scan.ps1 -ParaPublicacao` com histórico (ALTA 0, MEDIA 0) e busca
   explícita sem ocorrência de Client ID/secret/token, caminho local, Programa/Dynatest/clientes, e-mail pessoal,
   CPF e código do Project OS. Evidência no journal `RUN-20261008-001/CHECKPOINTS/oauth-pages-*`.
4. O repositório **não** é projeto do registry (o motor recusa `visibility: public` em contrato, e assim deve
   continuar). Ele é infraestrutura do OAuth, governado por este ADR.
5. O que nunca entra nele: credencial, Client ID, secret, token, `rclone.conf`, dado de projeto, caminho
   local. Qualquer mudança nele repete a varredura do item 3 antes do push.

## Consequências

- O app OAuth pode ser publicado, e o token do rclone deixa de expirar semanalmente.
- Auditoria: `gh repo list --json name,visibility` deve mostrar **um único** repositório não privado, este.
  Outro repositório público é desvio do ADR-0003.
- Revogar: apagar o repositório e voltar o app a *Testing* (com reautorização semanal) ou trocar de transporte
  (`drive-desktop`, ADR-0013).
