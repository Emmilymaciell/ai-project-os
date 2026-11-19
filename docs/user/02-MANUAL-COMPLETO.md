# 02 — Manual completo

Referência de uso do Emmily AI Project OS. Os documentos 05 a 15 aprofundam cada tema; este manual
dá a visão inteira e serve de índice de conceitos.

---

## 1. Glossário

| Termo | Significado prático |
|---|---|
| **Projeto** | trabalho com continuidade, estado e valor em ser retomado. Script de uso único é tarefa, não projeto |
| **Sessão** | uma conversa com o Claude. Descartável por definição |
| **Plataforma** | este repositório: `C:\AI-WORKSPACE\_platform\emmily-ai-project-os` |
| **Registry** | a pasta `registry/projects/`, com um arquivo YAML por item do ecossistema |
| **Contrato** | o YAML de um projeto: identidade, onde mora, remoto, nuvem, ambiente, segredos, backup, meta de nível |
| **Motor (`eos`)** | o programa Python que mede, faz backup, restaura e certifica: `py -3.13 -m eos` |
| **Plugin (`/os:*`)** | os comandos do Claude Code que funcionam em qualquer pasta |
| **Git** | o sistema que guarda o histórico de versões, dentro da pasta `.git` do projeto |
| **Commit** | uma versão salva no histórico. Aqui, só com o seu pedido |
| **Remoto** | a cópia do histórico no GitHub, **privada** |
| **Branch** | uma linha de trabalho paralela dentro do mesmo projeto |
| **Worktree** | uma segunda pasta de trabalho ligada ao mesmo repositório (usada por agentes paralelos) |
| **WIP** | *work in progress*: arquivos modificados ou novos ainda não commitados |
| **Stash** | gaveta temporária do Git. **O motor não protege stash** |
| **Bundle** | um arquivo único com o histórico Git inteiro, guardado no Drive |
| **Snapshot** | cópia consistente de um momento (do WIP ou de um banco SQLite) |
| **Manifesto de backup** | o JSON que descreve um backup; é gravado por último. Sem manifesto, não há backup |
| **Certificação** | prova de restauração: restaura numa pasta temporária, confere e roda o teste do projeto |
| **Nível L0–L6** | quanto o projeto sobrevive sem esta máquina e sem esta conversa |
| **SAFE / AT_RISK / UNSAFE** | a segurança do projeto contra perda |
| **OK / DEGRADED** | se o projeto consegue operar agora (ex.: SharePoint disponível) |
| **STATE.md** | onde o projeto está agora: fase, último marco, próximo passo |
| **HANDOFF** | documento para outra pessoa, máquina ou conta assumir |
| **ADR** | registro de decisão de arquitetura (`docs/decisions/ADR-NNNN-*.md`) |
| **Human gate (H1–H5)** | ponto em que o Claude para e precisa de você |
| **Titular** | você, Emmily: dona declarada dos projetos e quem decide |

---

## 2. Onde mora cada coisa

| Lugar | Guarda | Não guarda |
|---|---|---|
| **Computador** (`C:\AI-WORKSPACE\`) | a execução ativa: código, `.venv`, saídas, bancos vivos | não é cópia de segurança de nada |
| **GitHub privado** (`github.com/Emmilymaciell/<repo>`) | código, scripts, histórico, branches, tags, STATE, HANDOFF, ADRs, runbooks, testes, configuração sem segredo | dados brutos, documentos com dado de terceiro, segredos, trabalho não commitado |
| **Google Drive** (`EMMILY PROJECT CLOUD/`) | dados brutos (PDF, DOCX, XLSX, imagens, datasets), bundles Git, snapshots de WIP e de banco, manifestos, certificados | repositório Git **ativo** (nunca trabalhe com Git dentro de pasta sincronizada) |
| **Bitwarden** | senhas, tokens, chaves de API, códigos de recuperação | nada mais |
| **SharePoint / OneDrive corporativo** | documentos do contrato Programa, lidos pelos projetos | **não é backup de projeto** |

Estrutura do Drive (raiz lógica, igual em qualquer máquina):

```
EMMILY PROJECT CLOUD/
  00 PLATFORM/        a plataforma
  01 PROG/            projetos e acervos PROG
    <id>/             cloud.drive_root do projeto
      dados/<pasta>                      espelho das pastas cloud-mirror (eos mirror)
      dados-anteriores/<carimbo>/<pasta> versões que um espelho substituiu (nunca apagadas)
  02 PERSONAL/
  03 UNIVERSITY/
  04 PORTFOLIO/
  05 LAB/
  99 RECOVERY/
    git-recovery/<id>/<carimbo>/<id>.bundle
    wip-snapshots/<id>/<carimbo>/wip.tar.gz
    database-snapshots/<id>/<carimbo>/<banco>.gz
    manifests/<id>/<carimbo>.json        (backup)  e  cert-<carimbo>.json  (certificação)
                   ownership-<carimbo>.json (propriedade)  e  mirror-<carimbo>.json (espelho de dados)
    disaster-recovery/
    emergency-preservation/
```

Workspace local:

```
C:\AI-WORKSPACE\
  _platform\emmily-ai-project-os\      a plataforma
  _platform\_runs\RUN-20261008-001\     journal do programa vNext (fora do Git, com cópia no Drive)
  work\prog\<id>\                       projetos PROG novos ou extraídos
  personal\<id>\, university\<id>\, portfolio\<id>\   projetos dessas categorias
  ai-lab\<id>\                          experimentos (ex.: conversor-utm, portability-lab)

O nascimento protegido (`eos new`) escolhe a pasta pela categoria: PROG `work\prog`, PERSONAL
`personal`, UNIVERSITY `university`, PORTFOLIO `portfolio`, LAB `ai-lab`, PLATFORM `_platform`.
```

Vários projetos antigos continuam em pastas **legadas** do perfil (`%USERPROFILE%\PROG_Relatorio_G2_Automacao`,
por exemplo). Isso é deliberado: a regra é **proteger, verificar, registrar, certificar**, e só
depois, se valer a pena, mover. O contrato aponta o caminho com variáveis (`${USERPROFILE}`,
`${AI_WORKSPACE}`), e por isso funciona em outra máquina.

Exceção registrada: o Organizador Dynatest continua dentro do OneDrive (ADR-0002). Ela não abre
precedente: **projeto novo nunca nasce em pasta sincronizada**.

---

## 3. O registry e o contrato

Cada item do ecossistema tem um arquivo `registry/projects/<id>.yaml`. Ele declara **intenção**
(o que deveria ser verdade). O estado medido (nível, último backup) não fica ali: é calculado pelo
motor a cada verificação.

As seções, em linguagem simples:

| Seção | Responde |
|---|---|
| `identity` | id, nome, tipo (`PROJECT`, `COLLECTION`, `EXTERNAL_SOURCE`, `ARCHIVE`), categoria, status, criticidade |
| `workspace.local_path` | onde fica na máquina, com variáveis (`${AI_WORKSPACE}\...`) |
| `git` | branch padrão, remoto (sempre `https://github.com/...`), visibilidade (`private`), política de worktrees |
| `cloud.drive_root` | a pasta do projeto no Drive, ex.: `01 PROG/prog-relatorio-g2` |
| `external_sources` | fontes externas (SharePoint) e se a operação depende delas |
| `state` | onde vive o estado: `git-only`, `sqlite` (com a lista de bancos) ou `files` |
| `data` | pastas de dados e a política de cada uma: `cloud-mirror`, `reproducible`, `external`, `none` |
| `environment` | linguagem, versão, manifesto de dependências, bootstrap, comando de teste e de *smoke* |
| `secrets` | onde está o manifesto de **nomes** de segredo e onde vivem os valores (`bitwarden`, `local-env`, `none`) |
| `backup` | se o WIP entra no snapshot e o que é excluído |
| `ai.canonical` | os arquivos neutros de IA que reconstroem o contexto (ex.: `docs/STATE.md`, `AGENTS.md`) |
| `portability.target_level` | a meta de nível (em geral `L6`) |
| `certification` | previsto para a evidência da última certificação, mas **nada o escreve hoje**: a evidência vive em `99 RECOVERY/manifests/<id>/cert-<carimbo>.json` |
| `ownership` | titular, criadoras, contribuidores, contas de ferramenta, contexto contratual, licença, terceiros, identidades Git, política de assinatura. Opcional no schema, obrigatória por política para `PROJECT` (o `ownership-check` reprova sem ela); ver [10](10-PROPRIEDADE-E-PROVENIENCIA.md) |

A validação **falha fechado**: campo com nome errado é erro, não "campo ausente". Para conferir
todos: `py -3.13 -m eos validate`.

Políticas de dados, porque elas decidem o "posso apagar a pasta?":

| Política | Significa | Efeito |
|---|---|---|
| `cloud-mirror` | a pasta precisa de cópia conferida na nuvem | `eos mirror <id>` copia para `<cloud.drive_root>/dados/<path>`. A pasta deixa de bloquear "apagar clone" e "trocar de computador" quando o **último espelho verificado** tem cada arquivo atual com o mesmo tamanho e data de modificação; arquivo novo ou alterado depois volta a bloquear até o próximo `eos mirror` |
| `reproducible` | dá para gerar de novo (há script) | não bloqueia |
| `external` | a fonte é outra (ex.: cópia do SharePoint) | não bloqueia |
| `none` | descartável (cache, `egg-info`) | não bloqueia |

Qualquer arquivo **ignorado pelo Git e não declarado** em `data` bloqueia "apagar clone" e "trocar
de computador": se ninguém disse o que ele é, o motor supõe que só existe ali.

---

## 4. O motor `eos`

Roda no PowerShell, na raiz da plataforma, com Python 3.13 (exige 3.12 ou mais):

```powershell
cd C:\AI-WORKSPACE\_platform\emmily-ai-project-os
py -3.13 -m eos <comando>
```

| Comando | O que faz | Altera alguma coisa? |
|---|---|---|
| `validate` | valida todos os contratos do registry | não |
| `status [--sem-rede]` | uma linha por projeto: nível, segurança, operação, respostas | só reconstrói o índice derivado `registry.db` |
| `check <id> [--json] [--sem-rede]` | o diagnóstico de um projeto, com as três respostas | não |
| `backup <id>...` ou `backup --todos` | bundle Git + WIP + bancos para o Drive, conferidos por hash | só **acrescenta** na nuvem; não toca no projeto |
| `certify <id> [--manter]` | restaura numa pasta temporária, confere, roda o smoke e grava o certificado | grava o certificado na nuvem; apaga só a pasta temporária que ela mesma criou (`--manter` a preserva) |
| `restore <id> --para <dir> [--fonte auto\|cloud\|github] [--com-dados]` | restaura para uma pasta **vazia** e confere. `--com-dados`: depois do Git, baixa o último espelho `cloud-mirror` verificado para `<dir>/<path>` e confere tamanho e md5 de cada arquivo; arquivo que o Git já trouxe com outro conteúdo **não** é sobrescrito: o restore reprova | cria a pasta destino; recusa destino com conteúdo |
| `mirror <id>...` ou `mirror --todos` | espelha as pastas `cloud-mirror` do contrato para `<cloud.drive_root>/dados/<path>`: só sobe o que mudou (tamanho + md5), confere cada arquivo na nuvem depois da cópia, recusa nome de segredo e atalho (symlink/junção). `--todos` = só projetos com alguma pasta `cloud-mirror` | só **acrescenta** na nuvem: nada é apagado lá; a versão anterior de um arquivo alterado vai para `<drive_root>/dados-anteriores/<carimbo>/`. Grava o manifesto `99 RECOVERY/manifests/<id>/mirror-<carimbo>.json` e uma cópia no journal da máquina. Não toca no projeto |
| `prepare-machine-migration` | o que falta para trocar de computador, projeto a projeto | não ("Nada foi alterado") |
| `index` | reconstrói o índice SQLite derivado | só o índice |
| `resolve <texto>` | mostra como `${VARS}` resolvem nesta máquina | não |
| `new <id> --name "<nome>" --category <CAT> [--runtime python\|node\|none] [--sem-remoto] [--sem-rede] [--dry-run] [--certificar] [--descricao "<frase>"]` | nascimento protegido de um projeto ([05](05-COMO-CRIAR-UM-PROJETO.md)); antes de criar o remoto roda a varredura de segurança (achado = para, nada é publicado); `--sem-rede` implica `--sem-remoto`; saída `1` = nasceu com pendência (H2 do remoto) | cria pasta, repositório com commit inicial, contrato na plataforma (sem commit), remoto privado, pasta no Drive e primeiro backup; `--dry-run` não cria nada |
| `ownership-check <id> [--json]` | propriedade e proveniência: PASS/WARN/FAIL/N/A em 10 itens; saída `1` só com FAIL | não |
| `ownership-init <id>` | gera os arquivos de proveniência que faltam num projeto existente; a pasta é a mesma que `check`/`backup` usam (o override do `machine.yaml` vence o contrato) e precisa ser a raiz de um repositório Git, senão recusa | escreve só arquivos novos no projeto; nunca cria a pasta; nunca sobrescreve; não commita |
| `ownership-certify <id> [--tag]` | roda o check, recusa com FAIL e grava o certificado em `99 RECOVERY/manifests/<id>/ownership-<carimbo>.json` e no journal da máquina; `--tag` cria tag assinada `ownership-AAAAMMDD` | grava evidência na nuvem e na máquina, nunca no projeto; `--tag` cria uma tag (nunca sobrescreve) |

**Códigos de saída:** `0` ok; `1` alguma verificação reprovou ou algo não é seguro; `2` erro de uso
ou de execução.

O que o motor **nunca** faz: apagar, mover ou sincronizar na nuvem (não existe verbo destrutivo de
nuvem nele; o espelho de dados é cópia que só acrescenta), commitar, fazer push, sobrescrever
projeto existente. A única exceção ao "push" é o `eos new`, que publica o commit inicial no remoto
privado recém-criado, sem forçar nada.

---

## 5. O plugin `/os:*`

São skills do Claude Code instaladas como plugin `os`. Funcionam em qualquer pasta, inclusive onde
o projeto ainda não existe.

| Comando | Quando | O que faz |
|---|---|---|
| `/os:new-project` | ideia que merece virar projeto | discovery (no máximo 4 perguntas), classificação, plano, **espera seu sim**, instancia o template |
| `/os:resume` | voltar a algo parado | reconstrói o contexto pelo repositório, compara com o Git, mostra a retomada |
| `/os:status` | "onde estou?" | estado resumido do projeto ou do workspace inteiro |
| `/os:checkpoint` | **só a seu pedido** | INSPECT → TEST → QA → SECURITY → STATE/CHANGELOG → DIFF → **APPROVAL** → COMMIT → TAG (se marco) |
| `/os:doctor` | algo parece fora do lugar, antes de handoff | o projeto como sistema é coerente e retomável? Não roda testes nem varre segredo |
| `/os:security` | antes de push, release ou handoff | varre working tree, histórico, `.gitignore` e remoto contra segredo e dado de terceiro |
| `/os:handoff` | outra pessoa, máquina ou conta vai assumir | gera `docs/handoff/HANDOFF-<data>.md`, testando o contrato de portabilidade antes |

Planejados e ainda não existentes: `/os:eval`, `/os:release`, `/os:portfolio`, `/os:export-project`.

Se o plugin instalado parecer desatualizado, ver [15 — Troubleshooting](15-TROUBLESHOOTING.md).

---

## 6. O protocolo de sessão

| Comando | O que faz | O que **não** faz |
|---|---|---|
| `/session-start` | reconstrói o estado pelo repositório, roda o `doctor.ps1`, mostra divergências, propõe o número e o nome da sessão, mostra o briefing e **para** | não edita arquivo (as ferramentas de edição ficam bloqueadas), não commita, não começa tarefa |
| `/session-close` | para o desenvolvimento, pergunta "o que só existe na conversa?", grava no disco, atualiza `docs/STATE.md` e `docs/sessions/SESSIONS.md`, confere o Git e **para** | **não commita** (isso é `/os:checkpoint`, a seu pedido) |

O briefing do `/session-start` termina com *"Contexto reconstruído. Nenhuma alteração foi
realizada."* O relatório do `/session-close` termina com *"Handoff concluído. Nenhuma nova
implementação foi iniciada."* Se não terminarem assim, algo saiu do protocolo.

Detalhes em [06](06-COMO-TRABALHAR-EM-UM-PROJETO.md) e [07](07-COMO-ENCERRAR-UMA-SESSAO.md).

---

## 7. Os arquivos que guardam a memória do projeto

| Arquivo | Papel | Quem escreve |
|---|---|---|
| `docs/STATE.md` (ou `STATE.md`) | **onde o projeto está agora**. Snapshot, não diário | o Claude, antes de cada checkpoint e no `/session-close` |
| `docs/decisions/ADR-*.md` | por que está assim. Decisão registrada não se reabre sem fato novo | o Claude, quando há decisão durável |
| `docs/sessions/SESSIONS.md` | o que aconteceu em cada sessão (mais recente no topo) | `/session-close` |
| `CHANGELOG.md` | o que mudou entre versões | `/os:checkpoint` |
| `HANDOFF.md` / `docs/handoff/` | como outra pessoa assume | `/os:handoff` |
| `CLAUDE.md`, `AGENTS.md` | como uma IA trabalha aqui (adaptadores) | raramente muda |
| `project.yaml` | manifesto do projeto: classificação, verificação exigida | `/os:new-project` e `/os:checkpoint` |
| `secrets.manifest` / `.env.example` | **nomes** dos segredos, nunca valores | quando um segredo novo aparece |
| `PROVENANCE.md`, `OWNERSHIP.md`, `AUTHORS.md`, `NOTICE`, `.github/CODEOWNERS` | origem, titularidade, autoria, terceiros | o nascimento protegido (ou o Claude, a seu pedido, em projeto antigo, sem sobrescrever); depois, você revisa |

A memória automática do Claude e o histórico do chat são **apoio**, nunca fonte única de nada.

---

## 8. Backup, restauração e certificação (resumo)

Um backup do motor tem **três artefatos e um manifesto**:

1. **Histórico Git** → `git bundle --all` (todas as branches e tags), verificado.
2. **WIP** → um `wip.tar.gz` com os arquivos modificados e novos de **todas** as worktrees sujas.
3. **Bancos SQLite declarados** → snapshot pela API de backup do SQLite, comprimido.
4. **Manifesto** → gravado **por último**, depois de cada artefato subir e ser conferido por hash.

Restauração: sempre para pasta **vazia**; fonte `auto` (GitHub se houver remoto, completado pelo
bundle), `cloud` (só o Drive) ou `github`. Toda peça é conferida por SHA-256 antes de ser usada.

Certificação: restaura numa pasta temporária, confere refs, HEAD, WIP e bancos, verifica que os
arquivos canônicos estão lá, roda o `smoke_command` do contrato e grava o certificado. Vale **30
dias** para o nível L6.

Detalhes, limites e cenários de desastre em [08 — Backup e recovery](08-BACKUP-E-RECOVERY.md).

---

## 9. Níveis de continuidade (resumo)

| Nível | Nome | Exige (além dos anteriores) |
|---|---|---|
| L0 | Local Only | o projeto existe nesta máquina |
| L1 | Git Versioned | repositório Git com pelo menos um commit |
| L2 | Remote Protected | remoto **privado**, alcançável, com todas as branches e tags publicadas |
| L3 | Data Protected | backup atual na nuvem: bundle com as refs atuais, WIP atual, bancos com snapshot atual |
| L4 | Environment Reproducible | manifesto de ambiente e bootstrap; manifesto de segredos; nada de segredo rastreado; caminho por variável |
| L5 | Session Independent | arquivos canônicos presentes e `STATE.md` não mais velho que o último commit |
| L6 | Disaster Recovery Tested | certificação aprovada nos últimos 30 dias |

Detalhes em [13 — Health e continuity](13-HEALTH-E-CONTINUITY.md).

---

## 10. Fontes externas (SharePoint)

Alguns projetos Programa leem documentos do SharePoint do contrato. O registry modela isso como
`EXTERNAL_SOURCE` (`prog-sharepoint`) e cada projeto declara em `external_sources` se a **operação**
depende dela.

- O SharePoint **não** é backup de projeto. O contrato que tentar declará-lo como backup é recusado
  pela validação.
- Se o SharePoint estiver fora do ar, o projeto fica `Operação: DEGRADED`, mas a **segurança**
  continua `SAFE`. Não é alarme de perda.
- Cópias locais de documentos do SharePoint (pastas `tmp/`, por exemplo) são declaradas como
  `policy: external`: a fonte é o SharePoint.

---

## 11. Verificação: testes, revisores, segurança, hooks

| Natureza do trabalho | Verificação |
|---|---|
| código determinístico | `tests/` (no projeto: `.\tests\run-tests.ps1`) |
| comportamento de IA | `evals/` (quando houver o componente) |
| integração externa | teste de integração com mock |
| documento | validação de estrutura e conteúdo |
| dado sensível | varredura de segurança |

**Builder ≠ Evaluator (ADR-0007):** quem construiu não aprova o próprio trabalho a partir de
criticidade média. Os revisores `qa-reviewer` e `security-reviewer` são agentes **só-leitura**,
rodam em contexto isolado e leem evidência coletada por scripts determinísticos. O veredito tem três
valores: `APROVADO`, `REPROVADO` e `INCONCLUSIVO`, e **INCONCLUSIVO bloqueia como REPROVADO**.

| Criticidade | Revisão independente |
|---|---|
| baixa | nenhuma (auto-revisão) |
| média | QA |
| alta, ou com dado sensível | QA + Security |

**Hooks de Git** (ativados pelo `bootstrap.ps1`):

| Hook | Barra |
|---|---|
| `commit-msg` | mensagem sem assunto, sem linha em branco depois do assunto, ou assunto com mais de 100 caracteres |
| `pre-commit` | segredo no working tree (varredura rápida) |
| `pre-push` | push sem as verificações que o manifesto declara |

Eles são contornáveis com `--no-verify` **por desenho** (hook local não é fronteira de segurança).
Não contorne: se o achado for legítimo, registre a exceção (ADR-0010).

**Guarda de git destrutivo (hook do Claude Code, não do Git).** O plugin `os` 0.1.4 traz um hook
`PreToolUse` (`hooks/guarda_git.py`) que barra, nas ferramentas `Bash` e `PowerShell` do Claude e
dos subagentes, comandos como `git checkout --`, `restore`, `reset --hard`, `clean -f`,
`push --force`, `rebase` e `commit --amend`. Se você quiser uma dessas operações, rode você mesma
(`! git ...` no prompt do Claude Code, ou num terminal comum). Desde 2026-10-16 ele **está ativo** (plugin `0.1.4`; o guarda roda a partir da worktree principal da plataforma; teste ao vivo bloqueou `git checkout --` e
liberou `git status`). O andamento das revisões independentes dele (QA + Security)
fica no `docs/STATE.md`. Detalhes: `docs/runbooks/hooks.md`.

---

## 12. Agentes e modos de execução

O Claude decide **como conduzir** o trabalho e recomenda sem você pedir:

| Situação | Modo |
|---|---|
| tarefa simples | o próprio Claude |
| tarefa especializada | subagente |
| tarefas independentes entre si | subagentes em paralelo |
| mudanças independentes no mesmo repositório | worktrees (uma pasta por frente) |
| agentes que precisam conversar | Agent Team |
| fluxo grande e reproduzível | Dynamic Workflow |
| mudança enorme e particionável | batch |

Regras: dois agentes nunca escrevem na mesma worktree; revisão só-leitura pode ser paralela; quem
integra é o agente líder; nenhum agente guarda estado canônico só para si. Tarefas pesadas (suíte
completa, certificações) rodam **uma por vez**: a máquina já ficou sem memória uma vez.

Quando o Claude recomendar worktrees, ele deve dizer quantas, o nome de cada frente, a branch, o
objetivo, os arquivos de cada uma, o critério de conclusão e como integrar.

**Níveis de autonomia:** o nível corrente é **4** (editar e preparar commit; commitar só com
pedido; push só com aprovação).

---

## 13. Segredos (resumo)

Valor de segredo nunca entra no Git nem no backup. O Git guarda só **nomes**
(`secrets.manifest`, `.env.example`, `cofre.manifest` na plataforma). Os valores vivem no Bitwarden
(fonte de verdade planejada), no `.env` local ignorado, ou no gerenciador da própria ferramenta
(keyring do `gh`, configuração do `rclone`, sessão do Claude Code). Detalhes em
[12 — Segredos e Bitwarden](12-SEGREDOS-E-BITWARDEN.md).

---

## 14. Propriedade e assinatura (resumo)

Cada projeto declara quem é a titular, quem criou, quem contribuiu, que ferramentas ou contas foram
usadas sem autoria, o contexto contratual e os componentes de terceiros. Os commits são assinados
com chave SSH; para aparecerem como **Verified** no GitHub, a chave pública precisa estar registrada
lá como *signing key*. Detalhes em [10 — Propriedade e proveniência](10-PROPRIEDADE-E-PROVENIENCIA.md).

---

## 15. Linguagem natural: o que acontece por baixo

| Você diz | Por baixo | Para em você? |
|---|---|---|
| "Como estão meus projetos?" | `eos status` e leitura da tabela | não |
| "Esse projeto está seguro?" | `eos check <id>` | não |
| "Esse projeto está L6?" | `eos check <id>`: nível e dimensão `recovery` | não |
| "Faça backup" | `eos backup <id>` (ou `--todos`) | não |
| "Espelhe os dados deste projeto" | `eos mirror <id>` (ou `--todos`): pastas `cloud-mirror` para `<drive_root>/dados/`, só acrescenta | não |
| "Qual foi o último backup?" | `eos check <id> --json` → `dimensoes.backup.ultimo` | não |
| "Posso apagar essa sessão?" | `eos check <id>` → *Posso apagar esta sessão?* | não |
| "Posso apagar esse clone?" | `eos check <id>` → *Posso apagar a pasta local?*; **apagar** de fato é H3 | sim, para apagar |
| "Posso trocar de computador?" | `eos backup --todos`, `eos mirror --todos` e `eos prepare-machine-migration` | não |
| "Restaure este projeto" | `eos restore <id> --para <pasta vazia>`; o Claude escolhe uma pasta nova. *"...com os dados"*: `--com-dados` | só se o destino tiver conteúdo |
| "Certifique este projeto" | `eos certify <id>` | não |
| "Crie um projeto novo para X" | `/os:new-project` → plano + `eos new --dry-run` → seu sim → `eos new` | sim, aprova o plano (o sim cobre o commit inicial, o remoto privado e o push) |
| "Qual é a propriedade/proveniência deste projeto?" | `eos ownership-check <id>` e leitura dos arquivos | não |
| "Onde paramos?" | `/session-start` ou `/os:resume` | o Claude para depois do briefing |
| "Salva essa versão" | `/os:checkpoint` | sim, aprova o commit |
| "Manda pro GitHub" | push, depois de varredura de segurança | sim, push é sempre pedido explícito |
| "Encerra a sessão" | `/session-close` | não commita |
| "Ficou bom" / "Terminei" | **nada no Git**: no máximo, o Claude oferece o checkpoint em uma linha | — |

---

## 16. Arquivos desta máquina (fora do Git)

| Arquivo | Para quê |
|---|---|
| `%USERPROFILE%\.emmily-os\machine.yaml` | variáveis desta máquina (`AI_WORKSPACE`, `GDRIVE_REMOTE`, `GDRIVE_ROOT`), transporte de nuvem (`rclone` ou `drive-desktop`) e caminhos por projeto quando diferem do padrão |
| `%LOCALAPPDATA%\emmily-os\staging\` | área temporária do backup |
| `%LOCALAPPDATA%\emmily-os\registry.db` | índice derivado; pode ser apagado e reconstruído com `eos index` |
| `C:\AI-WORKSPACE\_platform\_runs\RUN-20261008-001\` | journal do programa vNext (eventos, relatórios, decisões levantadas) |

---

## 17. Limites conhecidos, declarados

O Project OS prefere declarar um limite a dar uma garantia falsa. Os principais:

- **Backup sem criptografia no cliente.** Vai para o seu Drive pessoal e privado; a criptografia
  depende do Bitwarden (ainda não instalado). Cada backup avisa isso no log e no manifesto.
- **Stash não é protegido.** Aplique ou transforme em branch.
- **Submódulos e symlinks no WIP** não são protegidos; viram pendência do backup.
- **Segredo dentro de arquivo de nome inocente** (`config.json`) não é detectado pelo nome.
- **Manifesto do backup não é assinado.** Aceito enquanto o Drive for pessoal e privado.
- **O rclone depende de um token OAuth.** Desde 2026-10-16 ele usa o client OAuth **próprio**
  (projeto Google Cloud `emmily-os-rclone`, ADR-0013, emenda), e o risco do `client_id`
  compartilhado acabou. Se o Google revogar o token, é `rclone config reconnect gdrive:` (H1); o
  Drive Desktop continua como transporte reserva.
- **A sessão OAuth do CLI do Claude expira**, e sem ela os revisores não rodam. `/login` é seu.
- **Sem proteção de branch no servidor** (plano gratuito do GitHub com repositório privado). O fluxo
  é client-side (ADR-0011).
