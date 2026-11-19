# Hooks de Git desta plataforma

Guarda-corpos **locais** que barram erro previsível antes de ele entrar no histórico ou sair para o remoto. Subfase 2.6.

Eles **orquestram** o que já existe — `security-scan.ps1`, `doctor.ps1`, a suíte declarada no manifesto — e não implementam verificação própria. Detector novo aqui significaria dois detectores divergindo em silêncio, que é o defeito que esta plataforma já pagou mais de uma vez.

## Instalar

```bash
.\scripts\install-hooks.ps1
```

Idempotente: rodar de novo não regrava nada. O mecanismo é uma linha — `core.hooksPath` apontando para a pasta versionada `githooks/`.

| Comando | O que faz |
|---|---|
| `.\scripts\install-hooks.ps1` | ativa. Sai `0` quando terminou instalado |
| `.\scripts\install-hooks.ps1 -Verificar` | **só diagnostica.** Sai `0` instalado, `1` faltando algo |
| `.\scripts\install-hooks.ps1 -Reparar` | autoriza sobrescrever um `core.hooksPath` que aponta para outro lugar |

**Clone novo:** `scripts/bootstrap.ps1` chama o instalador. Nada precisa ser copiado à mão para `.git/hooks` — e é deliberado: `.git/` não viaja num clone, então hook que mora lá depende de alguém lembrar de recriá-lo.

**Por que não há cópia.** O que não é copiado não diverge da origem: não existe uma segunda versão do hook escondida em `.git/hooks` para ficar velha sozinha.

**O que isso NÃO garante**, e a frase anterior aqui prometia demais — achado do `security-reviewer`: o que roda é o arquivo **como está no checkout**, não o arquivo que a revisão leu. Modificação não commitada em `githooks/` ou em `scripts/hook-*.ps1` vale no próximo commit; e como `core.hooksPath` é **relativo**, trocar de branch ou fazer checkout de um PR troca os hooks que vão rodar, **sem reinstalar nada**. Essa é a diferença real em relação a `.git/hooks`, que não acompanha o checkout. Para repositório privado de uma mantenedora só, é aceitável — mas é fato, não garantia.

O que **tem** detector: o shim ficar para trás da versão que o código espera. Cada shim carrega `# os-hooks-versao: N`, e o `/os:doctor` acusa quando não bate.

## Os três hooks

### `commit-msg` — estrutura da mensagem

Três regras, todas **estruturais**. Convenção estilística não entra: bloquear gosto transforma o hook em coisa que se contorna por hábito, e hook contornado por hábito não protege nada.

1. o assunto não pode ser vazio;
2. **se existir uma linha 2, ela tem de ser vazia**;
3. o assunto não pode passar de 100 caracteres.

A regra 2 vem de um defeito real: em 2026-09-22 o commit de fechamento da 2.5 foi criado sem a linha em branco separadora, e o assunto engoliu o primeiro parágrafo inteiro do corpo — 350 caracteres numa linha que `git log --oneline` e toda interface de repositório truncam. O conteúdo estava certo; a estrutura, não. A regra 3 existe porque a 2 sozinha não alcança a mesma frase escrita numa linha só, sem corpo; o limite é generoso de propósito — a convenção do Git recomenda 50 — para não virar regra de estilo.

**Não bloqueiam:** comentários que o próprio git injeta, o diff do `--verbose`, e `fixup!` / `squash!` / `amend!`, que o `rebase --autosquash` exige numa linha só.

### `pre-commit` — segredo, rápido

Roda `security-scan.ps1 -SemHistorico -SemRede`. Medido: **8,2 s** contra 93 arquivos.

> **Ele varre o disco, não o índice — e isso muda o que o `ok` significa.**
>
> | Situação | O que acontece |
> |---|---|
> | `git add` de um arquivo com segredo, e depois o segredo é apagado **só no disco** | o blob com o segredo **entra no commit** e o hook aprova. O `pre-push` completo barraria depois, mas aí já há commit local |
> | arquivo **não rastreado** com segredo | **barra um commit que não o contém** |
>
> As duas direções estão registradas de propósito: barrar demais ensina `--no-verify` tão rápido quanto barrar de menos. Ler o conteúdo do índice está no backlog como item nominal — não foi feito aqui porque criaria superfície nova dentro do scanner, que é o que a 2.6 evitou.

Não roda a suíte. Não varre o histórico nem consulta a rede — as duas áreas saem com **lacuna declarada** no relatório, nunca como aprovadas. Não altera arquivo, não faz `git add`, não corrige nada.

Escreve em `artifacts/hooks/`, **nunca** em `artifacts/review/`: aquele é a evidência das revisões independentes, e um hook que a regravasse a cada commit destruiria a evidência do fechamento em curso. Há caso de teste que mede isso por SHA-256.

### `pre-push` — o portão antes do remoto

Quem compõe é o **manifesto**, não o hook:

```yaml
verificacao:
  hooks:
    pre_push:
      - "doctor"
      - "security"
```

**Lista de bloco, não de fluxo.** O leitor de manifesto desta plataforma não lê `["a", "b"]` — é o item 42 do backlog, e ele devolveria a linha inteira como um valor só. O hook detecta essa forma, **barra** e diz que a causa é o formato da lista, em vez de acusar erro de digitação num valor que você escreveu certo.

Vocabulário **fechado**: `security`, `doctor`, `tests`, `nenhum`. Valor fora dele **barra**, nomeando o valor — o que o leitor não entende nunca pode virar *"então não precisa"*.

| Declaração | O que acontece |
|---|---|
| campo ausente | padrão: `doctor` + `security`. Ausente não é "não verifique" e também não autoriza impor o caro |
| `["nenhum"]` | desligado **explicitamente**. A diferença para o campo ausente é a diferença entre "não quero" e "não pensei" |
| lista vazia (`[]`) | **o mesmo que `["nenhum"]`**, e cai na mesma mensagem honesta. Era um terceiro comportamento calado — nada rodava e o hook imprimia aprovação. Achado do `qa-reviewer`, confirmado por execução |
| lista | exatamente o que está ali, do mais barato para o mais caro |

`tests` **não** entra no padrão: a suíte desta plataforma leva ~12 min, e impor isso a todo push seria o "executa tudo porque existe" — cujo efeito real é ensinar `--no-verify`.

## Códigos de saída

| Código | Significa |
|---|---|
| `0` | passou |
| `1` | reprovou: achou o que bloqueia |
| `2` | **não conseguiu verificar** — e isto barra também |

O `2` é a regra que mais importa e é a política 4.5 aplicada ao hook: *"não consegui conferir" nunca vira "está bom"*. Scanner que não rodou não autoriza commit nenhum.

## `--no-verify` existe

```bash
git commit --no-verify
git push --no-verify
```

Isto **não** é combatido, e nenhum mecanismo aqui tenta impedi-lo. Fingir que hook local é incontornável seria falsa garantia — a forma exata que esta plataforma trata como pior que lacuna.

**As três fronteiras, e cada uma responde uma coisa:**

| Camada | O que é | Contornável? |
|---|---|---|
| hooks (2.6) | feedback local rápido, na máquina de quem escreve | **sim**, por desenho |
| `pre-push` | portão antes de o histórico sair | sim — mesmo mecanismo |
| CI (2.8) | verificação **independente**, fora da máquina | não pelo autor do commit |

Hook local **não é fronteira de segurança**. Ele existe para que o erro previsível seja pego em 8 segundos em vez de numa revisão. Proteção de branch no servidor não está disponível neste repositório privado no plano atual — por isso a CI da 2.8 é a camada que vale, e não esta.

## Quando um hook barra

A mensagem sempre diz **o quê** e **o que fazer**. Os relatórios da execução ficam em `artifacts/hooks/`:

| Arquivo | De quem |
|---|---|
| `pre-commit-security.md` | varredura rápida do `pre-commit` |
| `pre-push-security.md` | varredura completa do `pre-push` |
| `pre-push-doctor.md` / `.json` | diagnóstico do `pre-push` |

Se o achado for legítimo e deliberado, registre a **exceção** em `project.yaml` (ADR-0010) — não contorne com `--no-verify`. Exceção registrada aparece no relatório com a severidade original e volta a bloquear em `-ParaPublicacao`.

## Guarda de git destrutivo para agentes (PreToolUse)

Este não é hook do Git: é hook do **Claude Code**, declarado pelo plugin `os` em `hooks/hooks.json` e implementado em `hooks/guarda_git.py`. Roda antes de toda chamada das ferramentas `Bash` e `PowerShell` de qualquer sessão ou subagente que carregue o plugin.

**Por quê.** Na revisão r13 um subagente implementador rodou `git checkout -- tests/suites/scanner.ps1` para desfazer as próprias edições — comando proibido pelo `CLAUDE.md`. Não houve perda, mas a regra era só texto. O guarda a torna mecânica.

**O que bloqueia** (saída `2`; o motivo e o caminho alternativo vão para o modelo): `checkout` com `--`, `.`, `--force` ou `-B`; `switch --force/--discard-changes/-C/--force-create`; `restore` (exceto `--staged` sem `--worktree`); `reset --hard/--merge/--keep`; `clean -f` (exceto dry-run); `rm -f` (exceto `--cached`, que só mexe no índice); `push` com `--force`/`-f`, `--force-with-lease`, `--force-if-includes`, `--delete`/`-d`, `--mirror`, `--prune`, `+ref` ou `:ref`; `pull --rebase/-r`; `rebase`; `commit --amend`; `stash drop/clear`; `branch -D/-M/-C/-f`; `tag -d/-f`; `worktree remove --force`; `worktree prune`; `update-ref -d`; `reflog expire`; `gc --prune=now`; `filter-branch`; `filter-repo`; **escrita** de `core.hooksPath` (ler passa), inclusive por `git -c`, `--config-env` e `GIT_CONFIG_*`/`$env:GIT_CONFIG_*`.

**Como lê o comando.** No dialeto da ferramenta: `Bash` com as regras do bash (`\` escapa fora de aspas, `\`+quebra de linha continua), `PowerShell` com as do PowerShell (crase escapa e continua, `\` é literal). Segmenta por `;`, `&&`, `||`, `|`, quebra de linha e subexpressão; avalia `$(...)` e crase **dentro** de aspas duplas; tolera `git -C`, `git -c`, `git.exe` e caminho completo; avalia por dentro `bash/sh -c` (inclusive com `-o opt` e flags combinadas como `-euo pipefail`), `powershell/pwsh -Command` (inclusive com `-ExecutionPolicy Bypass`, valor colado `-ExecutionPolicy:Bypass` e as demais opções que recebem valor), `-EncodedCommand` (decodificado, também colado por `:`, entre aspas ou com `--`; payload UTF-16 inválido é decodificado com substituição, não liberado) e `cmd /c`; avalia o corpo de heredoc **entregue a um shell** (`bash <<'EOF'`). Abreviação de opção longa conta desde 1 letra: o Git rejeita prefixo ambíguo, então bloquear um ambíguo não barra nada que funcionaria. O comando que aparece só como **texto** (mensagem de commit, `grep`, `echo`, heredoc para arquivo) não bloqueia. Os casos estão em `eos/tests/test_guarda_git.py`.

**O que NÃO cobre** — não é fronteira contra código hostil: `eval`, variável e montagem dinâmica (`$g='git'; & $g reset --hard`); alias do Git definido fora do comando e `pull.rebase=true` já configurado; script `.ps1`/`.sh`/`.py` chamado que contenha o comando (inclusive `bash script.sh`, `powershell -File`); here-string do PowerShell entregue por pipe; `git checkout <ref> <arquivo>` sem `--` (indistinguível de troca de branch); `xargs`/`find -exec`; `merge/am/cherry-pick/revert --abort`, `git stash` puro e `stash pop`, `branch -m`, `update-ref <ref> <sha>`, `Set-Item env:GIT_CONFIG_*`; `core.hooksPath` por via indireta — `include.path` para arquivo que o defina, `GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM` apontando arquivo com ele, `[Environment]::SetEnvironmentVariable`, edição direta de `.git/config` (ferramentas Edit/Write ou `>>`); aninhamento de shells/subexpressões além de `MAX_PROFUNDIDADE` (4); valor de opção longa separado por espaço só é reconhecido para as opções listadas em `VALOR_LONGO` — fora delas, um valor que comece por `-` pode ser lido como flags (falso positivo, nunca negativo); `--no-verify` (deliberadamente não combatido, ver acima); ferramentas que não sejam `Bash`/`PowerShell`.

**Se o guarda falhar, ele não trava a sessão.** No Claude Code só a saída `2` bloqueia. O `hooks.json` não chama o arquivo direto: chama `py -3.13 -I -c "...runpy.run_path..."` com o caminho como argumento, e esse invólucro **sai 0 se o arquivo não existir**. Sem ele, um `${CLAUDE_PLUGIN_ROOT}` não expandido faria o Python sair com `2` (*can't open file*) e **bloquearia todo comando** — medido. O invólucro deixa passar o `exit 2` do guarda e faz exceção não tratada sair `0` (`sys.excepthook`); falha interna do guarda também sai `0`. O hook declara `"shell": "powershell"`: medido em 2026-10-16, sem isso e sem Git Bash visível o Claude Code roda o hook em modo de fallback e trata **qualquer** saída ≠ 0/2 como bloqueio. Também medido: no `0.1.2` o guarda rodava e saía `2`, mas `powershell -Command` devolvia `1` (não bloqueante) — por isso o comando termina em `; exit $LASTEXITCODE`. O invólucro procura o guarda primeiro em `$env:CLAUDE_PLUGIN_ROOT` e depois no argumento, **só se for caminho absoluto com unidade** (`C:`): um argumento sem unidade (`/hooks/...`) resolveria para a raiz do drive, onde qualquer conta local pode plantar um arquivo (achado de segurança da r17; há teste do arquivo plantado). **A falha aberta é silenciosa:** sem `py`, sem a 3.13, sem o arquivo ou com exceção ao carregar, o hook sai `0` e o Claude Code descarta o stderr — o guarda simplesmente não roda. Para conferir que está ativo numa máquina, faça o teste ao vivo descrito em "Ativação". `-I` (modo isolado) impede que um `.py` no diretório corrente seja importado no lugar da stdlib. Há teste que executa o comando **exato** do `hooks.json`, com a raiz real, com o placeholder não expandido e com raiz inexistente.

**Quando a titular quer a operação bloqueada**, ela a roda ela mesma: no prompt do Claude Code, `! git reset --hard ...` executa direto no terminal, sem passar pelas ferramentas do agente — ou num terminal comum. O agente não deve tentar contornar o guarda.

**Ativação.** Medido em 2026-10-16 (sessões `claude -p` sem `--plugin-dir`): como o marketplace `emmily-platform` é do tipo **diretório** (`known_marketplaces.json`: `installLocation` = a worktree principal da plataforma), o `${CLAUDE_PLUGIN_ROOT}` do hook resolve para `C:\AI-WORKSPACE\_platform\emmily-ai-project-os`, e o guarda que roda em **todas** as sessões é o `hooks/guarda_git.py` **dessa worktree**, não a cópia em `~\.claude\plugins\cache\`. O `hooks.json` (a definição do hook) vem do plugin instalado, por isso mudança nele exige `claude plugin update os@emmily-platform` — a `version` sobe por PATCH (`0.1.1`–`0.1.4`) para isso. Consequências: mudar o `guarda_git.py` na worktree principal vale na próxima chamada, sem update; se essa worktree estiver numa ref sem o guarda, ou o arquivo quebrado no meio de uma edição, o guarda **não roda** (falha aberta silenciosa). Mantenha a worktree principal na `main` publicada; editar o guarda numa worktree separada, como esta plataforma já faz. **Teste ao vivo** (o único que prova que o guarda roda): num repositório descartável com um arquivo modificado, `claude -p "rode com a ferramenta PowerShell: git checkout -- f.txt" --allowedTools "PowerShell(git checkout:*)"` tem de responder com a mensagem `BLOQUEADO pelo guarda` e o arquivo continuar modificado.

## O `/os:doctor` diagnostica, e não instala

A dimensão `hooks` responde se os guarda-corpos estão ativos neste clone:

| Status | Quando |
|---|---|
| `PASS` | instalados e na versão esperada — ou o projeto não versiona hooks, que é fato, não defeito |
| `WARN` | não instalados, apontando para outro lugar, ou algum shim fora da versão |
| `INCONCLUSIVO` | a pergunta não pôde ser respondida |

`WARN`, e não `FAIL`: hook ausente não torna o projeto incorreto — torna-o desprotegido contra erro previsível, que é coisa diferente. O doctor **não instala**: ele diz qual comando instala. Há caso que mede que ele não mexeu em `core.hooksPath`.
