# 13 — Health e continuity

> **Regra que não se negocia:** "não consegui verificar" **nunca** conta como "passou". Toda
> verificação sai PASS, WARN, FAIL ou UNKNOWN, e só PASS sobe nível.

## 1. As três perguntas

O motor existe para responder, com fatos medidos agora, três perguntas de gente:

| Pergunta | Responde SIM quando |
|---|---|
| **Posso apagar esta sessão?** | o estado canônico está presente e em dia (dimensão `state` em PASS) **e** não há trabalho não commitado sem snapshot atual |
| **Posso apagar a pasta local?** | nível **L3 ou mais** **e** nada existe só nesta pasta |
| **Posso trocar de computador?** | nível **L5 ou mais** **e** nada existe só nesta pasta |

"Nada existe só nesta pasta" significa: nenhuma pasta `cloud-mirror` sem cópia verificada, nenhum
`.env` com valores num projeto `local-env`, nenhum item em `backup.exclude` presente, nenhum arquivo
ignorado pelo Git que o contrato não declare, inclusive dentro das worktrees que moram na pasta.

Pasta `cloud-mirror` "com cópia verificada" quer dizer: o **último `eos mirror` aprovado** tem cada
arquivo que está na pasta hoje, com o mesmo tamanho e a mesma data de modificação. O check não
relê o Drive nem o conteúdo: compara a pasta com o manifesto desse espelho. Arquivo novo ou
alterado depois do espelho, arquivo que o espelho recusa (nome de segredo, atalho) ou Drive
ilegível mantêm o NÃO. Ver [08](08-BACKUP-E-RECOVERY.md), seção 4.

```powershell
py -3.13 -m eos check <id>
```

Quando a resposta é NÃO, o motivo vem na mesma linha.

## 2. Os níveis L0–L6

Cumulativos: um nível exige todos os anteriores.

| Nível | Nome | Exige | Dimensões | Como subir até ele |
|---|---|---|---|---|
| **L0** | Local Only | o projeto existe nesta máquina | — | — |
| **L1** | Git Versioned | repositório com pelo menos um commit (Git existir sem commit não é proteção) | `git` | primeiro commit (a seu pedido) |
| **L2** | Remote Protected | remoto **privado**, alcançável, com **toda** branch e tag local publicada; só o remoto `origin`, apontando para a URL do contrato | `remote` | remoto privado + push de tudo |
| **L3** | Data Protected | último backup na nuvem cobre as refs atuais, o WIP atual (mesma impressão digital) e os bancos declarados; sem pendências | `backup` | `eos backup <id>` |
| **L4** | Environment Reproducible | manifesto de ambiente e bootstrap declarados e presentes; manifesto de segredos presente; nenhum arquivo de segredo rastreado nem no histórico; caminho local por variável (`${AI_WORKSPACE}`, `${USERPROFILE}`) ou declarado no `machine.yaml` | `environment`, `secrets`, `paths` | completar o contrato; sanitizar se houver segredo no histórico |
| **L5** | Session Independent | arquivos canônicos (`ai.canonical`) presentes; `STATE.md` não mais velho que o último commit por mais de 1 dia | `state` | manter o `STATE.md` em dia |
| **L6** | Disaster Recovery Tested | certificação por restauração isolada **aprovada nos últimos 30 dias**, com o projeto ainda em L5 | `recovery` | `eos certify <id>` |

**Meta dos projetos importantes: L6.** O contrato declara a meta em `portability.target_level`.

Consequências práticas:

- **L6 vence.** Depois de 30 dias sem recertificar, `recovery` vira WARN e o projeto cai para L5.
- **Um commit novo derruba L3** até o próximo backup (`refs mudaram desde o ultimo bundle`), e com
  ele os níveis acima. Isso é esperado: rode `eos backup`.
- **WARN não sobe nível.** Um `STATE.md` desatualizado (WARN em `state`) segura o projeto em L4.

## 3. As dimensões e seus motivos

| Dimensão | PASS | FAIL / UNKNOWN típicos |
|---|---|---|
| `git` | `n ref(s), HEAD <sha>` | `caminho local nao existe nesta maquina`; `nao e repositorio Git`; `repositorio sem nenhum commit (unborn)` |
| `remote` | `privado, todas as branches e tags publicadas` (refs `refs/preservado/*` ficam fora da conta: são locais de propósito e protegidas pelo bundle da nuvem) | `nenhum remoto declarado`; `remoto PUBLICO`; `n ref(s) local(is) nao publicada(s)`; `origin aponta para X, o contrato declara Y`; UNKNOWN: `verificacao sem rede`, `visibilidade do remoto nao confirmada pela API`, `ls-remote falhou` |
| `backup` | `bundle, WIP e bancos atuais na nuvem` | `nenhum backup na nuvem`; `refs mudaram...`; `WIP de X nao esta no ultimo snapshot`; `banco X mudou depois do snapshot`; `n entrada(s) de stash`; `ultimo backup marcado incompleto`; UNKNOWN: `nuvem indisponivel` |
| `environment` | `manifesto e bootstrap declarados` | `environment nao declarado`; `requirements.txt nao existe` |
| `secrets` | `manifesto de nomes presente, nada rastreado` | `arquivo de segredo RASTREADO`; `nome de segredo no HISTORICO`; `nome de segredo no WIP nao ignorado` |
| `paths` | `caminho local resolvido por variavel (${AI_WORKSPACE})` | `caminho fixo de maquina no contrato` |
| `state` | `estado canonico presente` | `ausente(s): docs/STATE.md`; WARN: `STATE.md mais velho que o ultimo commit por mais de 1 dia` |
| `recovery` | `certificado em <carimbo>` | `nunca certificado por restauracao`; `ultima certificacao reprovou`; WARN: `certificacao com mais de 30 dias` |
| `ownership` | informativa, fora da escada: `(informativa, fora da escada) PASS: ...` — não altera o nível nem as respostas | o mesmo texto com WARN/FAIL e os itens em falta; UNKNOWN se o check não rodou. Ver [10](10-PROPRIEDADE-E-PROVENIENCIA.md) |

## 4. Segurança × operação

Duas coisas diferentes, medidas separadamente:

| Segurança (`safety`) | Quando |
|---|---|
| `SAFE` | L3 ou mais: existe cópia completa e atual fora da máquina |
| `AT_RISK` | L1 ou L2: tem histórico, mas falta alguma proteção |
| `UNSAFE` | L0, ou o projeto nem existe nesta máquina |

| Operação (`operation`) | Quando |
|---|---|
| `OK` | consegue operar agora |
| `DEGRADED` | uma fonte externa obrigatória está indisponível (ex.: SharePoint) **ou** o ambiente não está declarado |

Exemplo: GitHub PASS, backup PASS, restore certificado, SharePoint fora do ar → **SAFE + DEGRADED**.
Não há alarme de perda: o projeto está protegido; só não consegue operar a parte que depende da
fonte.

## 5. Lendo o `eos status`

```powershell
py -3.13 -m eos status
```

```
projeto                        niv  safety   operacao  respostas
prog-cerebro-documental        L6   SAFE     OK        sessao=SIM clone=NAO pc=NAO
conversor-utm                  L6   SAFE     OK        sessao=SIM clone=SIM pc=SIM
engenharia-rodoviaria          L1   AT_RISK  OK        sessao=SIM clone=NAO pc=NAO
prog-sharepoint                (EXTERNAL_SOURCE - classificado)
p1-hidrologia                  (COLLECTION - classificado)
```

- `niv`, `safety`, `operacao`: as seções 2 e 4.
- `sessao=` / `clone=` / `pc=`: as três respostas da seção 1.
- Itens que não são `PROJECT` aparecem como *classificados*: não têm nível.
- Código de saída `1` se algum projeto não estiver pronto para trocar de computador.

Leitura do exemplo: o Cérebro está L6 e SAFE, mas `clone=NAO`: algo existe só na pasta dele (por
exemplo, o `.env` de um projeto `local-env`, dados ignorados não declarados, ou uma pasta
`cloud-mirror` ainda sem `eos mirror` verificado). `eos check prog-cerebro-documental` diz
exatamente o quê. O `engenharia-rodoviaria` está L1 só porque não tem
remoto (bloqueado por licença externa): a restauração dele foi certificada, mas sem remoto não passa
de L1.

## 6. Retrato do portfólio (2026-10-11/12)

Do `docs/vnext/EXECUCAO.md` e da medição de 2026-10-12. **O motor é a fonte atual**: rode
`eos status` antes de confiar nestes números.

| Situação | Projetos |
|---|---|
| L6 e SAFE | plataforma, conversor-utm, portability-lab, Dashboard Jurídico, Cérebro Documental, Relatório Grupo 1, Relatório Semanal, Organização SharePoint, Repositório Jurídico, Empresa X Portfolio, Organizador Dynatest, Projeto Pessoal A, Relatório G2 |
| restauração certificada, nível L1 por falta de remoto | Empresa X Gestão, os 5 projetos Programa extraídos do acervo Dynatest (`prog-gerador-dossie`, `prog-prestacao-contas-automacao`, `prog-indice-produtos`, `prog-criador-pastas`, `prog-grd-certificadora`) e `engenharia-rodoviaria` (remoto bloqueado por licença). Os primeiros ficaram sem remoto porque o `gh repo create` foi negado pelo ambiente (H2); **em 2026-10-12 todos eles, menos `engenharia-rodoviaria`, receberam remoto privado** — o nível sobe quando `eos backup` e `eos status` o confirmarem. `engenharia-rodoviaria` continua sem remoto e com a proveniência em apuração (H4) |
| classificados (sem nível) | SharePoint Programa (fonte externa), acervos de faculdade e laboratório, acervo Dynatest (coleção), arquivos |

> **Atualização 2026-10-16:** na aceitação final (`docs/FINAL-ACCEPTANCE.md`) os 22 PROJECT estavam
> em L6 SAFE. Depois dela: os dados Escritório Jurídico ficam no Drive pessoal (H4 decidido; Dashboard e
> Repositório Jurídico em L6 SAFE com três SIM) e o GF fez o SWITCH (certify L6). Rode `eos status`
> para o retrato atual.

## 7. `eos check` × `/os:doctor`

| | `eos check <id>` | `/os:doctor` (`scripts/doctor.ps1`) |
|---|---|---|
| Pergunta | o projeto sobrevive sem esta máquina e esta conversa? | o projeto, como sistema, é coerente e retomável? |
| Olha | Git, remoto, nuvem, ambiente, segredos, caminhos, STATE, certificação | manifesto `project.yaml`, STATE, ADRs, Git, dependências declaradas, frescor da última verificação, hooks |
| Status | PASS / WARN / FAIL / UNKNOWN | PASS / WARN / FAIL / INCONCLUSIVO |
| Roda testes? | só na certificação (`smoke_command`) | nunca |
| Varre segredo por conteúdo? | não (olha nomes) | nunca (isso é `/os:security`) |

Os dois seguem a mesma regra: o que não pôde ser verificado bloqueia (`UNKNOWN`/`INCONCLUSIVO`),
nunca vira aprovação.

## 8. Rotina de saúde

| Frequência | Ação |
|---|---|
| ao abrir um projeto | olhar a linha dele no `eos status` (ou pedir *"esse projeto está seguro?"*) |
| ao fechar o dia | `eos backup <id>`; se a pasta `cloud-mirror` do projeto mudou, também `eos mirror <id>` |
| semanal | `eos status` completo |
| mensal (antes dos 30 dias) | `eos certify <id>` nos projetos L6 |
| antes de trocar de PC | `eos backup --todos`, `eos mirror --todos`, `eos prepare-machine-migration` |
