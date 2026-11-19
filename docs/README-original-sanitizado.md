# Emmily AI Project OS

Sistema operacional pessoal de desenvolvimento assistido por IA.

Padroniza como qualquer projeto da Emmily é criado, desenvolvido, testado, versionado, documentado, compartilhado, atualizado, arquivado e transformado em portfólio — para trabalho, faculdade, automações, IA, engenharia, aplicativos, scripts e pesquisa.

## O problema que ele resolve

Antes: cada projeto era reinventado do zero, o estado vivia no histórico do chat, o backup era um ZIP na pasta pessoal, e saber *quando* usar subagente, worktree, teste ou eval dependia de lembrar.

Depois: a ideia vira projeto estruturado em um comando, o estado vive no repositório, o histórico vive no Git com backup remoto, e a própria plataforma recomenda a arquitetura de execução adequada a cada problema.

## Princípio central

**Projeto ≠ sessão.** O projeto sobrevive a `/compact`, à perda do chat, a uma sessão nova, a outra conta do Claude, a outro computador, a outra pessoa assumindo e a meses sem uso.

## Comandos

| Comando | O que faz | Fase |
|---|---|---|
| `/os:new-project` | Cria um projeto novo já estruturado, com discovery, template e Git | 1 |
| `/os:resume` | Retoma um projeto lendo o estado do repositório, não do chat | 1 |
| `/os:checkpoint` | Salva uma versão com verificação: tests → QA → security → STATE → commit | 1 |
| `/os:status` | Onde estou, o que está pendente, qual o próximo passo | 1 |
| `/os:handoff` | Gera o documento para outra pessoa, máquina ou conta assumir o projeto | 1 |
| `/os:doctor` | Diagnóstico completo do projeto e sugestão de evolução | 2 |
| `/os:security` | Auditoria de segredos, dados sensíveis e exposição | 2 |
| `/os:eval` | Cria e roda evals de comportamento LLM | 2 |
| `/os:release` | tests → evals → QA → security → versão → CHANGELOG → tag → release | 5 |
| `/os:portfolio` | Gera o material de portfólio sanitizado | 5 |
| `/os:export-project` | Empacota o projeto de forma portátil, sem segredos | 5 |

Você não precisa decorar nenhum deles: descreva o que quer em português e o Project OS reconhece a intenção.

## Estrutura

```
emmily-ai-project-os/
├── .claude-plugin/     plugin.json e marketplace.json (é o que torna /os:* global)
├── skills/             cada procedimento — e cada comando /os:* (são a mesma coisa)
├── agents/             papéis cognitivos: architect, researcher, qa, security, portfolio
├── templates/          esqueleto dos projetos governados
├── scripts/            automação (doctor, bootstrap, install-hooks)
├── githooks/           hooks de Git versionados, ativados por core.hooksPath
├── hooks/              hooks de plugin do Claude Code (ainda vazia)
├── docs/               VISION, ARCHITECTURE, STATE, SETUP, decisions/, audits/
├── tests/              verificação da própria plataforma
└── evals/              medição do comportamento probabilístico (a partir da Fase 3)
```

## Instalação em outra máquina

Ver [docs/SETUP.md](docs/SETUP.md). Resumo: clonar, rodar `scripts/bootstrap.ps1`, registrar o marketplace local.

O `bootstrap.ps1` também **ativa os hooks de Git** (`core.hooksPath` → `githooks/`), de forma idempotente. Eles barram mensagem de commit estruturalmente inválida, segredo entrando no working tree e push sem as verificações que o manifesto declara — e são **contornáveis com `--no-verify`, por desenho**. Ver [docs/runbooks/hooks.md](docs/runbooks/hooks.md).

## Estado atual

Ver [docs/STATE.md](docs/STATE.md). Decisões arquiteturais em [docs/decisions/](docs/decisions/).

## Licença e escopo

Uso pessoal. Este repositório é sobre o **ambiente de desenvolvimento**. A arquitetura agêntica dos produtos (Agent SDK, LangGraph, RAG, filas, event-driven) é um projeto separado e deliberadamente fora de escopo aqui.
