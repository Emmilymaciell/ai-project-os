# ADR-0005 — Implementar 5 das 11 skills na Fase 1

- **Data:** 2026-09-05
- **Status:** Aceita
- **Fase:** 1 (bloco G)

## Contexto

O handoff (`docs/VISION.md`, §6 e §10) prevê 11 skills: `new-project`, `resume`, `checkpoint`, `project-doctor`, `handoff`, `release`, `portfolio`, `export-project`, `security-audit`, `knowledge-sync`, `project-orchestrator`.

Implementar as 11 na Fase 1 é possível. Mas o próprio handoff avisa, duas vezes, contra o oposto disso: *"Nao criar complexidade so por estetica"* (§6) e *"Implementar em etapas, nao tudo no MVP"* (§29).

## Decisão

Fase 1 entrega **5 skills**, escolhidas por um critério só: **sustentar o ciclo de vida mínimo de um projeto que sobrevive à perda do chat.**

| Skill | Por que é da Fase 1 |
|---|---|
| `new-project` | Sem ela não nasce projeto no padrão novo |
| `resume` | É a prova do princípio "projeto ≠ sessão" |
| `checkpoint` | Sem ela não há histórico verificado |
| `status` | É como a Emmily se orienta sem depender do chat |
| `handoff` | É o contrato de portabilidade |

Adiadas, com a fase de destino:

| Skill | Fase | Por quê |
|---|---|---|
| `project-doctor` | 2 | Diagnostica contra um padrão que precisa primeiro existir e ser exercitado |
| `security-audit` | 2 | Precede o push dos repos existentes, que é da Fase 2 |
| `eval` | 2–3 | Sem comportamento probabilístico implementado, seria eval sem sujeito |
| `project-orchestrator` | 3 | Na Fase 1 a orientação proativa vive no `CLAUDE.md`; vira skill quando houver casos reais para calibrar |
| `knowledge-sync` | 4 | Depende de n8n, Notion e Obsidian |
| `release`, `portfolio`, `export-project` | 5 | Dependem de tests, evals, CI e sanitização |

## Alternativas consideradas

- **As 11 agora.** Rejeitada: seis delas dependeriam de infraestrutura inexistente (CI, evals, n8n, Notion). Seriam escritas contra suposições, não contra a realidade — e reescritas depois.
- **Só `new-project` e `checkpoint`.** Rejeitada: sem `resume` e `handoff`, o princípio central da plataforma fica sem demonstração e a Fase 1 não pode ser validada.

## Consequências

- Positiva: cada skill nasce contra um uso real.
- Positiva: a Fase 1 termina em algo testável de ponta a ponta.
- Negativa: `/os:doctor`, `/os:release` etc. não existem por um tempo. Mitigada: o `README.md` marca a fase de cada comando, e quem invocar um comando ainda não implementado recebe a resposta de qual fase o traz.
