# 14 — Human gates

Um *human gate* é um ponto em que o Claude **para em estado seguro** e precisa de você. Fora desses
cinco casos, ele **não** para: não pergunta se deve continuar, não pede confirmação de decisão já
registrada, não pede para você escolher detalhe técnico reversível.

## 1. Os cinco gates

| Gate | Nome | Quando | Exemplos reais |
|---|---|---|---|
| **H1** | Autenticação | login, OAuth, 2FA, desbloqueio do Bitwarden, Google, GitHub ou Microsoft exigem ação humana | `gh auth login`; `rclone config reconnect gdrive:`; `/login` no Claude Code quando a sessão OAuth expira; instalar e desbloquear o Bitwarden; `gh auth refresh -s admin:ssh_signing_key` para registrar a chave de assinatura |
| **H2** | Permissão externa | o ambiente bloqueou uma operação e só uma aprovação explícita libera | o `gh repo create` dos projetos extraídos do acervo Dynatest, negado pela permissão do ambiente em 2026-10-11 (liberado em 2026-10-12: eles têm remoto privado); no `eos new`, a mesma negação vira `PENDENCIA HUMANA sem remoto (H2)` e o nascimento segue em L1; criar o client OAuth próprio do rclone (feito em 2026-10-16); a remoção das worktrees redundantes, das cópias duplicadas e do exe do Gerador na Fase 9, negada pelo classificador e liberada pelo "autorizo H2" da titular em 2026-10-16 |
| **H3** | Destrutivo / irreversível | apagar, limpeza permanente, sobrescrita irreversível, reescrita de histórico ou *force push* não autorizado, remoção de recovery ou de backup antigo, descarte de worktree, destruição de WIP | a sanitização de histórico de Projeto Pessoal A, Semanal, Repositório Jurídico e Organização SharePoint; o *force push* pendente do Semanal; a Fase 9 (limpeza), autorizada pela titular em 2026-10-15 e executada com prova; apagar a máquina antiga |
| **H4** | Decisão material da titular | duas ou mais alternativas plausíveis, sem evidência suficiente para escolher com segurança, com mudança material | categoria PROG das automações do acervo Dynatest; Empresa X Gestão como projeto próprio; GRD Certificadora como PROJECT ou ARCHIVE; a proveniência de `engenharia-rodoviaria` (decidida em 2026-10-15, opção C); os dados Escritório Jurídico no Drive pessoal (decidido em 2026-10-16: manter) |
| **H5** | Incidente de segurança | segredo real versionado, credencial exposta, suspeita de comprometimento, token no histórico | um token do rclone que apareceu num log temporário (pendência T-09): a correção é refazer o login, que rotaciona o token (feito em 2026-10-16, com o client OAuth próprio) |

**Git destrutivo pedido a um agente não vira gate: é barrado.** O guarda `PreToolUse` do plugin
`os` 0.1.4 (`hooks/guarda_git.py`) bloqueia `checkout --`, `reset --hard`, `push --force` e afins
nas ferramentas do Claude. Quem quiser a operação a roda no próprio terminal (`! git ...`).
Desde 2026-10-16 ele **está ativo** (plugin `0.1.4`; o guarda roda a partir da worktree principal da plataforma; teste ao vivo bloqueou `git checkout --` e
liberou `git status`). O andamento das revisões independentes dele (QA + Security)
fica no `docs/STATE.md` (`docs/runbooks/hooks.md`).

## 2. O que você recebe

Sempre neste formato:

```
HUMAN ACTION REQUIRED

Gate: H3
Reason: <por que a ação exige você>
Exact action for Emmily: <a ação exata, com o comando ou a resposta esperada>
What I have already protected: <o que já está salvo, onde, e como foi verificado>
What will continue automatically afterward: <o que o Claude faz depois que você agir>
```

Você responde com a ação feita (*"fiz o login"*) ou com a decisão (*"aprovo a opção B"*,
*"não autorizo"*). O Claude reconcilia o estado e **continua de onde parou**, sem recomeçar.

## 3. H3 em detalhe: a ordem universal

Toda ação destrutiva segue esta ordem, e nenhum passo é pulado:

```
DISCOVER → PROTECT → COPY → VERIFY → REGISTER → SWITCH → CERTIFY → CLEANUP
```

Antes de pedir sua aprovação num H3, o Claude tem de mostrar:

| Item | Exemplo |
|---|---|
| por que parece redundante ou necessário | *"clone antigo de 2024, mesmo HEAD do remoto"* |
| onde está a cópia protegida | *"bundle em `99 RECOVERY/git-recovery/<id>/<carimbo>/`"* |
| como foi verificada | *"hash conferido; restore certificado em <data>"* |
| espaço recuperável | *"1,9 GB"* |
| risco | *"nenhum arquivo só nesta pasta, segundo `eos check`"* |
| rollback | *"`eos restore <id> --para <pasta>`"* |

Proteção e rollback são **provados antes**, não prometidos. Nunca: `git reset --hard`, `git clean`
destrutivo, reescrever histórico sem plano aprovado, `push --force` não autorizado, descartar branch
ou worktree, transformar WIP em commit só para "deixar limpo".

## 4. O que **não** é gate (o Claude segue sozinho)

- iniciar a próxima fase não destrutiva de um trabalho já autorizado;
- rodar testes, diagnósticos, `eos check`, `eos status`, `eos backup`, `eos certify`, `eos restore`
  para pasta nova;
- escolher um detalhe técnico reversível (nome de variável, estrutura de um teste);
- corrigir um bug achado pelos próprios testes, dentro do escopo autorizado;
- informar progresso.

E o que **também não é gate, mas exige pedido explícito seu** pela regra de ouro: commit, tag e
push. A diferença: gate é o Claude parar e pedir; commit é o Claude **esperar** você pedir.

## 5. Como um gate aparece nos fluxos

| Fluxo | Gate provável |
|---|---|
| criar projeto | H2 (criar repositório), H1 (login expirado), H4 (classificação ambígua) |
| trocar de computador | H1 (todos os logins da máquina nova, chave de assinatura), H3 (apagar a antiga) |
| restore por cima de pasta existente | H3 (o motor recusa; o Claude restaura em pasta nova e pede a troca) |
| push de histórico com dado de terceiro | H3 (sanitizar) e, se houver segredo, H5 |
| limpeza de disco ou de backups antigos | H3 |
| segredo encontrado | H5, depois H3 para sanitizar |

## 6. Permissões do Claude Code

O Claude não tenta contornar um pedido de permissão legítimo do Claude Code e não recomenda modos que
pulam permissões. Se uma operação legítima e repetitiva gerar pedidos demais, ele propõe uma regra de
permissão **mínima e específica**, nunca uma liberação ampla "para ir mais rápido".
