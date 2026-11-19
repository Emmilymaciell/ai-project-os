# EMMILY AI PROJECT OS
## Handoff Mestre para Implementacao no Claude Code

## 1. Objetivo
Construir um sistema operacional pessoal de desenvolvimento assistido por IA que padronize como qualquer projeto da Emmily e criado, desenvolvido, testado, versionado, documentado, compartilhado, atualizado, arquivado e eventualmente transformado em portfolio.

A cultura desejada e:

> Tive uma ideia que merece virar projeto -> explico em linguagem natural -> o Project OS entende o problema -> recomenda a arquitetura de execucao apropriada -> cria a estrutura -> guia desenvolvimento -> sugere quando usar skills, subagentes, worktrees, Agent Teams, Dynamic Workflows, testes, evals, PRs etc. -> versiona -> documenta -> prepara release -> sincroniza gestao/portfolio -> deixa o projeto portavel e recuperavel.

O sistema deve servir para trabalho, faculdade, automacoes, IA, engenharia, aplicativos, scripts, pesquisa e projetos pessoais.

## 2. Principio central
**Projeto != sessao.**

O projeto e um repositorio duravel. A sessao do Claude e uma instancia temporaria de trabalho.

O projeto deve sobreviver a:
- /compact;
- perda ou exclusao do chat;
- nova sessao;
- outra conta do Claude;
- outro computador;
- outra pessoa assumindo;
- meses sem uso.

Nada critico pode depender somente do historico da conversa.

## 3. Papel de cada sistema
- **Git:** fonte de verdade do historico de mudancas.
- **Git GUI:** interface visual do Git, nao motor do versionamento.
- **GitHub:** remoto, branches, PRs, releases, Actions e backup.
- **Claude:** camada de raciocinio, implementacao e coordenacao.
- **Notion:** gestao visual, banco de projetos, dashboards, roadmap e portfolio.
- **Obsidian:** conhecimento local em Markdown, backlinks e knowledge graph.
- **n8n:** integracao e orquestracao de eventos entre sistemas.
- **OneDrive:** releases, handoffs, artefatos e backups; nao repositorios Git ativos sincronizados.

## 4. Politica corporativa
Projetos corporativos podem existir no ambiente pessoal autorizado da usuaria, incluindo repositorio local, GitHub pessoal privado e OneDrive pessoal.

Regras:
- GitHub privado por padrao;
- publicacao publica de dados corporativos nunca automatica;
- portfolio permitido, preferencialmente sanitizado;
- dados externos/servicos externos podem ser usados com aprovacao quando necessario;
- nunca publicar automaticamente documentos internos, credenciais, segredos, dados sensiveis ou informacoes nao autorizadas.

## 5. Workspace alvo
```text
C:\AI-WORKSPACE\
|
+-- _platform\
|   +-- emmily-ai-project-os\
+-- work\
|   +-- prog\
|   +-- dynatest\
|   +-- cliente-b\
+-- university\
+-- personal\
+-- ai-lab\
+-- portfolio\
```

Arquivos de release/backup podem ir para algo como:
```text
OneDrive\AI-ARCHIVE\
+-- releases\
+-- handoffs\
+-- portfolio-assets\
+-- backups\
```

## 6. O proprio Project OS
Ele sera um repositorio versionado que cria e governa outros projetos.

Estrutura aproximada:
```text
emmily-ai-project-os/
+-- .claude-plugin/
+-- skills/
|   +-- new-project/
|   +-- resume/
|   +-- checkpoint/
|   +-- project-doctor/
|   +-- handoff/
|   +-- release/
|   +-- portfolio/
|   +-- export-project/
|   +-- security-audit/
|   +-- knowledge-sync/
|   +-- project-orchestrator/
+-- agents/
|   +-- architect.md
|   +-- researcher.md
|   +-- qa-reviewer.md
|   +-- security-reviewer.md
|   +-- portfolio-curator.md
+-- workflows/
+-- hooks/
+-- scripts/
+-- templates/
+-- docs/
+-- tests/
+-- evals/
+-- README.md
+-- CHANGELOG.md
+-- CLAUDE.md
```

A estrutura exata deve ser validada durante a implementacao com a versao atual do Claude Code. Nao criar complexidade so por estetica.

## 7. Template maximo de projeto
Projetos complexos podem ter:
```text
meu-projeto/
+-- CLAUDE.md
+-- README.md
+-- CHANGELOG.md
+-- project.yaml
+-- .gitignore
+-- .env.example
+-- .claude/
|   +-- settings.json
|   +-- rules/
|   +-- skills/
|   +-- agents/
|   +-- workflows/
+-- .github/
|   +-- workflows/
|   +-- pull_request_template.md
+-- docs/
|   +-- STATE.md
|   +-- ARCHITECTURE.md
|   +-- SETUP.md
|   +-- REQUIREMENTS.md
|   +-- decisions/
|   +-- runbooks/
|   +-- handoff/
+-- src/
+-- scripts/
+-- tests/
+-- evals/
+-- data/
+-- artifacts/
+-- portfolio/
+-- bootstrap.ps1
```

Projetos pequenos usam apenas o necessario.

## 8. Estado e memoria
- **CLAUDE.md:** instrucoes permanentes e concisas.
- **docs/STATE.md:** estado atual do projeto, concluido, parcial, pendencias, riscos, proximo passo e ultimo checkpoint.
- **ADR:** decisoes arquiteturais importantes.
- **Auto Memory:** apoio local, nunca unica fonte de verdade para algo critico.

## 9. Portabilidade
Criar um contrato de portabilidade: outra conta, maquina, pessoa ou Claude deve conseguir assumir o projeto.

Cada projeto relevante precisa ter setup, dependencias, .env.example, bootstrap/doctor, documentacao, skills/agents especificos e instrucoes.

Criar `/os:export-project` para gerar um pacote portatil que remova segredos/caches/dados proibidos e gere HANDOFF.md.

## 10. Comandos principais
A usuaria nao deve precisar memorizar dezenas de comandos.

Atalhos principais:
- `/os:new-project`
- `/os:resume`
- `/os:checkpoint`
- `/os:status`
- `/os:doctor`
- `/os:handoff`
- `/os:release`
- `/os:portfolio`
- `/os:export-project`
- `/os:security`
- `/os:eval`

O Claude tambem deve sugeri-los em linguagem natural no momento adequado.

## 11. Proactive Guidance
A usuaria nao precisa saber previamente quando usar Skill, subagent, worktree, Agent Team, Dynamic Workflow, batch, tests, evals, hooks, PR, CI, MCP ou n8n.

Antes de implementacoes relevantes, avaliar:
- complexidade;
- dependencias;
- modulos independentes;
- risco;
- necessidade de pesquisa;
- necessidade de revisao;
- volume de arquivos;
- paralelismo possivel;
- comportamento probabilistico;
- reuso futuro;
- integracoes externas;
- sensibilidade dos dados.

Se houver mais de uma boa opcao, apresentar somente as relevantes, explicar trade-offs e recomendar uma.

## 12. Project Orchestrator
Criar um mecanismo que recomende o modo de execucao:

```text
Tarefa simples -> MAIN CLAUDE
Tarefa especializada -> SUBAGENT
Varias tarefas independentes -> PARALLEL SUBAGENTS
Varias mudancas independentes no repo -> WORKTREES
Agentes precisam conversar -> AGENT TEAM
Fluxo grande e reproduzivel -> DYNAMIC WORKFLOW
Mudanca enorme particionavel -> BATCH
```

O Project Orchestrator decide **como conduzir o trabalho**.
O Architect decide **como estruturar tecnicamente o produto**.

A arquitetura de execucao deve ser reavaliada quando o projeto crescer.

## 13. Worktrees e sessoes paralelas
Quando forem uteis, o Claude deve orientar explicitamente:
- quantas sessoes;
- branch/worktree de cada uma;
- objetivo;
- arquivos/responsabilidades;
- dependencias;
- criterio de conclusao;
- como integrar depois.

O usuario nao deve receber apenas a frase "use worktrees".

## 14. Skills
Skill e conhecimento/procedimento/workflow reutilizavel. Pode conter SKILL.md, referencias, scripts, assets, exemplos, criterios, templates e anti-falsos-positivos.

O sistema deve sugerir promover procedimentos recorrentes a Skill quando houver estabilidade/reuso suficiente.

## 15. Subagentes
Subagente e um trabalhador Claude especializado com contexto isolado, prompt, ferramentas, modelo, skills e eventualmente memoria.

Criar agentes por **papel cognitivo recorrente**, nao por extensao de arquivo.

Agentes-base:
- architect;
- researcher;
- qa-reviewer;
- security-reviewer;
- portfolio-curator.

## 16. Builder != Evaluator
Quando o risco justificar:
```text
Architect/Planner -> Builder -> Tests/Evals -> QA independente -> Security -> Human Review
```

Quem implementou nao deve ser a unica fonte de validacao.

## 17. Tests e Evals
O sistema deve detectar automaticamente:
- codigo deterministico -> tests/;
- comportamento LLM/IA -> evals/;
- integracao externa -> integration tests/mocks quando apropriado;
- artefato documental -> validacao apropriada;
- dados sensiveis -> security checks.

A usuaria nao deve precisar lembrar de criar evals.

## 18. Security reviewer
Preferencialmente read-only.

Verificar:
- secrets/tokens/.env;
- dados corporativos/pessoais;
- arquivos indevidamente versionados;
- dependencias;
- acoes destrutivas;
- envio a servicos externos;
- permissoes.

## 19. Niveis de autonomia
Proposta inicial:
- 0: somente ler;
- 1: analisar/sugerir;
- 2: editar local;
- 3: executar scripts/testes;
- 4: preparar commit;
- 5: branch/push/PR;
- 6: escrever em servicos externos;
- 7: deploy/operacao sensivel.

Comecar conservador e aumentar conscientemente.

## 20. Git, diff e PR
Fluxo de checkpoint:
```text
aprovacao humana -> tests -> evals (se aplicavel) -> QA -> security -> git status -> diff -> atualizar STATE/CHANGELOG -> resumo -> commit
```

Nao usar `git add .` cegamente.

Pequena mudanca -> commit.
Feature relevante -> branch + PR.
Release -> PR quando a maturidade do projeto justificar.

## 21. GitHub Actions
Fase de qualidade deve adicionar CI quando fizer sentido para executar tests, lint, type checks, security e evals selecionados.

## 22. Hooks
Usar hooks para politicas deterministicas, por exemplo:
- antes de compactar: checar checkpoint;
- antes de commit: security scan;
- ao parar: validar criterio de conclusao;
- ao criar/remover worktree: atualizar estado.

Nao depender da LLM lembrar de rotinas automatizaveis.

## 23. Notion + Obsidian
- Git/repo = verdade tecnica.
- Notion = verdade gerencial/visual.
- Obsidian = conhecimento em rede/local.

Arquitetura inicial preferida:
```text
PROJECT REPO -> n8n -> Notion
PROJECT REPO -> n8n -> Obsidian
```

Evitar sincronizacao bidirecional irrestrita no inicio.

## 24. n8n
Integracao oficial futura do OS.

Workflows planejados:
1. project-created
2. checkpoint-sync
3. release-sync
4. pr-merged
5. portfolio-sync
6. backup-release
7. project-health
8. knowledge-sync

Implementar progressivamente.

## 25. Portfolio
`/os:portfolio` deve funcionar como uma reuniao multidisciplinar virtual: gestao/negocio, operacoes, tecnica, QA/evidencias, seguranca/privacidade e portfolio curator.

Saidas previstas:
```text
portfolio/
+-- project.yaml
+-- executive-summary.md
+-- case-study.md
+-- technical-summary.md
+-- operational-impact.md
+-- metrics.json
+-- architecture-diagram.md
+-- lessons-learned.md
+-- screenshots/
+-- visibility.yaml
```

Nunca inventar metricas. Projetos corporativos: portfolio permitido, com controle de exposicao.

## 26. Observabilidade
Fase posterior: medir sessoes, agentes, skills, tokens, custo, tempo, erros, taxa de sucesso, tool calls, commits, PRs e eval scores.

## 27. Project Doctor
`/os:doctor` deve verificar estrutura, documentacao, STATE, branches, dependencias, secrets, tests, evals, skills, agents, arquitetura de execucao, portfolio, sincronizacoes, releases e divida tecnica.

Tambem deve sugerir evolucao arquitetural quando necessario.

## 28. Handoff
`/os:handoff` gera um documento para outra pessoa/Claude/maquina assumir contendo contexto, arquitetura, estado, setup, dependencias, decisoes, riscos, validacao e proximos passos.

## 29. Release
Fluxo-alvo:
```text
tests -> evals -> QA -> security -> version bump -> CHANGELOG -> tag -> GitHub release -> portable bundle -> Notion -> portfolio -> OneDrive archive
```

Implementar em etapas, nao tudo no MVP.

## 30. Ordem de implementacao
### Fase 0 - Discovery / auditoria read-only
Mapear Windows, Claude Code/Desktop, Git/Git GUI, GitHub CLI, Python, Node, PowerShell, OneDrive e projetos existentes. Nao alterar projetos.

### Fase 1 - Fundacao
Workspace, repo do OS, Git/GitHub privado, template, project.yaml, CLAUDE.md, STATE.md, README, new-project, resume, checkpoint, handoff.

### Fase 2 - Qualidade
Tests, evals, QA, security, hooks, diff, branches, PR, GitHub Actions.

### Fase 3 - Paralelismo
Subagents, worktrees, Agent View, Dynamic Workflows, orientacao proativa.

### Fase 4 - Integracoes
Notion, n8n, GitHub webhooks, OneDrive archive, Obsidian.

### Fase 5 - Portfolio
Portfolio curator, workflow central, sanitizacao, feeds futuros.

### Fase 6 - Observabilidade
Metricas, tracing, custos, dashboards.

### Fase 7 - Experimental
Somente com beneficio real: Agent Teams, Claude Squad, multi-model, OpenClaw, Claw3D, Agent SDK etc.

## 31. Migracao de projetos existentes
Nao converter todos de uma vez.

1. Inventario.
2. Classificacao.
3. Backup/commit atual.
4. Doctor read-only.
5. Comparar estrutura.
6. Preservar o que funciona.
7. Migrar apenas o necessario.
8. Testar.
9. Gerar STATE.
10. Commit de migracao.
11. So depois avancar para outro projeto.

## 32. UX desejada
A usuaria pode falar normalmente.

Exemplo:
- "Essa versao ficou boa" -> Claude sugere checkpoint.
- "Quero adicionar 10 analises independentes" -> Claude pode recomendar Dynamic Workflow.
- "Quero mexer em 3 modulos independentes" -> Claude recomenda worktrees e guia a criacao.
- procedimento repetido -> Claude sugere transformar em Skill.
- papel recorrente de revisao -> Claude sugere criar subagente.

## 33. Fluxo humano final
1. Ideia.
2. Classificar conversa/tarefa/projeto.
3. New Project.
4. Discovery.
5. Requirements.
6. Architecture.
7. Execution Architecture Advisor.
8. Implementation.
9. Paralelismo se apropriado.
10. Tests/evals.
11. QA/security.
12. Human review.
13. Checkpoint.
14. PR/CI quando apropriado.
15. Release.
16. Notion/n8n/archive.
17. Portfolio.
18. Operacao/manutencao.
19. Handoff/archive.

## 34. Ferramentas no radar, nao no MVP
Nao instalar automaticamente OpenClaw, Claw3D, Claude Squad, Agent Deck, CrewAI, LangGraph, AutoGen, dezenas de MCPs ou dezenas de agentes.

Avaliar apenas quando resolvem problema concreto.

## 35. Escopo
Este projeto e sobre o **ambiente pessoal de desenvolvimento com Claude**.

Separar de outro projeto futuro: **Arquitetura Agentica dos Meus Produtos**, onde entram Claude Agent SDK, LangGraph, CrewAI, AutoGen, RAG, filas, event-driven architecture etc.

## 36. Criterio de sucesso
O OS esta maduro quando:
- ideia vira projeto profissional com pouco trabalho manual;
- Claude recomenda a infraestrutura adequada;
- chats deixam de ser ponto unico de falha;
- projetos sao portaveis;
- versoes sao rastreaveis;
- qualidade e verificavel;
- IA tem evals quando apropriado;
- seguranca e revisao sao explicitas;
- handoff e release sao reproduziveis;
- Notion/portfolio/arquivo integram progressivamente;
- a plataforma evolui sem complexidade gratuita.

---

# PROMPT DE INICIALIZACAO PARA CLAUDE CODE

Voce e o **Implementation Lead do projeto EMMILY AI PROJECT OS**.

Existe nesta pasta um arquivo chamado `EMMILY_AI_PROJECT_OS_HANDOFF.md`. Leia esse arquivo **integralmente antes de fazer qualquer alteracao**. Ele e a especificacao mestre do projeto e registra decisoes arquiteturais ja discutidas e aprovadas.

## Missao
Implementar o Project OS fase por fase no computador Windows da usuaria, ate chegar ao sistema descrito no handoff.

Atue como engenheiro de plataforma, arquiteto de software, especialista em Claude Code, Git/GitHub, automacao, QA, portabilidade e seguranca.

A usuaria nao deve precisar dominar os detalhes tecnicos antes de comecar. Quando houver passo manual, explique exatamente o que ela deve fazer.

## Comece SOMENTE pela Fase 0 - auditoria read-only
Antes de alterar qualquer coisa, descubra e registre:
1. versao/localizacao do Claude Code/Desktop;
2. Git;
3. como Git GUI esta sendo usado;
4. se `gh` esta instalado/configurado;
5. Python;
6. Node/npm se aplicavel;
7. PowerShell;
8. estrutura dos projetos atuais;
9. repositorios Git existentes;
10. OneDrive e pastas sincronizadas;
11. quais projetos ja possuem `.claude`, skills, CLAUDE.md, scripts, state, tests etc.;
12. como o versionamento atual funciona;
13. riscos de migracao;
14. dependencias que afetam a Fase 1.

Nao mova, renomeie, delete, instale ou reestruture nada na Fase 0 sem aprovacao.

Entregue:
- inventario do ambiente;
- lacunas;
- riscos;
- recomendacoes;
- proposta detalhada da Fase 1.

## Ciclo de trabalho em cada fase
Use:
1. INSPECT
2. PLAN
3. EXPLAIN
4. GET APPROVAL quando relevante
5. IMPLEMENT
6. TEST
7. QA
8. SECURITY CHECK
9. SHOW DIFF/RESULT
10. UPDATE STATE/DOCS
11. CHECKPOINT/COMMIT
12. NEXT STEP

## Proactive Guidance
A usuaria NAO precisa saber previamente quando usar Skill, subagent, worktree, Agent Team, Dynamic Workflow, batch, tests, evals, hooks, PR, CI, MCP ou n8n.

Avalie continuamente e recomende quando houver beneficio material.

Use como heuristica:
- tarefa simples -> Main Claude;
- tarefa especializada -> subagent;
- tarefas independentes -> parallel subagents;
- mudancas independentes no repo -> worktrees;
- agentes precisam conversar -> Agent Team;
- fluxo grande/reproduzivel -> Dynamic Workflow;
- alteracao enorme/particionavel -> batch.

Se houver duas boas abordagens, apresente as opcoes relevantes, explique trade-offs e recomende uma.

Se recomendar worktrees/sessoes paralelas, guie a usuaria explicitamente com nomes, branches, objetivos, responsabilidades e integracao.

## Tests/evals
Detecte automaticamente:
- codigo deterministico -> tests;
- IA/LLM -> evals;
- integracao externa -> integration tests/mocks quando apropriado;
- artefatos -> validacao;
- dados sensiveis -> security checks.

A usuaria nao deve ter que lembrar disso.

## Git
Git e a fonte de verdade. Git GUI e apenas interface.

Nao use `git add .` cegamente.
Antes de commit: status, diff, secrets, tests, QA, STATE/CHANGELOG, resumo e politica de aprovacao.

GitHub pessoal e permitido inclusive para projetos corporativos, privado por padrao. Dados corporativos nao podem ser publicados automaticamente. Portfolio e permitido com controle de exposicao. Escritas externas exigem aprovacao quando configurado.

## Projetos existentes
Nao tente converter todos de uma vez.
Primeiro audite, depois escolha um projeto piloto, migre com seguranca, valide o metodo e so entao replique.

## Portabilidade
Nada critico deve depender do historico deste chat. O resultado deve ser clonavel/transferivel para outra conta, maquina ou pessoa.

## Primeira resposta apos ler o handoff
1. confirme que entendeu;
2. resuma em no maximo 10 pontos o que sera construido;
3. explique a Fase 0;
4. diga quais informacoes/acessos precisa verificar;
5. inicie somente operacoes read-only seguras;
6. nao inicie a Fase 1 antes de apresentar o resultado da auditoria e obter aprovacao.

---

## Nota sobre este documento
Este handoff deve ser usado como especificacao inicial, nao como prompt gigante permanente.

Depois da Fundacao:
- mover/guardar como documento de visao/spec em `docs/`;
- extrair regras permanentes curtas para CLAUDE.md/rules;
- registrar decisoes em ADRs;
- registrar estado em STATE.md;
- manter o historico do chat apenas como referencia opcional.
