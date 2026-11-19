# evals/ — vazio de propósito

Esta pasta está vazia porque **ainda não há comportamento probabilístico a medir** nesta plataforma.

Hoje o Project OS é: manifestos, documentação, template e scripts determinísticos. Tudo isso é verificado em `tests/`, que é o lugar certo. Criar evals agora seria eval sem sujeito — cerimônia, não verificação.

## Quando esta pasta passa a existir de verdade

Na **Fase 3**, quando o Project Orchestrator começar a *recomendar* arquitetura de execução (main Claude, subagent, worktrees, Agent Team, Dynamic Workflow, batch). Recomendação é julgamento: a mesma entrada pode produzir saídas diferentes, e o que importa não é "rodou sem erro" e sim "recomendou bem".

O que será medido lá:

| Eval | Pergunta |
|---|---|
| `orchestrator-recomenda-modo` | Dado um problema descrito em português, o modo recomendado é razoável? |
| `orchestrator-nao-superdimensiona` | Tarefa simples continua recebendo "main Claude", e não worktrees? |
| `deteccao-de-verificacao` | Projeto com componente LLM recebe proposta de eval sem ninguém pedir? |
| `deteccao-de-sensibilidade` | Projeto que toca dado corporativo dispara security check sozinho? |

O caso mais importante é o segundo: o modo de falha mais provável de um sistema assim não é recomendar de menos, é **recomendar demais** — sugerir worktrees e Agent Teams para tarefas que pedem uma edição de arquivo.

## Regra

Nunca inventar métrica. Um eval sem critério de aprovação declarado não é eval, é impressão.
