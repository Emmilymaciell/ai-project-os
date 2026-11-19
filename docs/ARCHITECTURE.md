# ARCHITECTURE — Emmily AI Project OS

> **Desde o vNext (2026-10), a referência técnica completa e conferida contra o código é
> [`architecture/EMMILY-AI-PROJECT-OS-TECHNICAL-REFERENCE.md`](architecture/EMMILY-AI-PROJECT-OS-TECHNICAL-REFERENCE.md);
> o guia de uso é [`user/README.md`](user/README.md).** Este arquivo continua como visão de princípios
> (camadas, decisores, builder ≠ evaluator); onde divergir do motor, vale a referência técnica.

## 1. O que este repositório é

Uma **plataforma que governa outros repositórios**. Ele não produz nenhum artefato de trabalho: produz estrutura, procedimento e verificação para os projetos que produzem.

Consequência prática: quase tudo aqui é texto lido por um modelo (skills, agents, templates, ADRs) e uma minoria é código executado (scripts de bootstrap, doctor e hooks). Isso muda o que significa "testar" — ver seção 6.

## 2. Papel de cada sistema

| Sistema | Papel | O que **não** é |
|---|---|---|
| **Git** | Fonte de verdade do histórico | Não é backup (é local) |
| **Git GUI / gitk** | Inspeção visual do histórico | Não é o motor do versionamento |
| **GitHub** | Remoto, branches, PRs, releases, Actions; backup off-machine **do conteúdo versionado** | Não é backup de dados ignorados, artefatos locais nem trabalho não commitado — ver ADR-0003 |
| **Claude** | Raciocínio, implementação, coordenação | Não é fonte de estado |
| **Notion** | Gestão visual, banco de projetos, roadmap | Não é fonte de verdade técnica |
| **Obsidian** | Conhecimento local em Markdown, backlinks | Não é gestão |
| **n8n** | Integração e orquestração de eventos | Não decide nada |
| **Google Drive** (`EMMILY PROJECT CLOUD/`, via rclone) | Plano de dados e recovery do vNext: bundles, WIP, bancos, dados fora do Git, certificados (ADR-0013, ADR-0015) | Não é fonte do código: o Git é |
| **OneDrive** | Origem legada de acervos e de alguns projetos | Não é backup do OS e não hospeda working tree novo (ADR-0001, ADR-0002, ADR-0016) |
| **Motor `eos`** (`py -3.13 -m eos`) | Registry, contratos, backup, restore, certificação L0–L6, ownership, nascimento protegido | Não guarda estado na conversa |

Direção de sincronização preferida (Fase 4): `REPO → n8n → Notion` e `REPO → n8n → Obsidian`. Bidirecional irrestrito, não.

## 3. Camadas

```
┌───────────────────────────────────────────────────┐
│  SKILLS     /os:*  — superficie E procedimento     │
│             (skills/<nome>/SKILL.md)               │
├───────────────────────────────────────────────────┤
│  AGENTS     papéis cognitivos com contexto isolado │
├───────────────────────────────────────────────────┤
│  TEMPLATES  o esqueleto dos projetos governados    │
├───────────────────────────────────────────────────┤
│  SCRIPTS    determinismo: bootstrap, doctor        │
├───────────────────────────────────────────────────┤
│  HOOKS      política que não depende de lembrar    │
└───────────────────────────────────────────────────┘
```

Regra de alocação: **se depende de julgamento, é skill ou agent. Se é sempre igual, é script. Se não pode ser esquecido, é hook.**

Uma skill de plugin **é** o comando: `skills/status/SKILL.md` num plugin chamado `os` já se invoca como `/os:status`. Não existe camada de `commands/` nesta plataforma — ver ADR-0004.

O erro clássico é implementar como skill algo que deveria ser hook — aí a política passa a depender de o modelo lembrar dela. A regra de ouro do commit é o exemplo: ela continua sendo texto no `CLAUDE.md` (os hooks da Fase 2 validam mensagem, segredo e pré-push, mas não decidem *quando* commitar).

## 4. Distribuição: por que plugin

As skills poderiam morar em `.claude/skills/` de cada projeto. Não moram, por dois motivos:

1. `/os:new-project` precisa funcionar **onde o projeto ainda não existe**. Uma skill local a um projeto não pode criar esse projeto.
2. Duplicar as skills por projeto significa 12 cópias divergindo. O plugin dá uma origem única e versionada.

O empacotamento como plugin (`.claude-plugin/plugin.json` com `"name": "os"`) é o que produz o namespace `/os:*` e o torna disponível em qualquer pasta. O marketplace local (`.claude-plugin/marketplace.json`) é como o Claude Code encontra o plugin sem depender de um repositório remoto — o que mantém a plataforma funcional **antes** de existir GitHub e **offline**.

## 5. Dois decisores distintos

- **Project Orchestrator** decide *como conduzir o trabalho*: main Claude, subagent, subagentes paralelos, worktrees, Agent Team, Dynamic Workflow ou batch.
- **Architect** decide *como estruturar o produto*: módulos, dependências, dados, interfaces.

Confundir os dois é o que leva a "usar worktree porque é legal". A arquitetura de execução deve ser **reavaliada quando o projeto cresce**, não escolhida uma vez.

## 6. Verificação

**A política é `docs/VERIFICATION-POLICY.md`.** Ela é a fonte: define o que conta como verificado, mapeia natureza do trabalho para tipo de verificação, e amarra rigor a criticidade. Nada aqui repete aquele conteúdo.

O que esta seção acrescenta é onde a plataforma se aplica a si mesma:

| Natureza, nesta plataforma | Onde |
|---|---|
| Código determinístico (`bootstrap.ps1`, scanner, `doctor`) | `tests/suites/` |
| Comportamento probabilístico (o Orchestrator recomendando arquitetura) | `evals/` — **a partir da Fase 3**, quando o sujeito existir |
| Integração externa (`gh`, n8n, Notion) | integration test + mock |
| Estrutura instanciada pelo template | teste de instanciação, em `suites/template.ps1` |
| Exposição de dados | `suites/security.ps1` + `/os:security` |

## 7. Builder ≠ Evaluator

```
Architect/Planner → Builder → Tests/Evals → QA independente → Security → Human Review
```

**Quando este fluxo é obrigatório está em ADR-0007**, derivado de `classificacao.criticidade`: `baixa` dispensa, `media` exige QA, `alta` exige QA e security, e `dados_sensiveis: true` força QA e security qualquer que seja a criticidade.

O mecanismo é **contexto isolado**, e a ignorância do revisor é o instrumento, não um efeito colateral: se ele souber que algo já foi testado, não testa. É por isso que `qa-reviewer` e `security-reviewer` são agentes separados, e não uma seção do prompt de quem constrói.

A plataforma se submete à própria regra: a partir da subfase 2.3, cada subfase da Fase 2 passa pelos revisores construídos na 2.2.

## 8. Níveis de autonomia

| Nível | O que é permitido |
|---|---|
| 0 | Somente ler |
| 1 | Analisar e sugerir |
| 2 | Editar local |
| 3 | Executar scripts e testes |
| 4 | Preparar commit |
| 5 | Branch, push, PR |
| 6 | Escrever em serviço externo |
| 7 | Deploy / operação sensível |

**Nível corrente: 4.** Editar e preparar commit, sim; commitar só com pedido explícito; push só com aprovação (bloco H eleva pontualmente a 5).

## 9. Estado e memória

| Camada | Papel | Confiabilidade |
|---|---|---|
| `docs/STATE.md` | Onde o projeto está | Fonte de verdade operacional |
| `docs/decisions/` | Por que está assim | Fonte de verdade das decisões |
| `CLAUDE.md` | Como trabalhar aqui | Permanente e curto |
| `CHANGELOG.md` | O que mudou entre versões | Derivado dos checkpoints |
| `docs/sessions/SESSIONS.md` | O que aconteceu em cada sessão | Histórico append-only, escrito pelo `/session-close` |
| Auto Memory do Claude | Atalho de contexto | **Apoio. Nunca fonte única de nada crítico.** |
| Histórico do chat | Conveniência | Descartável por definição |

## 10. Portabilidade

Contrato: outra pessoa, conta ou máquina deve conseguir assumir. Isso exige, em todo projeto relevante: `SETUP.md`, dependências declaradas, `.env.example`, `bootstrap`, `doctor`, ADRs, `STATE.md` e as skills/agents específicos versionados junto.

`/os:export-project` (Fase 5) empacota isso removendo segredos, caches e dados proibidos, e gera o `HANDOFF.md`.
