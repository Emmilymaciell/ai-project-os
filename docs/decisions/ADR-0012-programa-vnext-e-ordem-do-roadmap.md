# ADR-0012 — Programa vNext: continuidade como objetivo, e a ordem que ele impõe ao roadmap

- **Data:** 2026-10-08
- **Status:** Aceita
- **Fase:** 2 → programa vNext (`docs/vnext/PROGRAMA-VNEXT.md`)

## Contexto

Em 2026-10-08 a mantenedora entregou o programa vNext: tornar a plataforma o gerente de
continuidade de **todos** os projetos — Git/GitHub, Google Drive como plano de dados e
recovery, backup/restore, portabilidade L0–L6, registry, independência de sessão de IA.
O princípio é *sessão de IA = descartável; computador = substituível; projeto = permanente*.

O roadmap vigente (`docs/VISION.md` §30, `docs/STATE.md`) punha a 2.8 (CI) e a 2.9 (evals)
logo depois da 2.7, e integrações de arquivo (OneDrive archive) só na Fase 4.

O inventário de 2026-10-08 (journal `RUN-20261008-001`) mediu o risco que motivou o programa:
11 repositórios de trabalho **sem remoto nenhum**, 6 árvores com trabalho não commitado (5
delas worktrees do G2), um repositório sem nenhum commit, e dois bancos SQLite (914 MB e
310 MB) com cópia única neste disco.

## Decisão

1. **O programa vNext passa à frente da 2.8 e da 2.9.** Perda de projeto é risco presente e
   medido; CI e evals são qualidade sobre o que já está protegido. As duas **não foram
   canceladas**: entram depois da Fase 4 do programa (plataforma em L6), quando a CI passa a
   ter o que verificar além do código da própria plataforma.
2. **Ordem:** −1 recovery da 2.7 (feito, `15e4496`) → 0 preflight → 1 preservação de
   emergência → 2 Portability Lab → 3 core em branch `vnext` (worktree irmã) → 4 a plataforma
   em L6 → 5 registry completo → 6A/6B migrações → 7 acervos → 8 DR → 9 limpeza (só com H3).
3. **Autonomia dentro do programa.** Commit e push **não destrutivos** sem pedido a cada vez,
   desde que: conteúdo revisado, portões previstos verdes, varredura de segredo limpa, remoto
   validado e privado. As proibições do `CLAUDE.md` continuam **todas** de pé — `reset --hard`,
   `clean`, `rebase`, `amend`, `push --force`, descarte de branch/worktree e qualquer exclusão
   exigem pedido explícito (gate H3). Repositório novo no GitHub nasce **privado**.
4. **Human gates** são só os cinco do programa (H1 autenticação, H2 consentimento externo, H3
   destrutivo, H4 ambiguidade material, H5 incidente). Fora deles a execução não para.
5. **O journal do programa vive fora do repositório** (`C:\AI-WORKSPACE\_platform\_runs\`), e é
   replicado no Drive. Ele registra *execução*; decisão continua indo para ADR e estado para
   `docs/STATE.md`. Journal não é fonte de verdade de decisão.
6. **Workspace físico: mantém-se o do ADR-0001** (`work/prog`, `ai-lab/`, …). O programa
   descreve a árvore como *conceitual* e proíbe mover projeto "para ficar bonito". Categoria é
   atributo **lógico** do registry; caminho local é atributo **da máquina**. Mudar nomes de pasta
   agora seria churn sem ganho de proteção.

## Alternativas consideradas

- **Terminar a Fase 2 (2.8, 2.9) antes.** Rejeitada: deixaria 11 repositórios sem cópia fora
  da máquina por mais semanas para melhorar a verificação de um único repositório que já está
  protegido.
- **Executar o programa no `main`.** Rejeitada pelo próprio programa (§28) e pela prudência:
  o `main` sustenta os hooks e as skills em uso diário; o core novo fica em `vnext` até passar
  pelos portões.
- **Adotar a árvore conceitual do programa (`prog/`, `lab/`) já.** Rejeitada pelo item 6.

## Consequências

- O `docs/STATE.md` ganha a seção do programa; `VISION.md` não é reescrito — continua sendo a
  especificação original, e este ADR registra o desvio de ordem.
- O ADR-0003 é **estendido**, não revogado, pelo ADR-0013: o lugar de backup de dados deixa de
  ser `OneDrive\AI-ARCHIVE` e passa a ser o Google Drive.
- Risco aceito: execução longa e autônoma acumula decisões. Mitigação: toda decisão material vira
  ADR antes de virar código, e o journal permite auditar a sequência.
