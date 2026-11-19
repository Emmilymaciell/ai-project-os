# 06 — Como trabalhar em um projeto

## 1. Abrir

1. Abra o Claude Code **na pasta do projeto** (ex.: `C:\Users\<você>\PROG_Relatorio_G2_Automacao`,
   ou `C:\AI-WORKSPACE\work\prog\prog-gerador-dossie`). Se não lembrar onde fica:
   `py -3.13 -m eos check <id>` mostra o caminho resolvido; ou pergunte *"onde fica o projeto X?"*.
2. Digite `/session-start`, ou diga *"onde paramos?"* (que aciona `/os:resume`).

O que acontece por baixo:

| Passo | Comando real |
|---|---|
| confirmar a raiz e o Git | `git rev-parse --show-toplevel`, `git status --porcelain`, `git log -10` |
| ler as regras | `CLAUDE.md` inteiro; só o cabeçalho e o *Próximo passo* do `STATE.md`; só os ADRs que restringem a próxima tarefa |
| diagnóstico barato | `scripts/doctor.ps1` (cerca de 2 s; não roda a suíte) |
| reconciliar | data do STATE × último commit; próximo passo × `git log`; arquivos modificados × pendências |

## 2. Ler o briefing

```
PROJETO        <nome> — <que problema resolve>
SESSÃO         <N> — <nome sugerido>
GIT            branch · HEAD · staged / modificados / não rastreados
ÚLTIMO MARCO VERIFICÁVEL
PRÓXIMA TAREFA EXATA
CRITÉRIO DE CONCLUSÃO
DECISÕES QUE RESTRINGEM
VALIDAÇÃO      Último resultado registrado: ... / Executado agora: ...
PENDÊNCIAS / BLOQUEIOS
INCONSISTÊNCIAS ENCONTRADAS

Contexto reconstruído. Nenhuma alteração foi realizada.
```

Três coisas para olhar:

- **Inconsistências:** se o STATE diz uma coisa e o Git outra, o Claude **mostra** as duas e diz
  qual está usando. Ele não corrige em silêncio.
- **Validação:** *"registrado"* é o que alguém rodou antes; *"executado agora"* é o que rodou nesta
  sessão. Resultado antigo nunca é apresentado como novo.
- **Próxima tarefa exata:** é a menor unidade coerente, não um replanejamento.

Depois do briefing o Claude **para**. Autorize: *"pode seguir"*, ou dê outra tarefa.

## 3. Trabalhar

O ciclo que o Claude segue em toda tarefa:

```
INSPECT → PLAN → EXPLAIN → APPROVAL (quando relevante) → IMPLEMENT
→ TEST → QA → SECURITY → DIFF/RESULT → UPDATE STATE/DOCS → (CHECKPOINT a seu pedido) → NEXT STEP
```

O que você pode esperar sem pedir:

| O Claude faz sozinho | Exemplo |
|---|---|
| recomendar o modo de execução | *"são 3 módulos independentes: sugiro 3 worktrees, `feat/leitura`, `feat/calculo`, `feat/relatorio`..."* com objetivo, arquivos, critério e integração de cada uma |
| detectar a verificação necessária | código → testes; saída de IA → evals; integração → mock; dado sensível → varredura |
| sugerir skill ou subagente | procedimento repetido → *"vale virar skill"* |
| oferecer checkpoint | *"ficou bom"* → ele **oferece** em uma linha; não executa |

O que o Claude **não** faz sem você:

- commit, tag, push;
- `reset --hard`, `checkout --`, `clean -fd`, `rebase`, `commit --amend`, `push --force`;
- trocar de branch no meio de um trabalho;
- apagar arquivo, pasta, branch, worktree ou backup;
- login em qualquer serviço.

## 4. Salvar uma versão (checkpoint)

Diga uma destas: *"salva essa versão"*, *"commita isso"*, *"atualiza o git"*, *"essa é a versão
boa"*, *"marca como versão 0.2.0"*, ou `/os:checkpoint`.

**Não** são pedidos de commit: *"ficou bom"*, *"terminei"*, *"pronto"*, *"funcionou"*. Na dúvida, o
Claude pergunta em uma linha.

A sequência:

| # | Etapa | O que você vê |
|---|---|---|
| 1 | INSPECT | `git status`, `git diff --stat`, diff lido inteiro |
| 2 | TEST | o comando de teste do projeto e a **saída real**. Teste falhando interrompe |
| 3 | QA | auto-revisão; e o `qa-reviewer` se a criticidade for média ou alta |
| 4 | SECURITY | busca de segredo, documento operacional e dado pessoal de terceiro. Achado interrompe |
| 5 | STATE | `STATE.md`, `CHANGELOG.md` e `project.yaml` atualizados **antes** do commit |
| 6 | DIFF | o resumo: arquivos, testes, segurança, versão, mensagem proposta |
| 7 | APPROVAL | **seu sim** |
| 8 | COMMIT | `git add` arquivo por arquivo (nunca `git add .`) e commit assinado |
| 9 | TAG | só se for marco validado ponta a ponta, e só com sua confirmação. Formato `v0.2.0` |

Commit não é backup e não sai da máquina. Para isso: push (seção 6) e `eos backup` (seção 5).

## 5. Backup durante o trabalho

```powershell
py -3.13 -m eos backup <id>
```

| Quando | Por quê |
|---|---|
| fim do dia | protege o WIP que ainda não virou commit |
| antes de qualquer coisa arriscada | migração, sanitização, refatoração grande |
| depois de alterar um banco SQLite declarado | o snapshot antigo deixa de valer (`banco ... mudou depois do snapshot`) |
| depois de um checkpoint importante | o bundle passa a ter as refs atuais |

O backup não toca no projeto: só lê e acrescenta artefatos na nuvem.

Pastas de dados `cloud-mirror` (fora do Git) não entram no backup: depois de gerar ou alterar dados
nelas, `py -3.13 -m eos mirror <id>` (ver [08](08-BACKUP-E-RECOVERY.md), seção 4).

### Trabalho não commitado (WIP)

Arquivos modificados e novos de **todas** as worktrees do projeto vão num `wip.tar.gz`. Não vão:

- arquivos ignorados pelo Git (por isso eles precisam estar declarados em `data` no contrato);
- arquivos com nome de segredo (`.env`, `*.key`, `credentials.json`...);
- **stash** — se você tiver stash, o backup fica INCOMPLETO. Peça *"transforma o stash em branch"*;
- submódulos e symlinks.

### Bancos de dados

Projetos com estado em SQLite (ex.: Cérebro Documental, Organização SharePoint) declaram os bancos
em `state.databases`. O backup tira um snapshot **consistente** pela API do SQLite, com o banco em
uso, e o restore confere hash e `integrity_check`. Nunca trabalhe com um banco SQLite vivo dentro de
pasta sincronizada (Drive ou OneDrive).

## 6. Mandar para o GitHub (push)

Push é sempre pedido explícito: *"manda pro GitHub"*, *"faz o push"*.

Antes do push, o Claude roda `/os:security` (working tree, histórico, `.gitignore` e remoto) e o
hook `pre-push` confere as verificações declaradas. Achado bloqueante interrompe.

O Claude também não deve rodar git destrutivo (`push --force`, `reset --hard`, `checkout --`...):
o guarda `PreToolUse` do plugin `os` 0.1.4 barra o comando, e, se você quiser a operação, roda você
mesma. Desde 2026-10-16 ele **está ativo** (plugin `0.1.4`; o guarda roda a partir da worktree principal da plataforma; teste ao vivo bloqueou `git checkout --` e
liberou `git status`). O andamento das revisões independentes dele (QA + Security)
fica no `docs/STATE.md` ([02](02-MANUAL-COMPLETO.md), seção 11).

O remoto é sempre privado. Se a dimensão `remote` do `eos check` disser `remoto PUBLICO`, é
incidente: avise o Claude.

## 7. Fontes externas no meio do trabalho

Se o projeto lê o SharePoint e ele estiver indisponível, o `eos check` mostra
`Operacao: DEGRADED` e *"fonte externa indisponível"*. Isso **não** é perda: a segurança continua
`SAFE`. O trabalho que não depende da fonte segue normalmente.

## 8. Quando o projeto ficou parado por meses

Use `/os:resume` (ou *"vamos voltar no projeto X"*). Ele reconstrói pelo repositório e sinaliza:
STATE mais velho que o último commit, working tree com muita coisa, falta de remoto, última atividade
há mais de 30 dias. Se o projeto não tiver `STATE.md`, ele diz que o projeto não sobrevive à perda
de conversa e propõe criar.

## 9. Fechar

Sempre com `/session-close`. Ver [07 — Como encerrar uma sessão](07-COMO-ENCERRAR-UMA-SESSAO.md).
