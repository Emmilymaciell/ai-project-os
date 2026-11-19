# FASE 0 — Auditoria read-only do ambiente

> **Versão pública sanitizada.** Caminhos locais, e-mails e nomes de projetos/cliente foram substituídos (ver `RELATORIO` de sanitização). Mantido porque é o arquivo-alvo da exceção do ADR-0010 declarada em `project.yaml`.

- **Data:** 2026-09-05
- **Executor:** Claude Code (Implementation Lead), Opus 5
- **Escopo:** somente leitura. Nada foi movido, apagado, renomeado, instalado ou reorganizado.
- **Único arquivo criado:** este relatório.
- **Sensibilidade:** MÉDIA — este documento contém a estrutura de pastas corporativas (Programa/Dynatest), caminhos locais e os e-mails de identidade dos repositórios. Compatível com repositório **privado** (ADR-0003). **Não incluir em portfólio nem em qualquer publicação pública sem sanitização.**

---

## 1. Inventário de ferramentas

| Item | Estado | Detalhe |
|---|---|---|
| Windows | OK | 11 Pro 10.0.26200 |
| PowerShell | OK (5.1) | 5.1.26100.9278. **pwsh 7 não instalado** |
| ExecutionPolicy | OK | LocalMachine = RemoteSigned |
| Git | OK | 2.55.0.windows.3 (`C:\Program Files\Git`) |
| Git identidade GLOBAL | **AUSENTE** | `user.name` e `user.email` vazios no `~/.gitconfig` |
| Git credential.helper | **AUSENTE** | não configurado |
| init.defaultBranch | **AUSENTE** | repos existentes divergem: um em `master`, dois em `main` |
| core.excludesfile (gitignore global) | AUSENTE | cada projeto tem o seu (bem feitos) |
| gitk | OK | presente |
| git gui | OK | usado via `scripts/abrir_git_gui.ps1` nos projetos |
| GitHub CLI (`gh`) | **NÃO INSTALADO** | bloqueia remoto / PR / CI. Confirmado: não está no PATH nem em `~\.local\bin` |
| GitHub remoto | **INEXISTENTE** | nenhum dos 3 repos tem `remote` |
| Python | OK | 3.13 (default do launcher `py`) e 3.12 (default do PATH) — **divergência** |
| Node / npm | OK | v24.18.0 / 11.16.0 |
| npm globals | — | apenas `n8n@2.29.10` |
| n8n | INSTALADO | `~/.n8n` existe; não verificado se está rodando |
| Notion desktop | INSTALADO | + Notion Calendar |
| Obsidian | **NÃO INSTALADO** | |
| Docker | não instalado | não necessário agora |
| VS Code (`code`) | não está no PATH | |
| winget | OK | v1.29.290 — caminho de instalação disponível para o `gh` |
| Claude Desktop | OK | `app-1.20186.0` |
| Claude Code CLI (`claude`) | **CORRIGIDO em 2026-09-08: instalado** | `~\.local\bin\claude.exe`, versão **2.1.252**, pelo instalador nativo. Está fora do PATH do Bash desta sessão, o que produziu o falso negativo original. Invocar pelo caminho completo funciona. |
| Disco C: | ATENÇÃO | 475 GB total, 96 GB livres (80% usado) |

## 2. Configuração global do Claude (`~/.claude`)

- `settings.json` mínimo: tema, canal de update, marketplace oficial. **Sem hooks, sem permissions, sem env.**
- Skills globais: **1** (`versionar`).
- Agents globais: **0** (a pasta não existe).
- MCP servers: **0** (global e por projeto).
- Plugins instalados: **0** (apenas o marketplace oficial registrado).
- `~/.claude/CLAUDE.md`: existe e é bom — idioma, ambiente Windows/OneDrive e o protocolo de versionamento (regra de ouro: nunca commitar sem pedido explícito).
- Auto-memory: 5 memórias indexadas em `MEMORY.md`.
- Higiene: ~10 arquivos órfãos `.claude.json.tmp.*` na home (lixo, não crítico).

## 3. Repositórios Git existentes

Todos são **locais, sem remoto, sem branch além da principal, sem PR, sem CI, sem hooks**.

### 3.1 `C:\caminho\exemplo\PROG_Relatorio_Grupo1_Automacao`

- Branch `master` | 16 commits | **15 tags (v1.0 … v1.14)** | working tree limpo
- Identidade local: Emmily Melo &lt;(e-mail corporativo removido)&gt;
- Tem: `CLAUDE.md`, `.claude/skills/relatorio-prog-grupo1/` (SKILL.md + assets + references + scripts)
- Não tem: `README.md`, `docs/`, `STATE.md`, `tests/`, `evals/`, `CHANGELOG.md`
- Tamanho 189 MB, mas `.git` = 1,3 MB. O peso está em `output/` (146 MB) e `examples/` (42 MB), **corretamente ignorados**.
- `.gitignore` de altíssima qualidade: bloqueia Office, PDF, imagens, segredos e dados operacionais do Programa.

### 3.2 `C:\caminho\exemplo\PROG_Repositorio_Juridico`

- Branch `main` | 16 commits | 0 tags | working tree limpo
- Identidade local: "PROG - Automacao Indice Juridico" &lt;pessoa@example.com&gt; (identidade de projeto, não pessoal — decisão deliberada)
- Tem: `CLAUDE.md`, `README.md`, `.claude/skills/indice-repositorio-juridico/`, `.gitattributes`, `state/`, `historico/`, 6 scripts Python + 4 PowerShell, e **`scripts/99_teste_ciclo.py` (já existe um teste de ciclo)**
- Não tem: `docs/`, `STATE.md`, `CHANGELOG.md`, `evals/`

### 3.3 `C:\caminho\exemplo\OneDrive\Documentos\Claude\Organizador_Dynatest_Pessoal`

- Branch `main` | 6 commits | 0 tags | **1 arquivo modificado** (`state/movimentos.tsv`)
- Tem: `CLAUDE.md`, `README.md`, `.claude/skills/…`, `.gitattributes`, 8 scripts Python + 6 PowerShell, `99_teste_ciclo.py`
- **Mora dentro do OneDrive de propósito** (ela alterna entre a máquina do trabalho e o notebook de casa). O risco já foi mitigado conscientemente no commit `b64b696`: `gc.auto=0`, `maintenance.auto=false` e `backup_historico.ps1` gerando `backups/historico.bundle` (arquivo único, que o OneDrive sincroniza inteiro ou não sincroniza). A restauração já foi testada.
- Todos os 158 arquivos estão LOCAIS (nenhum cloud-only). Sem risco imediato.

### 3.4 Não-repositórios relevantes

- `C:\caminho\exemplo\Desktop\engenharia-rodoviaria_1.4\engenharia-rodoviaria_1.3` — tem `.claude-plugin/`, `agents/`, `skills/`, `AGENTS.md`, `CLAUDE.md`, `CHANGELOG.md`, `AUTHORS.md`, mas **não tem Git**. É o projeto de maior maturidade estrutural e menor segurança de histórico.
- `C:\caminho\exemplo\Documents\Codex` — esqueleto vazio do Codex, `.git` vazio/corrompido. Ignorar.
- ZIPs de backup manual na home: `PROG_Relatorio_Grupo1_Automacao*.zip` (3 arquivos, ~426 MB no total) e `PROG_Repositorio_Juridico.zip`. Backup por cópia manual — sintoma exato do que o OS deve substituir.

## 4. Como o versionamento funciona hoje

Padrão real observado (consistente e bom):

1. Trabalho local, sem remoto.
2. Commit somente quando ela pede (regra de ouro do `~/.claude/CLAUDE.md`).
3. Mensagens de commit descritivas, algumas referenciando decisões (`DEC-033`, `DEC-039`) — ou seja, **já existe um embrião de ADR**, só que dentro do `CLAUDE.md` e não em `docs/decisions/`.
4. Tags de versão apenas no projeto Programa Relatório (`v1.0`…`v1.14`).
5. Inspeção visual por `git gui` / `gitk`, via `scripts/abrir_git_gui.ps1`.
6. Backup por ZIP manual e, no projeto do OneDrive, por bundle automatizado.

## 5. Lacunas (gap analysis) frente ao handoff

| Área | Lacuna |
|---|---|
| Workspace | `C:\AI-WORKSPACE` existe, mas só com `_platform/emmily-ai-project-os` (2 arquivos). Faltam `work/`, `university/`, `personal/`, `ai-lab/`, `portfolio/`. |
| Project OS | Não existe: sem repo, sem skills, sem agents, sem templates, sem plugin. |
| Comandos `/os:*` | Nenhum existe. |
| Identidade Git global | Ausente — cada repo depende de config local; um repo novo hoje falharia no commit. |
| GitHub | Sem `gh`, sem conta configurada, sem remoto, sem backup fora da máquina. |
| Portabilidade | Nenhum projeto tem `bootstrap`, `.env.example`, `SETUP.md` ou `HANDOFF.md`. Nenhum é clonável-e-executável por terceiro. |
| Estado | Nenhum `docs/STATE.md`. O estado vive no `CLAUDE.md` e na cabeça dela. |
| ADR | Decisões (`DEC-xxx`) existem, mas não estão em `docs/decisions/`. |
| Tests | 2 de 3 projetos têm `99_teste_ciclo.py`, mas sem runner, sem CI, sem convenção. |
| Evals | Zero. Os 3 projetos produzem artefatos via LLM/heurística — **são candidatos reais a eval**. |
| Hooks | Zero. A regra de ouro de commit e a política de segredos dependem hoje de a LLM lembrar. |
| CI | Zero (consequência de não haver GitHub). |
| Subagents | Zero. |
| MCP | Zero. |
| n8n | Instalado, não integrado. |
| Notion | Instalado, não integrado. |
| Obsidian | Não instalado. |
| Observabilidade | Zero. |

## 6. Riscos identificados

### Altos

- **R1 — Sem backup fora da máquina.** Os 3 repos existem em um único disco. Falha de disco = perda total de histórico. É o risco mais grave e o mais barato de resolver (GitHub privado).
- **R2 — Identidade Git global ausente.** Qualquer repo novo criado pela Fase 1 não consegue commitar até isso ser resolvido. **Bloqueia a Fase 1.**
- **R3 — O projeto mais estruturado (`engenharia-rodoviaria_1.4`) está no Desktop sem Git.** Não há histórico; qualquer erro é irreversível.

### Médios

- **R4 — Dados corporativos.** Os 3 projetos tocam material Programa/Dynatest. Qualquer remoto DEVE ser privado e passar por security scan antes do primeiro push. Os `.gitignore` atuais já são fortes, mas nunca foram auditados contra o histórico já commitado.
- **R5 — Três contas OneDrive corporativas registradas** (`OneDrive - Dynatest Engenharia`, `(1)` e `(2)`), sinal de re-vinculações anteriores. Caminhos de script que apontem para a pasta errada quebram silenciosamente.
- **R6 — Divergência Python 3.12 (PATH) × 3.13 (launcher `py`).** Scripts podem rodar em interpretador diferente conforme quem chama. Nenhum projeto usa venv.
- **R7 — Divergência de branch padrão** (`master` vs `main`).
- **R8 — Disco a 80%.** Worktrees, clones e bundles consomem espaço. 426 MB só em ZIPs redundantes.

### Baixos

- **R9 — Repo dentro do OneDrive:** risco real, mas já mitigado de forma competente e testada. **Recomendação: preservar a decisão, não mover.**
- **R10 —** `~/.claude.json.tmp.*` órfãos.
- **R11 —** Sem `pwsh` 7 (o 5.1 é suficiente; `pwsh` seria conforto, não necessidade).

## 7. Dependências que afetam a Fase 1

1. Definir identidade Git global (nome + e-mail) — **bloqueante**.
2. Existe conta GitHub? Qual usuário? Instalar `gh` — **bloqueante para o remoto**, não para o resto.
3. Confirmar que os 3 projetos existentes **permanecem onde estão** por enquanto (recomendado).
4. Escolher o projeto piloto de migração.

## 8. Recomendação de projeto piloto

**`PROG_Repositorio_Juridico`.**

Motivos: é pequeno (3,6 MB), tem working tree limpo, histórico consistente em `main`, já tem `README.md`, `.gitattributes`, Skill própria e um teste (`99_teste_ciclo.py`). É o que mais se aproxima do template-alvo, então a migração exercita o método sem risco alto — e, se der errado, o custo de reverter é baixo.

Descartados como piloto nesta rodada: o Programa Relatório (189 MB, 15 tags, é o projeto de maior valor operacional — migrar por último), o Organizador (vive no OneDrive, tem decisão específica a preservar) e o engenharia-rodoviária (sem Git — precisa primeiro de um commit inicial de segurança, que é uma ação isolada, não uma migração).
