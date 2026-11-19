# Emmily AI Project OS — instruções permanentes

Este repositório **é a plataforma**, não um projeto de trabalho. Ele cria e governa os outros projetos.

## Princípio central

**Projeto ≠ sessão.** O repositório é a fonte de verdade. O chat é descartável. Nada crítico pode existir apenas no histórico da conversa.

Antes de terminar qualquer trabalho relevante, pergunte: *se esta conversa sumisse agora, o que se perderia?* O que se perderia deve estar em `docs/STATE.md`, num ADR ou no código.

## Protocolo de sessão

| Comando | Quando | O que faz |
|---|---|---|
| `/session-start` | ao abrir qualquer sessão | reconstrói o estado pelo repositório, reconcilia com Git e disco, apresenta o briefing e **para**. Read-only: não edita, não commita, não começa tarefa |
| `/session-close` | ao encerrar | para o desenvolvimento, persiste no disco o que só existe na conversa, atualiza `docs/STATE.md` e `docs/sessions/SESSIONS.md`, confere o Git e **para**. **Não commita** — isso continua sendo `/os:checkpoint`, e só a pedido |

As duas vivem em `.claude/skills/` (locais deste repositório, não do plugin). Elas **compõem** `/os:resume`, `/os:status` e `scripts/doctor.ps1` em vez de duplicá-los.

## Antes de mudar qualquer coisa

Leia, nesta ordem:
1. `docs/STATE.md` — onde o projeto está agora.
2. `docs/ARCHITECTURE.md` — como está organizado e por quê.
3. `docs/decisions/` — o que já foi decidido. **Não reabra decisão registrada sem motivo técnico novo.**

`docs/VISION.md` é a especificação mestre. É referência, não prompt: consulte a seção relevante, não recarregue inteiro.

## Ciclo de trabalho obrigatório

```
INSPECT → PLAN → EXPLAIN → APPROVAL (quando relevante) → IMPLEMENT
→ TEST → QA → SECURITY → DIFF/RESULT → UPDATE STATE/DOCS → CHECKPOINT → NEXT STEP
```

Não pule TEST, SECURITY nem UPDATE STATE porque "a mudança é pequena".

## Regra de ouro do Git

**Nunca `git add` / `git commit` / `git tag` por iniciativa própria.** Nem ao terminar uma tarefa, nem ao corrigir um bug, nem no fim da sessão.

Commitar apenas quando a usuária pedir explicitamente ("salva essa versão", "commita", `/os:checkpoint`, `/versionar`). Em caso de dúvida, pergunte em uma linha.

Nunca `git add .` às cegas: `status` → `diff` → security scan → resumo → `add` seletivo.

Proibido sem pedido explícito: `push`, `reset --hard`, `checkout --`, `clean -fd`, `rebase`, `commit --amend`, `push --force`, trocar de branch no meio de um trabalho.

## Proactive Guidance

A usuária **não deve precisar lembrar** quando usar Skill, subagent, worktree, Agent Team, Dynamic Workflow, batch, hooks, tests, evals, branch, PR, CI, MCP ou n8n. Detectar e recomendar é responsabilidade sua.

Heurística de execução:

| Situação | Modo |
|---|---|
| Tarefa simples | Main Claude |
| Tarefa especializada | Subagent |
| Tarefas independentes entre si | Parallel subagents |
| Mudanças independentes no mesmo repo | Worktrees |
| Agentes precisam conversar | Agent Team |
| Fluxo grande e reproduzível | Dynamic Workflow |
| Mudança enorme e particionável | Batch |

Se recomendar worktrees ou sessões paralelas, **nunca diga só "use worktrees"**: diga quantas sessões, o nome de cada frente, branch, objetivo, arquivos sob responsabilidade, critério de conclusão e como integrar depois.

Se houver mais de uma boa opção, apresente só as relevantes, explique o trade-off e **recomende uma**.

## Verificação — detectar sozinho

| Natureza | Verificação |
|---|---|
| Código determinístico | `tests/` |
| Comportamento LLM/IA | `evals/` |
| Integração externa | integration test + mock |
| Artefato documental | validação de estrutura/conteúdo |
| Dado sensível | security check |

A usuária não deve precisar pedir eval.

## Segurança

GitHub **privado por padrão**. Projetos corporativos (Programa/Dynatest) podem viver no GitHub pessoal privado, mas **nada corporativo é publicado automaticamente**. Portfólio é permitido com sanitização e controle de exposição explícito.

Antes de qualquer push: varrer segredos, tokens, `.env`, dados pessoais de terceiros e documentos internos — inclusive no histórico já commitado, não só no working tree.

## Idioma e estilo

Português do Brasil. Direto ao ponto. Ao entregar arquivo, informar o caminho completo.

## Ambiente

Windows 11, PowerShell 5.1, Git 2.55, Python 3.12/3.13, Node 24. Para scripts COM/Office, usar o scratchpad em `Temp`, **nunca** pasta sincronizada pelo OneDrive.

**Leia `docs/runbooks/gotchas-windows-powershell.md` antes de escrever `.ps1` ou mexer em Git aqui.** Cada item dele custou tempo de verdade: variável case-insensitive, `\` que não é escape, `Get-Content` sem `-Encoding` corrompendo acento, aviso de CRLF do Git virando erro terminante, `git diff HEAD` em repositório sem commits.
