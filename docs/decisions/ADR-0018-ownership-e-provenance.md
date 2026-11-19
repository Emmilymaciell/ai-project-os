# ADR-0018 — Ownership & provenance: informativa, por nome, com assinatura SSH

- **Data:** 2026-10-12
- **Status:** Aceita
- **Base:** pedido da titular no programa final do vNext (§13–§16: capacidade permanente de
  propriedade/proveniência, assinatura criptográfica, todo projeto novo nasce protegido);
  especificação em `docs/vnext/SPEC-OWNERSHIP-NOVO-PROJETO.md`; revisão independente r8.

## Contexto

A titular pediu que autoria, proveniência e titularidade declarada fossem verificáveis, auditáveis e
redundantes, sem prometer o impossível (impedir remoção) e sem nunca reivindicar código de terceiro.
O motor já tinha uma escada de portabilidade L0–L6 com semântica fechada (ADR-0014): cada nível é
uma pergunta operacional ("posso apagar a pasta?", "posso trocar de computador?").

## Decisões

1. **Ownership é dimensão INFORMATIVA, fora da escada L0–L6.** `eos check` e `eos status` mostram o
   resultado (`own`), mas ele não muda nível, segurança nem código de saída. Motivo: titularidade não
   responde às perguntas operacionais da escada, e um FAIL de proveniência (ex.: forense em aberto)
   não pode bloquear backup nem restauração. Teste: `TestEscadaIntocada`.
2. **Identidades declaradas por NOME no registry.** E-mail de pessoa é dado pessoal; o hook de
   segurança da plataforma o barra em arquivo versionado. O `ownership-check` casa autor do histórico
   por nome **ou** e-mail, e lê o histórico **sem** `.mailmap` (um `.mailmap` não pode transformar um
   intruso na titular). O certificado grava o nome e o SHA-256 do e-mail, nunca o e-mail em claro.
3. **O certificado vive fora do projeto.** `99 RECOVERY/manifests/<id>/ownership-<ts>.json` no Drive e
   o journal da máquina; nada no working tree. `ownership-certify --tag` cria tag ASSINADA.
4. **Contexto contratual não é autoria.** Quando há `employer_or_client`, o `OWNERSHIP.md` declara que o
   OS registra autoria, custódia e proveniência, e que a titularidade patrimonial segue o vínculo
   (ex.: Lei 9.609/1998, art. 4) — o OS não decide isso.
5. **Assinatura SSH, chave sem passphrase — risco ACEITO.** A chave `id_ed25519_git_signing` não tem
   passphrase para que commits feitos por agentes não travem em prompt. Consequência registrada: a
   assinatura prova "este perfil de usuário nesta máquina", não "esta pessoa digitou". A proteção é a
   do perfil do Windows. A chave privada **não** é copiada para backup: em máquina nova gera-se outra e
   registra-se a pública no GitHub; as assinaturas antigas continuam verificáveis enquanto a pública
   antiga estiver cadastrada. Revisitar se a titular quiser passphrase + ssh-agent.
6. **Proteção server-side indisponível no plano atual.** Branch protection e rulesets em repositório
   privado exigem GitHub Pro (HTTP 403 em 2026-10-12). O `CODEOWNERS` é declarativo, e a proteção
   continua client-side (ADR-0011).

## Consequências

- Todo PROJECT do registry tem seção `ownership`; `eos new` a gera no nascimento; `eos ownership-init`
  gera os arquivos que faltam em projeto existente sem sobrescrever nada.
- Proveniência em apuração (ex.: `engenharia-rodoviaria`) fica registrada como tal, com a evidência
  no Drive e não transcrita no registry.
