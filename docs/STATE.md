# STATE — Emmily AI Project OS

> Este arquivo é a memória do projeto. Quem chega — pessoa, máquina ou Claude novo — lê isto primeiro.
> Atualizar **antes** de cada checkpoint, nunca depois.

- **Última atualização:** 2026-10-16, noite (aceitação final reemitida **COMPLETE** depois das revisões r17/r18 da guarda de git e da correção do registro; `docs/FINAL-ACCEPTANCE.md`). Antes: 2026-10-16, tarde (decisões da titular e execução: rclone com client OAuth próprio, H4 Escritório Jurídico, SWITCH do GF, Fase 9 pelo H2, guarda de git — seção "2026-10-16 — decisões da titular e execução"). Antes: 2026-10-16 (fechamento do programa vNext: r13 aprovada pelos dois revisores e integrada no `main`; aceitação final em `docs/FINAL-ACCEPTANCE.md` — NOT COMPLETE só por gates da titular). Antes: 2026-10-15 (rodadas r10 a r13 de correção dos achados das revisões r9 a r12 — ver as seções "Rodada r10" a "Rodada r13" abaixo). Antes: 2026-10-12 (programa vNext, fase final F10: 7 repos novos com remoto privado e L6, ownership & provenance (`eos ownership-check|certify|init`) em 19 projetos, `eos new` (nascimento protegido), assinatura SSH, scanner 156/157 e coletor corrigidos, docs/user + referência técnica; Fase 9 com matriz de retenção, aguardando H3 — andamento em `docs/vnext/EXECUCAO.md`). Antes: 2026-10-11 (Fases 7 e 8)
- **Fase atual:** **programa vNext — COMPLETE em 2026-10-16** (ADR-0012): Fases −1 a 10 concluídas, inclusive a 9 (limpeza com prova, pelo H2 da titular); aceitação final em `docs/FINAL-ACCEPTANCE.md` (COMPLETE; SAFE TO BEGIN NORMAL PROJECT WORK: YES). A primeira avaliação, mais cedo no mesmo dia, deu NOT COMPLETE por gates da titular, resolvidos depois
- **Fases (roadmap original):** 0 e 1 concluídas (`v0.1.0`) · 2 (Qualidade) concluída nas subfases 2.0–2.7 · o roadmap seguinte foi substituído pelo programa vNext (ADR-0012), cujas fases estão em `docs/vnext/EXECUCAO.md`
- **Versão:** v0.1.0
- **Testes:** 504/504 passando (coleta completa r16 na `vnext` sobre `5d32fcc`, 2026-10-16, a que cobre o código atual; a r14 sobre `0b43992` deu o mesmo: casos `.ps1`, com `vnext.ps1` rodando o `unittest` de `eos/tests/` — `Ran 371 tests ... OK (skipped=1)`; depois dela só mudaram o guarda de git — uma linha do `guarda_git.py` e o `hooks.json`, cobertos pelo `unittest` do guarda, 28 OK sobre `0f1b983`, e por teste ao vivo — o teste do guarda, o `plugin.json` e documentação; revisão r14: Security APROVADO, QA REPROVADO só por registro e endurecimentos BAIXA do guarda de git, corrigidos na r15; r15–r18 registradas na seção de 2026-10-16 (r18: código APROVADO por QA e Security). Coleta anterior: 503/503 na `main` sobre `0130221`, r13 APROVADA por QA e Security)
- **Branch:** `main`
- **Remoto:** `https://github.com/Emmilymaciell/ai-project-os` — **privado**

---

## Concluído

| Bloco | Entrega | Verificação |
|---|---|---|
| Fase 0 | Auditoria read-only do ambiente | `docs/audits/2026-09-05-fase0-auditoria.md` |
| A | Identidade Git global (`Emmily Maciel` / `(e-mail removido)`), `init.defaultBranch=main`, `credential.helper=manager`, `core.longpaths`, `.gitignore_global` | QA: os 3 repos existentes seguem com o mesmo `git status` de antes |
| B | Árvore `C:\AI-WORKSPACE` (`work/`, `university/`, `personal/`, `ai-lab/`, `portfolio/`) e `OneDrive\AI-ARCHIVE\` | Somente pastas novas vazias; nada movido |
| C | `git init` no repo do OS + `.gitignore` | Branch `main`, identidade correta |
| D | `CLAUDE.md`, `README.md`, `CHANGELOG.md`, `STATE.md`, `ARCHITECTURE.md`, `SETUP.md`, ADR-0001..0005 | — |
| E | `templates/project-standard/` + `project.yaml` + `bootstrap.ps1` | Teste de instanciação (copia, substitui placeholders, roda o bootstrap): passa |
| F | Empacotamento como plugin (`.claude-plugin/plugin.json` + `marketplace.json`), registrado e instalado | **4 camadas de validação passaram** — ver ADR-0004 |
| G | 5 skills em `skills/<nome>/SKILL.md`, invocáveis como `/os:<nome>`. `commands/` removida | `plugin details os` lista `Skills (5)`, ~267 tok always-on |
| I | Teste de aceitação ponta a ponta em projeto descartável (`ai-lab/conversor-utm`) | **Os 11 passos passaram.** Veredito da retomada em contexto isolado: *"Sim — um desenvolvedor novo continua este projeto sozinho, só com o repositório"* |
| J | 8 defeitos de template e de skill corrigidos, cada um com teste que impede a volta | 35/35 |
| H | GitHub CLI 2.100.0, autenticação da Emmily, varredura de segredos sobre **todo o histórico**, repositório privado criado, `main` e `v0.1.0` no remoto | Histórico limpo em 4 verificações. `visibility: PRIVATE` conferido pela API. Upstream `main...origin/main` |
| — | Suíte de testes da plataforma | Suítes por área em `tests/suites/`. A contagem de casos vive **só no cabeçalho** deste arquivo, e há dois testes: um confere que ela bate com o disco, outro **proíbe** que ela reapareça em prosa. Foi preciso: a divergência voltou quatro vezes, e na quarta as duas cópias erradas entraram no mesmo commit que devia protegê-las |
| — | Security scan dos arquivos criados | 0 ALTA, **0 bloqueante** no fluxo privado. O achado do relatório da Fase 0 está `ACEITO-POR-EXCECAO` (ADR-0010), aparece no relatório com a severidade original, e **volta a bloquear** sob `-ParaPublicacao`. Identificado em **Parcial** pela localização e categoria, não pela contagem |

## Parcial

- **Skills:** 7 — as 5 da Fase 1 (`new-project`, `resume`, `checkpoint`, `status`, `handoff`), `security` da subfase 2.3 e `doctor` da subfase 2.5. Faltam **4** dos 11 comandos de `docs/VISION.md` §10, e **elas não são todas de fases futuras**: `eval` é da subfase **2.9**, ainda na Fase 2; `release`, `portfolio` e `export-project` ficam para as Fases 3 e 5. *(Esta linha já se contradisse **duas** vezes. Na primeira dizia "Fases 3 e 5" para as cinco, contra a tabela de roadmap mais abaixo no mesmo arquivo. Na segunda continuou anunciando `doctor` como trabalho futuro com a skill já no disco, `project.yaml` declarando 7 e o cabeçalho declarando a 2.5 concluída — e eu afirmei ter corrigido os quatro pontos do achado quando tratei três. Achado do `qa-reviewer` nas duas rodadas da 2.5. A **contagem** passou a ter detector em `tests/suites/docs.ps1`; a lista de **nomes** não tem, e é o que ainda envelhece aqui.)*
- **Achado do relatório da Fase 0 — DECIDIDO em 2026-09-08, caminho (c).** A Emmily escolheu **aceitar por exceção**, registrado em **ADR-0010**: o repositório é privado (`PRIVATE` confirmado pela API, ADR-0003) e o uso é permitido no ambiente dela. Reescrever o histórico com `filter-repo`/`push --force` foi **recusado** para este achado — destrutivo e desproporcional. O fato que descartou o caminho barato, verificado pelo `security-reviewer` por leitura própria dos refs: `.git/refs/heads/main` e `.git/refs/remotes/origin/main` são o mesmo sha, então **aquele blob já está no remoto** e sanitizar o working tree não desfaria nada.

  **A exceção não silencia.** O achado continua no relatório, com a severidade `MEDIA` original, em seção própria, citando justificativa e data. O que muda é a **disposição**: `ACEITO-POR-EXCECAO`. E ela **não vale para publicação** — sob `-ParaPublicacao` toda exceção é ignorada e o achado volta a bloquear. Verificado nos dois modos: privado `exit 0`, publicação `exit 1`.

  O que **continua sem detector** naquele arquivo: estrutura de pastas corporativas e caminhos de repositórios de trabalho. Isso é teto permanente da ferramenta, e o guarda-corpo é organizacional — `portfolio.exposicao: nenhuma` mais revisão humana antes de qualquer publicação.
- **Bloqueante conhecido — como distinguir de bloqueante novo.** Com a exceção aprovada, `security-scan.ps1` sai com **`0`** no fluxo privado. O sinal não é a **contagem** — número em prosa envelhece, e o `qa-reviewer` pegou este arquivo dizendo "3 MEDIA" quando a varredura dizia 2. O sinal é a **identidade**: o único achado aceito é o **e-mail em `docs/audits/2026-09-05-fase0-auditoria.md`, categoria `e-mail que nao assina commits deste repositorio`**. Qualquer bloqueante com outra localização ou outra categoria é **novo**, não está coberto, e interrompe (política 4.6). *(O e-mail corporativo da própria mantenedora no mesmo arquivo seria `BAIXA` por ADR-0009 — identidade do próprio autor —, e o scanner o superclassifica como `MEDIA` porque deriva identidade do `git log`, que só conhece quem assinou commit. Contestação do `security-reviewer`, aceita; a exceção cobre os dois porque são o mesmo caminho e a mesma categoria.)*
- **Agents:** `qa-reviewer` e `security-reviewer` **existem** (subfase 2.2), estritamente read-only. `architect`, `researcher` e `portfolio-curator` seguem na Fase 3.

## Fase 1 — encerramento formal

Todos os blocos A–J concluídos e verificados. Tag `v0.1.0` no local e no remoto.

O que a Fase 1 entregou, e a evidência de cada coisa:

| Entrega | Evidência |
|---|---|
| 5 comandos `/os:*` funcionando em qualquer pasta | Plugin instalado, `Skills (5)`, validado em 4 camadas |
| Template com contrato de portabilidade | Clone limpo roda seguindo só o README |
| Estado que sobrevive à perda do chat | Retomada em contexto isolado aprovou: *"um desenvolvedor novo continua sozinho, só com o repositório"* |
| Histórico versionado com backup fora da máquina | Repositório privado no GitHub, `main` + tag |
| Qualidade verificável | 35 testes; 8 defeitos achados pelo ciclo real e corrigidos na causa raiz |
| Decisões registradas, inclusive as de não-fazer | 6 ADRs |

## Pendências e limitações conhecidas

1. **A sessão OAuth do CLI expira, e isso trava a revisão independente.** Renovada em 2026-09-08, expirou em 09-09, renovada de novo em 09-10. Quando expira, `claude -p` devolve `Failed to authenticate: OAuth session expired and could not be refreshed` e sai com `1`.

   **Consequência operacional, e ela é grande:** os revisores **só são acionáveis por esse caminho** — `claude -p --agent <nome> --plugin-dir <repo>` —, porque a ferramenta `Agent` do app desktop não os endereça (ver *Como acionar os revisores*). Com a sessão expirada não há `qa-reviewer` nem `security-reviewer`, e o ADR-0007 exige os dois a partir de criticidade média. Não é contornável por quem trabalha: `/login` é interativo e é ação da mantenedora.

   **Antes de qualquer subfase que exija revisão, confirme com `claude -p 'ok'`** — custa uma chamada e evita descobrir a expiração depois de a evidência estar coletada. É também pré-requisito da verificação de hook `PreToolUse` na 2.6, porque só o `SessionStart` dispara antes da autenticação.
2. **Branch protection e rulesets indisponíveis:** repositório privado em plano gratuito devolve `403 Upgrade to GitHub Pro`. Verificado por três chamadas de API. Consequência para a Fase 2 no item branch/PR — **decisão registrada em 2026-10-02 no ADR-0011**: o fluxo é client-side, a limitação é conhecida e aceita, e isso **não é equivalente a enforcement server-side**. A mantenedora descartou contratar o GitHub Pro só por isto.
3. **`claude plugin eval` está em early access** e não habilitado nesta conta (`plugin eval is currently in early access`). A infraestrutura de evals da Fase 2 não pode ser construída sobre ele.

## Riscos abertos

| ID | Risco | Situação |
|---|---|---|
| R1 | Sem backup fora da máquina (3 repos, 1 disco) | **Fechado em 2026-10-16:** 22/22 PROJECT com remoto privado, backup no Drive e restauração certificada (L6; `docs/FINAL-ACCEPTANCE.md`). Texto original: **Aberto.** O bloco H fecha para a plataforma, e **só para o conteúdo versionado** — dados ignorados, saídas e artefatos locais continuam com cópia única em disco (ADR-0003). |
| R1b | Dados operacionais sem backup (146 MB de `output/` + 42 MB de `examples/baseline/` no Programa Relatório) | **Aberto.** Fora do escopo do Git por decisão correta. Backup é problema separado: `OneDrive\AI-ARCHIVE\` ou o próprio SharePoint. |
| R3 | `Desktop\engenharia-rodoviaria_1.4` sem Git nenhum | **Fechado em 2026-10-15:** Git, remoto privado sanitizado, L6 (H4 opção C). Texto original: **Aberto.** Ação isolada, fora da Fase 1. |
| R4 | Histórico dos repos existentes nunca auditado contra segredos | **Fechado:** todo push passa pelo pre-push com varredura de histórico; projetos sanitizados antes do primeiro push (Fase 6). Texto original: **Aberto.** Precede qualquer push desses repos (Fase 2). |
| R5 | 3 contas OneDrive corporativas duplicadas | **Aberto.** Só importa quando um script apontar para lá. |
| R6 | Python 3.12 (PATH) × 3.13 (`py`) | **Aberto.** Template define o interpretador por projeto. |
| R8 | Disco a 80%; 426 MB em ZIPs redundantes | **Aberto.** Limpeza só com aprovação explícita. |
| R2, R7 | Identidade Git e branch padrão | **Fechados no bloco A.** |

## Fase 2 — Qualidade (em andamento)

Plano aprovado. Alvo: `v0.2.0` (verificação) e `v0.3.0` (automação). Execução **sequencial**; worktrees ficam para a Fase 3, onde o isolamento tem benefício real.

| Subfase | O que entrega | Situação |
|---|---|---|
| **2.0** | Modularizar os testes: runner raiz + 6 suítes por área + harness | **Concluída.** 36/36; execução seletiva por `-Suite` |
| **2.1** | Política de verificação + ADR-0007 (Builder ≠ Evaluator) | **Concluída.** 46/46; três detectores provados em cópia isolada |
| **2.2** | `qa-reviewer` e `security-reviewer` read-only + coletores determinísticos | **Concluída.** 82/82. Os dois revisores reprovaram a primeira tentativa: 8 defeitos do QA e 1 ponto cego estrutural do security — ver CHANGELOG |
| **2.3** | `/os:security` + scanner completo: histórico do Git, `.gitignore` regra por regra, dado de terceiro, exposição externa | **Concluída.** As quatro áreas `INCONCLUSIVO` fechadas. 6 defeitos achados pela própria varredura, 5 testes que passavam por vacuidade, e **9 achados dos dois revisores independentes** — inclusive um bug de correção e um furo no `.gitignore` do template que nenhum teste pegava. Ver CHANGELOG |
| **2.4** | Infraestrutura de tests por projeto | **Concluída** — aprovada pelos dois revisores em 2026-09-14. O template deixou de entregar `tests/` com `.gitkeep` dentro; ponto de entrada único, critério de aceite lido do manifesto, `bootstrap` rodando a suíte. Três defeitos achados pelos próprios testes novos (um fazia `1.0` valer `10`) e **treze rodadas de revisão independente**, mais de cem achados no total — um `ALTA`, e o mais grave era a minha própria correção do coletor |
| 2.5 | `/os:doctor` | **Concluída** em 2026-09-22 — **dezenove** rodadas de revisão independente. Nenhuma afirmação de aprovação aqui: os vereditos estão em `artifacts/review/veredito-25-r*-{qa,sec}.md` — **evidência de sessão: `artifacts/` é ignorado pelo Git e não viaja num clone** — e resumidos na seção da subfase, que é o registro que viaja |
| 2.6 | Hooks de Git versionados: `commit-msg`, `pre-commit` (segredo) e `pre-push` (composto pelo manifesto) | **Concluída** em 2026-10-02 — **oito** rodadas de revisão independente, 60 casos próprios. Ativados por `core.hooksPath`, instalados pelo `bootstrap`, diagnosticados pela sétima dimensão do doctor. Contornáveis por `--no-verify`, **por desenho**: a camada independente é a CI da 2.8 |
| 2.7 | Branch / diff / PR — client-side, ver limitação acima | **Concluída** em 2026-10-08 — `qa-reviewer` e `security-reviewer` **APROVADOS** na última rodada. O número de rodadas e o veredito de cada uma vivem **só** na tabela da seção da subfase — este arquivo já se contradisse sobre isso, e foi achado de revisão duas vezes |
| 2.8 | CI no GitHub Actions | — |
| 2.9 | Evals: formato compatível agora, runner nativo quando abrir | — |

A partir da 2.3, cada subfase passa pelos revisores construídos na 2.2 — Builder ≠ Evaluator aplicado à própria plataforma.

## Subfase 2.3 — encerrada. As quatro áreas `INCONCLUSIVO` fecharam

Os critérios obrigatórios que a Emmily fixou em 2026-09-08, e o que cada um virou:

| # | Área, antes `INCONCLUSIVO` | Como fechou | Situação |
|---|---|---|---|
| 1 | **Histórico do Git** | `rev-list --all --objects` + `cat-file`, conteúdo e nome de arquivo. Cobre todo commit alcançável por qualquer ref | **Coberta** |
| 2 | **`.gitignore` regra por regra** | `check-ignore -v --no-index` com sonda derivada de cada regra — inclusive `**`, `?` e classe de caractere (por um membro, declarado como tal) — mais **14** nomes de segredo canônicos verificados de fora para dentro, **em cada diretório com `.gitignore` próprio** | **Coberta.** Zero regras não verificáveis. O par `!/examples/` + `!/examples/**`, que o Git exige junto, é verificado **pelo resultado, em conjunto**: o relatório declara que qual das duas decidiu não foi atribuído |
| 3 | **Dado pessoal / de terceiro** | CPF e CNPJ com dígito verificador, telefone e CEP pontuados, e-mail classificado contra os autores reais do histórico | **Coberta** |
| 4 | **Exposição externa** | Visibilidade do remoto pela API do GitHub, 8 padrões de webhook/endpoint, varredura de configuração de CI | **Coberta** |

**A regra de não forçar `PASS` foi respeitada, e há três lugares onde ela pesou:** regra de `.gitignore` que a sonda não representa honestamente — classe **negada**, `**` colado no nome — aparece numa seção própria do relatório, sem entrar como aprovada nem reprovada; `-SemHistorico`, `-SemRede` e a costura de teste `$env:OS_SCAN_GH` aparecem na linha de modificadores e derrubam a área correspondente para lacuna declarada, em vez de reduzir cobertura em silêncio; e sonda de classe de caractere é contada em separado, porque prova a regra **para aquele membro**, não para a classe inteira.

**O que o scanner NÃO prova sobre o `.gitignore` do template**, e vale registrar porque foi ali que a revisão humana achou um furo real: a ordenação entre o bloco de binários de escritório e a negação de `examples/`. Isso é provado por `tests/suites/template.ps1`, que pergunta ao `git check-ignore` em mais de 20 caminhos concretos — teste escrito por quem construiu, que é justamente a assimetria que o ADR-0007 existe para não confiar. O `security-reviewer` conferiu a ordenação por leitura e concordou; a garantia é essa, e não mais que essa.

Lacunas que **continuam** declaradas em todo relatório, porque são limites da ferramenta e não desaparecem: segredo sem formato reconhecível, vulnerabilidade de dependência (camada complementar: `pip-audit`/`npm audit`/Dependabot), dado pessoal sem formato como nome de pessoa (camada complementar: revisão humana antes de publicar) e conteúdo de arquivo binário.

### Lista de bloqueio que o `security-reviewer` deixou — toda fechada

- (a) ~~varrer arquivos não rastreados~~ — **2.2**;
- (b) ~~varrer o histórico~~ — **2.3**, `scan-historico.ps1`;
- (c) ~~padrões de dado pessoal de terceiro~~ — **2.3**, `scan-dado-pessoal.ps1`;
- (d) ~~`git check-ignore` regra por regra~~ — **2.3**, `scan-gitignore.ps1`;
- (e) ~~allowlist para as fixtures de teste~~ — **2.2**, por reclassificação e não por silenciamento;
- (f) ~~`project.yaml` da plataforma~~ — **feito.**

### Como acionar os revisores — descoberta da 2.3, essencial para o resto da Fase 2

**Os agentes do plugin não são endereçáveis pela ferramenta `Agent` na sessão do app desktop.** Ela oferece só `claude, claude-code-guide, Explore, general-purpose, Plan, statusline-setup`, e `Agent(subagent_type: 'qa-reviewer')` falha com *"Agent type not found"* — embora `claude plugin details os` liste `Agents (2)`.

Isso afeta diretamente a regra "a partir da 2.3, cada subfase passa pelos revisores". O caminho que **funciona**, e que foi usado nas quatro rodadas de revisão da 2.3:

```powershell
& "$env:USERPROFILE\.local\bin\claude.exe" -p "<prompt>" --agent security-reviewer --plugin-dir C:\AI-WORKSPACE\_platform\emmily-ai-project-os
```

Por que esse caminho e não um agente genérico com o prompt colado: `--agent` faz o **runtime aplicar o campo `tools`** da definição real, então o revisor continua estritamente read-only. Colar o prompt num `general-purpose` daria um revisor com `Bash` — e o ADR-0008 é explícito de que instrução não é limite, `tools` é. Rodar os dois em paralelo, em background, e **não tocar na árvore** enquanto eles leem: coleta que envelhece no meio da revisão foi defeito real na 2.3.

### A revisão pendente do mecanismo de exceção RODOU — e achou defeito real

A lacuna `INCONCLUSIVO` que o fechamento da 2.3 registrou existia porque o OAuth do CLI expirou antes de os revisores poderem rodar. Com o `/login` renovado em 2026-09-10, ela rodou. **Ela não fechou de graça: converteu-se em dois defeitos concretos, que foram corrigidos na causa raiz.**

Os **dois revisores convergiram independentemente** no mesmo achado, e ele era grave: a implementação **não cumpria a regra 2 do próprio ADR-0010**. A comparação de caminho era por **prefixo**, porque extraía o caminho do início de uma string de prosa. Consequências alcançáveis com uma linha de manifesto: exceção para `x.md` cobrindo `x.md-copia.md`, e `caminho: "docs"` funcionando como **allowlist de diretório** — o buraco recusado nominalmente. E o relatório *afirmava* "correspondência exata", garantia que o código não tinha.

O teste que devia provar a regra usava dois nomes **sem prefixo comum**: passava com `StartsWith`, com `-like` ou com igualdade. Verde sobre ramo não exercitado — a mesma classe de ponto cego que já tinha mordido no `-Out`.

**Corrigido na causa raiz, não no sintoma:** o achado passou a carregar `Caminho` como campo estruturado, e a comparação é igualdade. O ramo perigoso deixou de existir. Mais três correções, cada uma com teste que exercita o ramo de verdade — ver a **emenda de 2026-09-10 no ADR-0010**:

| Correção | Teste que a guarda |
|---|---|
| Igualdade de caminho, campo estruturado | nome irmão que começa igual continua bloqueando; caminho declarado como diretório não cobre nada |
| Exceção **nunca** cobre `ALTA` | achado `ALTA` com exceção casando caminho e categoria continua bloqueando |
| `status` correto + campo faltando aparece no relatório, com o motivo | o relatório nomeia o campo ausente |
| Blob do histórico sem conteúdo passou a ser **contado e declarado** | — (fecha o `INCONCLUSIVO` de `historico`: o `continue` silencioso deixava um candidato fora do balanço num relatório cuja premissa é declarar a própria cobertura) |
| Teto permanente passou a listar **estrutura de diretório e nome de cliente** | — (`-ParaPublicacao` com `exit 0` **não** significa publicável) |

**Decisão de escopo que eu tomei estreitando, e que é sua para alargar:** exceção não cobre `ALTA`. Estreitar retira permissão, então não precisou de decisão nova; conceder precisaria. Se algum dia você quiser aceitar um `ALTA` por exceção, isso vira ADR e o mecanismo recusa até lá.

Você confirmou essa política em 2026-09-10: exceção não cobre `ALTA` é **comportamento seguro padrão**, e permitir um dia exige decisão explícita sua e alteração formal do ADR.

#### A segunda rodada achou um terceiro defeito — no parser do manifesto

Evidência nova sobre o código corrigido, revisores em contexto isolado, veredito anterior descartado porque o mecanismo mudou materialmente. O `security-reviewer` aprovou as seis áreas. O `qa-reviewer` **reprovou**, com um `ALTA` que nenhum teste verde teria pegado: o parser YAML das exceções só reconhecia o início de uma entrada quando `caminho` era a **primeira** chave.

O modo de falha era **fail-open**, e composto: numa lista de duas entradas com a segunda começando por `categoria`, a segunda entrada não era criada, e o `caminho:` dela **sobrescrevia o caminho da entrada 1** — que mantinha o `status: "aceito-por-excecao"` já lido. Resultado: a varredura passava a aceitar um par (caminho, categoria) que **ninguém decidiu**, com a lista de recusadas vazia e portanto **nenhum sinal no relatório**. Reordenar chaves é a coisa mais natural do mundo em YAML.

**Corrigido na causa raiz:** a entrada passou a ser reconhecida pelo marcador `-` de item de lista, em qualquer ordem de chaves, e o portão de aceitação (`Test-ExcecaoAceita` = `status` exato **e** completude) é aplicado uma única vez a todas as entradas coletadas. Guardado por dois testes: segunda entrada com chaves fora de ordem não contamina a primeira; entrada única com chave antes de `caminho` é reconhecida.

Detalhe de processo que vale registrar: o portão de aceitação existia em **duas** cópias com indentação diferente, e a substituição em massa pegou só uma — a que ficou para trás era a da descarga final, o caso mais comum (lista de uma entrada). Está no runbook.

#### Fatos BAIXA que o `security-reviewer` declarou abertos — registrados, não corrigidos

Aprovação nas seis áreas **com** três itens latentes nomeados. Nenhum é defeito do que foi implementado; todos são superfície que existe e que você pode querer estreitar depois:

1. **O marcador de fixture é rota mais larga que o mecanismo de exceção.** Ele rebaixa `ALTA`→`BAIXA` sem exigir caminho, categoria, justificativa nem decisão registrada, e **não** é ignorado por `-ParaPublicacao`. O mecanismo de exceção, mais rigoroso, recusa `ALTA`; o marcador, mais frouxo, não. Estreitar é decisão sua.
2. **`Test-ExcecaoCompleta` exige 5 dos 9 campos** que o ADR-0010 declara obrigatórios. Os outros 4 são documentais e nada os cobra — um manifesto incompleto neles é aceito.
3. **Uma exceção cobre ocorrências ilimitadas** dentro do mesmo par (caminho, categoria). Não há limite de contagem nem carimbo do conteúdo aceito: o arquivo pode ganhar mais achados da mesma categoria depois da decisão, e eles entram na mesma exceção.

E uma nota de comportamento, não de defeito: a igualdade de caminho e de categoria usa os operadores do PowerShell, que são **case-insensitive**. Em Windows isso é coerente com o sistema de arquivos; num clone em Linux, `Docs/a.md` casaria com uma exceção para `docs/a.md`.

#### Fechamento da lacuna — verificações finais de 2026-09-10

| Verificação | Resultado |
|---|---|
| Suíte completa | passava inteira, `exit 0` (contagem daquele momento removida: número em prosa envelhece) |
| `claude plugin validate` na raiz (marketplace), em `./skills` e em `./agents` | as três passam |
| `security-scan.ps1` fluxo privado | `exit 0` — ALTA 0, MEDIA 2, BAIXA 21, 78 arquivos |
| `security-scan.ps1 -ParaPublicacao` | `exit 1` — as duas MEDIA voltam a bloquear |
| Revisores independentes sobre o código corrigido | `security-reviewer` **APROVADO** nas seis áreas; `qa-reviewer` **APROVADO** depois da correção do parser |

As **duas** MEDIA são o mesmo par (caminho, categoria) — dois e-mails de domínios diferentes no mesmo arquivo de auditoria — cobertos pela **mesma** entrada de exceção. É a demonstração concreta do fato BAIXA nº 3 acima, visível no relatório.

**A lacuna `INCONCLUSIVO` do fechamento da 2.3 está fechada.** Não fechou por omissão: fechou depois de a revisão achar três defeitos `ALTA`, todos corrigidos na causa raiz e cada um com teste que exercita o ramo perigoso.

### Convenção de dado sintético — decidida em 2026-09-08

CSV **não** é liberado genericamente em `examples/`. O `.gitignore` do template ignora `*.csv` em todo lugar, inclusive no resto de `examples/`, e libera apenas dois diretórios declarados:

```
examples/fixtures/     dado de fixture de teste
examples/synthetic/    dado sintético gerado
```

O **caminho** é o guarda-corpo, não o comentário — que era a mesma forma do defeito que o `security-reviewer` achou com `.xlsx`, e CSV é o formato mais provável de um extrato operacional real. Colocar um CSV ali passou a ser ato deliberado, e o nome do diretório declara o que aquele dado é. Os dois diretórios existem no template com `.gitkeep`, para a convenção ser visível em todo projeto instanciado.

Binário de escritório (`.xlsx`, `.pdf`, `.pptx`) continua barrado **mesmo dentro** deles. Provado por `git check-ignore` em mais de 20 caminhos concretos em `tests/suites/template.ps1`.

### Como os coletores são acionados hoje

**Manualmente.** Não existe hook: `hooks/hooks.json` não existe, e o `project.yaml` declara `hooks: 0`. Quem roda `scripts/collect-diff.ps1` e `scripts/security-scan.ps1` é quem executa o `/os:checkpoint`, seguindo a tabela de rigor da skill. O hook que **bloqueia push com segredo** é a subfase 2.6 — verificado que hooks de plugin disparam, mas nenhum foi escrito.

> **Atualização 2026-10-16:** `hooks/hooks.json` passou a existir com **um** hook de plugin — o guarda `PreToolUse` de git destrutivo para agentes (`hooks/guarda_git.py`, incidente r13) — e `project.yaml` declara `hooks: 1`. Ele não aciona os coletores: o acionamento dos coletores continua manual como descrito acima. Ver `docs/runbooks/hooks.md`.

### Convenção do marcador de fixture

Arquivo que **declara** `SEGREDO-FABRICADO-PARA-TESTE` nas **40 primeiras linhas** — o cabeçalho — tem os achados de credencial e de dado pessoal **reclassificados** para severidade BAIXA, categoria `fixture declarada`. **Reclassificar, não silenciar:** o achado continua no relatório. Há teste provando que o mesmo conteúdo com e sem marcador produz achado nos dois casos.

**Só no cabeçalho, e o motivo é de segurança.** Até a 2.3 a checagem era sobre o arquivo inteiro, e a primeira execução da varredura completa mostrou o furo: `CHANGELOG.md` e este `STATE.md` **citam** o marcador para documentar a convenção, e tiveram os achados reclassificados por isso. Qualquer arquivo poderia desarmar a varredura sobre si mesmo escrevendo o marcador numa frase. Declaração é afirmação do arquivo sobre si mesmo, e isso mora no cabeçalho. Fixture com o marcador no fim deixa de ser reclassificada e passa a acusar — falha para o lado seguro.

O relatório avisa que o marcador é afirmação de quem escreveu o arquivo, não verificação.

### Escada de severidade e disposição — ADR-0009 e ADR-0010

**Severidade** diz *o que o achado é*: `ALTA` (algo indevido está exposto), `MEDIA` (algo questionável exige decisão de uma pessoa), `BAIXA` (fato para contestar — guarda-corpo ausente, fixture declarada, identidade do próprio autor). A escada mede **exposição**, não importância.

**Disposição** diz *se ele trava*. `ALTA` e `MEDIA` travam, **exceto** quando cobertos por exceção aprovada (ADR-0010) — e nesse caso o achado mantém a severidade, aparece em seção própria e cita a exceção. `BAIXA` nunca trava.

Código de saída: `0` sem bloqueante, `1` com bloqueante, `2` a varredura não aconteceu — e `2` **não** é uma variação de `1`.

**A lacuna "não existe `MEDIA` aceita" está fechada** pelo ADR-0010. O mecanismo é estreito de propósito: correspondência exata de caminho **e** categoria, nove campos obrigatórios, `status: "aceito-por-excecao"` como único valor que vale, e `-ParaPublicacao` ignorando tudo. Allowlist por domínio, extensão ou diretório foi **recusada** explicitamente — resolveria o ruído criando um buraco. A suite `scanner` guarda isso com um bloco de casos dedicado ao mecanismo (todos com prefixo `excecao:`), incluindo os que provam que achado parecido em outro arquivo, nome irmao com prefixo comum, caminho declarado como diretorio e categoria diferente no mesmo arquivo **continuam bloqueando** — e que achado `ALTA` nunca e coberto. O numero de casos vive no disco, nao nesta frase.

O projeto descartável `ai-lab/conversor-utm` está preservado como evidência do ciclo e como fixture de teste para o `/os:doctor`. Apagar só quando a Fase 2 tiver as próprias fixtures.

## Subfase 2.4 — infraestrutura de testes por projeto. **Concluída**

**O que era o problema.** O template declarava ter verificação e entregava `templates/project-standard/tests/` com um `.gitkeep` dentro — estrutura vazia, exatamente o que a política 4.4 proíbe, no arquivo que governa todo projeto novo. E a skill `new-project` documentava um placeholder `{{TEST_CMD}}` que **não existia em lugar nenhum do template**: o passo 6 mandava "rodar o comando que você escreveu no `{{TEST_CMD}}`", sobre um valor que nunca era substituído porque não estava lá. Nenhum teste pegava nem um nem outro, porque o teste de placeholder comparava só a direção template → skill.

**O que o template entrega agora:**

| Arquivo | Papel |
|---|---|
| `tests/run-tests.ps1` | ponto de entrada **único**, o mesmo comando em todo projeto, qualquer que seja a linguagem. Detecta a trilha |
| `tests/README.md` | como rodar, o que se ganha de graça, e **o que estes testes não cobrem** (política 4.7) |
| `tests/conftest.py` + `tests/test_smoke.py` | trilha Python: `scripts/` importável sem boilerplate, fixtures, suíte de fumaça |
| `tests/_harness.ps1` + `tests/suites/smoke.ps1` | trilha PowerShell: `Test-Caso`, `Assert-True`, `Get-Texto`, leitura do manifesto |

O `/os:new-project` **apaga a trilha que não se aplica** — mesmo padrão já usado com o `requirements.txt`. Se as duas sobreviverem, o runner **recusa rodar**: escolher uma em silêncio esconderia metade dos testes.

**Códigos de saída, ADR-0009 aplicado ao projeto:** `0` passou, `1` falhou, **`2` a suíte não rodou** — sem suíte, sem `.venv`, trilha ambígua, ou suítes que carregaram e não executaram caso nenhum. `2` não é uma variação de `1`. Um runner que não acha suíte e sai com `0` está afirmando aprovação sobre nada, que é a violação da política 4.5.

**Critério de aceite mora no manifesto.** `verificacao.comando`, `verificacao.criterio_de_pronto` e `verificacao.limites` são campos novos do `project.yaml`; os harnesses das duas trilhas leem de lá e **falham quando o limite não está declarado**, sem valor padrão. Isso vem de um defeito medido: no `conversor-utm` o critério "dentro de 1 metro" existia em três lugares — prosa do `README.md`, docstring do teste e um `1.0` cravado na asserção — e em nenhum era fonte de verdade. Terceira aparição da mesma classe de defeito nesta plataforma.

**O `bootstrap.ps1` passou a rodar a suíte**, não só conferir que a pasta existe. E compara declaração com realidade: manifesto dizendo `tests: true` com suíte que não roda **bloqueia**. É a semente do `/os:doctor` da 2.5, com o caso mais comum já coberto.

#### O que o `conversor-utm` deu, sem ser tocado

Usado só como caso real de comparação — **não foi migrado nem alterado**, e continua como fixture e evidência do ciclo (ADR-0001: migração é decisão dela, um projeto por vez). Dos 29 testes dele (8 pontos × 2 parametrizações + 13 casos), o inventário separou:

| Virou infraestrutura do template | Ficou lá, específico |
|---|---|
| `sys.path.insert` para `scripts/` → `conftest.py` | matemática UTM: round-trip, bordas de `zona_de`, falso norte, desvio do meridiano central, faixa útil |
| limite de aceite lido do manifesto → fixture `limite()` / `Get-LimiteDoManifesto` | a lista `PONTOS` e as tolerâncias concretas |
| convenção de docstring: estratégia + o que o teste **não** prova | o contrato de colunas `Este/Norte/Zona/Hemisferio` |
| padrão de teste de regressão contando a história do bug | as asserções de `converter_csv` |
| armadilha do CSV com BOM → fixture `csv_com_bom` | |
| entrada única e códigos `0/1/2` | |

#### Três defeitos reais, achados pelos testes novos

1. **`[double]::TryParse('1.0')` devolve `10` nesta máquina.** A cultura do sistema é pt-BR: o ponto é lido como separador de **milhar**, `TryParse` devolve `$true`, e uma tolerância de 1 metro declarada no manifesto passava a valer 10 metros — com o teste **verde**, porque ele só comparava contra o número errado. Foi pego pelo único caso que exigia o valor **exato**, não por um caso de "cabe no limite". Corrigido com `InvariantCulture`; guardado pelo caso `manifesto: 1.0 le como UM, nao como DEZ`. Está no runbook.
3. **O coletor de evidência morreu por causa de um aviso do Git.** Aconteceu na hora de coletar a evidência desta própria subfase: `.gitattributes` fixa `eol=lf` para `.md`, um `STATE.md` gravado com CRLF fez o `git diff` avisar *"CRLF will be replaced by LF"*, e no PowerShell 5.1 stderr de executável nativo é erro terminante sob `Stop` — o `collect-diff.ps1` saiu com `2` e **sem relatório**. Coletor que morre não produz evidência, e sem evidência a revisão é `INCONCLUSIVO`. Havia guarda para repositório sem commits, para ref inexistente e para destino fora do repositório; o quarto aviso, que ninguém previu, derrubou igual. **Corrigido por classe, não por caso:** todo `git` dos coletores passa por `Invoke-Git`, que devolve stdout, deixa o código em `$LASTEXITCODE` e não permite que aviso nenhum aborte quem chama — 34 chamadas convertidas, nenhuma solta restou. Guardado por um caso que **planta** a condição do aviso e confere que ela existe antes de exigir o relatório.

2. **Suíte-fixture em here-string inflava a contagem de testes da plataforma.** As suítes que os testes escrevem dentro de projetos temporários tinham `Test-Caso` na coluna 0, e o guarda-corpo que confere `Testes: N/N` contra o disco passou a contar 210 casos com 206 executados. Corrigido indentando as fixtures, com a convenção escrita no topo da suíte. O guarda-corpo funcionou: foi ele que acusou.

#### Verificado

| Verificação | Resultado |
|---|---|
| Suíte completa | passa inteira, `exit 0` — a contagem está no cabeçalho deste arquivo, e só lá |
| Projeto **recém-instanciado**, trilha PowerShell | `run-tests.ps1` `exit 0` com casos executados |
| Projeto recém-instanciado, trilha Python | `.venv` + `pytest` de verdade: smoke passa, `limite()` lê do manifesto, código sem teste próprio reprova, `import` de `scripts/` funciona |
| Trilha vazia / trilha ambígua / sem `.venv` / nenhum caso | `exit 2` nos quatro, cada um com o motivo escrito |
| `bootstrap.ps1` | roda a suíte; bloqueia quando o manifesto declara `tests: true` e a suíte não roda; **não** bloqueia quando não declara |
| Placeholder | verificado nas **duas** direções |

#### A revisão independente reprovou — e o achado central era meu

Os **dois revisores reprovaram**, e convergiram no mesmo defeito. Ele não estava no que a 2.4 se propôs a fazer: estava na correção que eu tinha feito no meio do caminho, quando o coletor de evidência morreu por causa do aviso de CRLF.

**A primeira versão do `Invoke-Git` baixava o `ErrorActionPreference` e engolia o código de saída.** O `qa-reviewer` classificou como `ALTA`; o `security-reviewer` contou: das ~34 chamadas, **só 6 consultavam `$LASTEXITCODE`**. Nas outras 28, falha de git virava **lista vazia** — e lista vazia é indistinguível de "nada a acusar". Antes da 2.4, a mesma falha abortava e o `trap` dava `exit 2`, alto e visível. **Eu troquei um modo de falha ruidoso por um silencioso, dentro de um detector de segurança.** Cinco caminhos foram traçados linha por linha:

| Onde | O que acontecia com o git falhando |
|---|---|
| `security-scan.ps1` | `ls-files` vazio → **0 arquivos examinados**, seis áreas declaradas cobertas, lacunas `(nenhuma)`, `exit 0` |
| `scan-historico.ps1` | `cat-file --batch-check` vazio → todo sha classificado como não-blob **antes** de qualquer contador; `0 de 0 blobs lidos` **reconcilia** e passa pelo próprio guarda-corpo |
| `scan-comum.ps1` | `Test-TemCommits` — HEAD ilegível indistinguível de repositório recém-`init`, com afirmação **positiva** de cobertura |
| `scan-exposicao.ps1` | `remote -v` vazio → área coberta; um remoto **público** cujo `remote -v` falhou sai sem achado `ALTA` |
| `scan-gitignore.ps1` | `RegrasVerificadas` incrementava **antes** de olhar o resultado: contava tentativa como verificação |

O `security-reviewer` nomeou a assimetria que condenava a versão: `scan-exposicao.ps1` é escrupuloso quando o **`gh`** falha — tem quatro motivos distintos de "sem resposta" — e era cego quando o **git** falhava. A lição da 2.3 tinha sido aplicada a um dos dois executáveis.

**Corrigido por classe, não por caso:** `Invoke-Git` agora **lança quando o git falha**, e sob `Stop` + `trap` isso volta a produzir `exit 2` — "a varredura não aconteceu", o terceiro estado do ADR-0009. Aviso com código `0` continua ignorado, que era o defeito original. As **oito** chamadas em que código `!= 0` é **resposta** e não erro — `check-ignore` (×4), `rev-parse --verify --quiet` (×3), `config --get-all` — passaram a usar `-PermitirFalha` explícito, e só elas leem `$LASTEXITCODE`. *(Esta frase dizia "sete" e afirmava que todas liam o código; o `qa-reviewer` contou oito e achou duas que não liam. Na de `check-ignore` em lote isso doía: código `128` ficava indistinguível do `1` normal, o lote se perdia e toda regra virava um falso "sem efeito observável" — o modo de falha que o próprio comentário do arquivo chama de o pior possível. As duas passaram a exigir que `0` e `1` sejam resposta e qualquer outro código lance.)*

Mais quatro **guardas de sanidade**, para o caso em que o git sai com `0` e contradiz o disco: `ls-files` vazio com arquivo no disco; objetos no histórico com nenhum blob classificado; `remote -v` vazio com `[remote]` no `.git/config`; e `Test-TemCommits` falso conferido contra as refs em `.git/`. Cada um lança em vez de declarar cobertura.

**Segundo achado convergente, e esse viaja para todo projeto governado:** `Get-CampoDoManifesto` **falhava aberto**. Procurava a *sequência* de chaves sem exigir que a filha estivesse **dentro** da mãe, então `verificacao.limites.erro_maximo_m` era satisfeito por um `limites:` em qualquer outro bloco do arquivo — devolvendo `99`. Não é "ausente vira padrão": ausente virava **o valor de outro bloco**. E o docstring e este `STATE.md` afirmavam que o leitor falhava fechado; **afirmação falsa de fail-closed é pior que lacuna assumida**. O QA achou duas variantes a mais: escalar de bloco (`>`) devolvia o próprio indicador como valor, e filha mal indentada no nível da mãe era aceita. Corrigido com indentação estritamente maior e nível fixo, mais recusa explícita de escalar de bloco.

**Divergência entre os dois leitores gêmeos**, também do QA: para o mesmo manifesto inválido, um aceitava o que o outro recusava — `criterio_de_pronto: ""` virava `{}` em Python e lançava em PowerShell. Projeto Python e projeto PowerShell tinham rigor diferente sobre o mesmo arquivo. Os dois foram alinhados, e há caso de teste espelhado nas duas trilhas.

E mais cinco correções menores, cada uma com teste: o `bootstrap.ps1` morria antes do resumo quando a suíte do projeto tinha erro de sintaxe (mesma classe do `Stop` + stderr, no arquivo **entregue**, enquanto a proteção existia só no harness da plataforma); o runner do template mapeava só o código `5` do pytest como "não rodou", deixando `3` e `4` virarem "falhou"; o runner **da plataforma** não tinha a guarda de vacuidade que a 2.4 impôs aos projetos governados; o `New-ProjetoDeTeste` afirmava "não filtra por extensão" e filtrava por uma allowlist de 13 extensões — afirmação falsa, agora decidida por conteúdo (byte `0x00`), como o Git decide; e o relatório de segurança se declarava "subfase 2.3" literal, agora identificado pelas linhas do próprio varredor e dos detectores carregados.

**E esta última afirmação era FALSA quando foi escrita.** Os dois revisores conferiram contra o artefato coletado e acharam a mesma coisa: o relatório dizia `(1 linhas) + 0 detectores`, contradizendo o carimbo do próprio arquivo, que declarava 697. Três defeitos numa linha só — `Join-Path` sem separador montando `scripts\libscan-comum.ps1`, e `Measure-Linhas` recebendo **caminho** onde espera **conteúdo**, duas vezes, devolvendo `1` porque caminho não tem `\n`. Era um mecanismo de proveniência que nunca funcionou, num relatório cuja premissa é declarar a própria cobertura, e **nenhum dos 225 casos tocava aquela linha**. Corrigido, com uma função nova de nome distinto (`Measure-LinhasDoArquivo`) para que a confusão caminho-vs-conteúdo fique impossível de escrever, e com o caso que os dois pediram nominalmente: ele **lê a linha `Gerador` do relatório gerado** e exige a contagem real e os seis detectores nomeados.

**Achado meu, no caminho, e vale registrar porque quase passou:** um `"$codigo:"` numa mensagem de erro é lido pelo PowerShell como variável qualificada por drive e dá `ParseError` — mesma família do `"\$Ordem:"` que já estava no runbook. O modo de falha foi instrutivo: o erro de sintaxe fez **toda** execução sair com `2`, e os dois casos novos que exigem `exit 2` **passaram por motivo errado**. Só o resto da suíte ficando vermelho denunciou.

E um defeito do meu próprio teste: os casos da trilha Python compartilham um `.venv` (custa 20 s e rede), um deles alterava o manifesto e não restaurava, e o caso seguinte tentava substituir um texto que já havia mudado — a substituição virava no-op e o caso **passava sem exercitar o ramo**. Exatamente a classe que esta subfase existe para não repetir. Agora quem mexe restaura, e a fixture confere que a condição existe **antes** de exigir o resultado.

#### A segunda rodada também reprovou, e três das minhas correções não estavam em vigor

Evidência nova, contexto isolado, veredito anterior descartado. Os dois reprovaram de novo, e convergiram em três pontos — o que vale registrar é que **duas das correções da rodada anterior eram afirmação e não fato**:

1. **A linha de proveniência do relatório nunca funcionou** (acima). O `STATE.md` afirmava como feito o que o artefato desmentia.
2. **O leitor PowerShell continuava falhando aberto, por outra porta.** A checagem de aninhamento que eu tinha adicionado vinha **depois** do `continue` que descartava linhas cuja chave a regex não reconhecia. Uma chave com **hífen** — `dados-extra:` — era invisível para a lógica de aninhamento, não encerrava o bloco da mãe, e `verificacao.limites.erro_maximo_m` voltava a devolver o valor de outro bloco. O caso que eu tinha escrito usava `outro_bloco`, que **passa** pela regex: exercitava o ramo do aninhamento e não alcançava este. Corrigido lendo a árvore inteira e procurando depois — a estrutura decide, não a ordem de aparição — e a chave aceita hífen, ponto e aspas.
3. **Os dois leitores gêmeos ainda divergiam, e a divergência recusava manifesto VÁLIDO.** O Python levantava exceção em **lista em qualquer posição** do arquivo, derrubando a suíte inteira; o PowerShell só se a lista viesse antes do campo procurado. E lista não é exótica: o `project.yaml` **da própria plataforma** tem `ambiente.dependencias_externas` como lista, e o ADR-0010 **manda** preencher `dados_sensiveis_excecoes` com entradas de lista. Um projeto que seguisse o schema documentado teria a trilha Python inteira quebrada. Regra nova nos dois: lista e escalar de bloco viram valor **registrado como não legível** — pedir aquela chave falha, pedir outra funciona. E há casos que comparam os dois gêmeos **sobre a mesma entrada** — quatro valores que já divergiram — mais um que lê o manifesto **da plataforma** pela trilha PowerShell e outro que exercita os ramos de lista e de escalar de bloco pela trilha Python. *(A primeira versão desta frase afirmava um caso "pelos dois gêmeos" que não existia: o corpo instanciava só a trilha PowerShell, e o `qa-reviewer` chamou de terceira rodada da mesma classe — afirmação que o código não entrega.)*

**O achado mais grave desta rodada, do `qa-reviewer`:** o `bootstrap.ps1` tinha três `git` soltos sob `Stop`, e o `Invoke-Git` vive em `scripts/lib/`, que **não é entregue**. Com o índice corrompido ou um `index.lock` de um cliente travado, `ls-files` falhava, a lista de vazamentos ficava vazia, e o bootstrap imprimia **`[OK] nenhum .env ou chave versionada`** — afirmação de segurança sobre um git que não respondeu, dentro do **único check de segurança que um projeto governado roda sozinho**. É textualmente o mesmo `ALTA` da rodada anterior, do outro lado da fronteira. Corrigido com um helper próprio dentro do `bootstrap.ps1` (o template não pode depender da plataforma), e a resposta do git passou a ser conferida antes de virar afirmação: falha vira `BLOQUEIA: NAO FOI POSSIVEL VERIFICAR`.

Mais três: a sonda do `pytest` ficou fora da guarda de preferência, um ramo antes do que já estava corrigido — stderr do interpretador viraria `exit 1` ("falhou") para um problema de **ambiente**, que o contrato manda reportar como `2`. O caso que compara as listas de extensão das duas trilhas lia o **arquivo inteiro** em vez da lista, e podia passar com as listas divergentes. E o contrato do `-Check` dizia "não cria nada" desde que a 2.4 passou a **rodar a suíte do projeto** nesse modo — a suíte é do projeto e pode escrever; o texto foi corrigido em vez de a capacidade ser removida, porque rodar o teste é o único jeito de saber que o comando documentado funciona.

**Tensão registrada, não resolvida:** quando falta `py` ou rede, os casos da trilha Python **reprovam** e o runner da plataforma sai com `1`. Numa subfase cuja tese é "`2` não é variação de `1`", "não foi possível verificar" continua saindo como "rodou e falhou". A mensagem diz explicitamente que não foi possível verificar, e a política 4.5 é clara de que `INCONCLUSIVO` bloqueia como `REPROVADO` — mas o runner da plataforma ainda não tem o terceiro estado por caso. Fica para quando houver um segundo motivo para mexer nele.

#### Terceira rodada: `security-reviewer` **APROVADO** no fluxo privado, `qa-reviewer` reprovou de novo

O `security-reviewer` aprovou as seis áreas com as três lacunas fechadas por inspeção própria — e disse **como** fechou e **o que as reabre**, que é o que torna a inspeção auditável. Publicação continua **não aprovada**: `-ParaPublicacao` sai com `1`, e mesmo que saísse com `0` não significaria publicável — estrutura de diretório e nome de cliente corporativo são teto permanente da ferramenta.

**Ele deu o critério que eu pedi, e ele é melhor que a minha intuição.** Dois eixos, e o primeiro decide:

> **Direção da falha.** Quando a guarda erra, o resultado é `exit 2` sem relatório afirmativo, ou `exit 0` com afirmação de cobertura? Só o segundo é bloqueante. "Varredura que não aconteceu não pode sair com `0`" é regra sobre a **direção**, não sobre a existência da lacuna.

Aplicado aos quatro que eu deixei abertos de propósito: três erram **alto** e são backlog; um errava na direção proibida e ele escalou para `MEDIA` — e **disparou nesta execução**. `security-scan.ps1` descartava arquivo rastreado ausente do disco **sem contador**, e a aritmética do próprio relatório não fechava: 78 + 7 = 85 únicos, `0` não lidos por tipo, **84** examinados. A causa era o `tests/.gitkeep` que esta subfase apagou. Corrigido com contador e linha de lacuna própria — a mesma classe do `BlobsSemConteudo` da 2.3, reaparecida no scanner principal.

E ele corrigiu o meu diagnóstico do item que eu achava ser "troca de guarda por guarda": **o problema não é a guarda, é que `Test-TemCommits` responde a duas perguntas diferentes** — *"há histórico a varrer?"* e *"o `HEAD` resolve?"* — e é usada para as duas. Depois de `git init` + `remote add` + `fetch` as respostas divergem, e por isso as duas correções óbvias estão erradas: `$false` faria o detector afirmar "não existe histórico a varrer" sobre um repositório com blobs buscados; `$true` faria o `rev-parse --short HEAD` lançar. A saída é **separar o predicado em dois**, e enquanto não separar, manter o `throw` — que erra alto.

**O `qa-reviewer` reprovou pela terceira vez, e o achado central era a terceira aparição da mesma classe:** dois casos meus se chamavam *"as duas trilhas"* e *"pelos dois gêmeos"*, e os corpos instanciavam **só a PowerShell** — `-Trilha 'powershell'` apaga `conftest.py` e todo `test_*.py`. E este `STATE.md` afirmava o caso como fato. Além disso, os ramos de `ValorNaoLegivel` do lado Python **nunca eram executados** em 231 casos verdes, porque o manifesto do template traz `[]` inline, sem nenhum item de lista.

Corrigido: os nomes passaram a dizer a trilha que testam, e entraram quatro casos que faltavam — os ramos de lista e de escalar de bloco pela trilha Python; um que compara os **dois gêmeos sobre a mesma entrada**, com quatro valores que já divergiram; a sequência YAML compacta nas duas trilhas; e a sensibilidade a caixa. Mais três divergências residuais de leitor que esses casos expuseram: escalar de bloco com **indicador de indentação** (`|2`) escapava das seis formas reconhecidas nos dois gêmeos; `.Trim('"')` do PowerShell removia **todas** as aspas das pontas sem exigir par, corrompendo `"roda no modo 'privado'"`; e o `hashtable` do PowerShell é case-insensitive enquanto o `dict` do Python não é.

**Dois defeitos nos meus próprios casos novos, os dois pegos pela suíte:** `-ne` entre strings no PowerShell é **case-insensitive**, então o guarda-corpo de uma fixture cujo assunto *era a caixa* acusou a fixture de não ter mudado nada; e o canal de evidência do caso de comparação era um delimitador `VALOR_LIDO<...>` que **colidia com o próprio valor** — a entrada `">"` produzia `VALOR_LIDO<>>` e o padrão não-guloso capturava vazio, acusando divergência que não existia. Os dois lados passaram a gravar em arquivo. As duas armadilhas estão no runbook.

#### Quarta rodada: `security-reviewer` APROVADO de novo, e o QA achou a quarta reincidência

O `security-reviewer` aprovou o fluxo privado outra vez, e achou um defeito **na minha própria correção do F1** — exatamente o que eu pedi que ele procurasse. O acumulador que decide imprimir `(nenhuma)` na tabela de lacunas **não incluía** as duas linhas novas: a de arquivo rastreado ausente do disco (que a correção anterior acrescentou) e a de blob sem conteúdo (da 2.3). Numa execução cuja única lacuna fosse uma dessas, a **mesma tabela** imprimiria a lacuna *e* `(nenhuma) — nenhuma área cai para INCONCLUSIVO`. Declaração de cobertura que se autocontradiz, na seção que o protocolo manda ler primeiro e tratar como autoritativa.

E o caso de teste que eu tinha escrito **media a linha e não o contador**, então passava por cima da contradição. O molde certo já existia no caso irmão de `-SemHistorico`.

**O padrão que ele nomeou vale mais que o conserto, e está agora escrito no código:**

> Toda linha nova na tabela de lacunas precisa entrar no contador que decide `(nenhuma)`. A correção acrescentou a linha e esqueceu o contador; o teste novo mediu a linha e não o contador. É a terceira vez nesta plataforma que o conserto cobre o sintoma declarado e deixa o portão a jusante.

Mais um `BAIXA` dele, barato e de bom retorno: a linha da lacuna dizia "1 arquivo(s)" e **não dizia qual** — ele só fechou cruzando com o relatório de diff. Um revisor que receba só o relatório de segurança cairia em `INCONCLUSIVO` por falta de um dado que o scanner tem em mãos. Agora a linha nomeia os caminhos.

**O `qa-reviewer` reprovou pela quarta vez, e o achado mais incômodo é a quarta reincidência da contagem em prosa** — com as **duas cópias erradas adicionadas por mim neste mesmo diff**. A tabela "Verificado" da 2.4 e a linha do roadmap declaravam uma execução que não era a que aconteceu, e o guarda-corpo existente conferia **só o cabeçalho**, então não tinha como pegar cópia em prosa.

O remédio é o que esta plataforma já adotou uma vez: **remover o número, não corrigi-lo** — corrigir envelhece de novo. E entrou o guarda-corpo que faltava: um caso que exige que a contagem **corrente** apareça **exatamente uma vez** no `STATE.md`, e na linha de cabeçalho. Número histórico de subfase fechada continua permitido, porque registro de um momento não envelhece.

Os outros três dele, todos reais:

- **Valor que é só comentário virava critério.** `criterio_de_pronto:  # preencher depois` é `null` em YAML, e os **dois** gêmeos devolviam a string `# preencher depois` como o critério de aceite — direção proibida, afirmando critério onde não há, no campo que esta subfase existe para tornar fonte de verdade. A remoção de comentário exigia espaço **antes** do `#`, e depois do `trim` o `#` fica na posição 0. Como os dois erravam igual, o caso de comparação não podia alcançar por construção.
- **Sexta divergência entre os gêmeos:** TAB antes do `#`. O `\s+#` do PowerShell casava tab e o `" #"` do Python não. E `: valor` (chave vazia) era recusado por um e aceito pelo outro.
- **Um caso chamado "nas duas trilhas" instanciava uma** — a quarta aparição da classe, no caso que **nasceu** da correção dela. Agora roda as duas de verdade.

#### Quinta rodada, e a lacuna que eu declaro no fechamento

O `qa-reviewer` reprovou a quinta vez e o `security-reviewer` devolveu **`INCONCLUSIVO`** — `histórico` não fechou. Os dois convergiram outra vez, e o achado central foi o melhor das cinco rodadas.

**A correção que eu havia feito alcançou um de três laços.** `scan-dado-pessoal.ps1` e `scan-exposicao.ps1` continuavam descartando arquivo rastreado ausente do disco **sem contador**, e as duas áreas declaravam `sim` com "0 não lidos" — sobre 85 arquivos no conjunto e 84 examinados. Mesma classe, mesmo arquivo, um ramo ao lado; o próprio repositório já tinha registrado essa classe uma vez.

**E a linha de lacuna que eu escrevi era falsa para uma das áreas.** Ela afirmava: *"o blob ainda é alcançável pelo `histórico`, e é lá que ele aparece"*. Para credencial, verdade. Para **exposição**, falso — `scan-historico.ps1` carrega só `Get-PadroesConteudo`, nunca `Get-PadroesExposicao`. Um arquivo rastreado com webhook, apagado do disco sem `git add`, não era lido por área nenhuma, não era procurado no histórico com padrão de webhook, e o relatório saía `exit 0` dizendo `exposicao externa | sim`. Escrevi uma afirmação de cobertura que era falsa, no documento cuja premissa é declarar a própria cobertura.

**A coluna "Coberta" contradizia a seção de lacunas em 3 de 6 áreas** — quarta aparição do mesmo padrão, e o `security-reviewer` contou: eu havia posto o fato novo no acumulador que decide `(nenhuma)` e esquecido **o outro portão que consome o mesmo fato**. A tabela abre dizendo *"Área com lacuna não pode receber APROVADO"* e se desmentia trinta linhas depois. A regra passou a estar escrita nas duas pontas: fato que emite linha entra no acumulador **e** na coluna.

**O único achado que mudou veredito foi barato e justo.** A linha do blob vazio entregava um critério ao revisor mas não dizia **qual** blob. Ele monta o limite aritmético — marcadores de 0 byte colapsam num objeto só — mas **não consegue excluir o maligno**: uma falha de *leitura* num blob com conteúdo satisfaz o mesmo limite, porque o contador sobe no mesmo `if (-not $txt)` para os dois casos. E ele não pode abrir objeto do Git: são comprimidos, e ele não tem `Bash` por desenho do ADR-0008. A linha passou a imprimir **sha abreviado + caminho**, e o fechamento passou a ser por identidade.

**E a correção da rodada anterior não tinha caso de teste** — os dois revisores acharam a mesma metade faltando. Apagar o termo do acumulador deixava a suíte verde com o defeito de volta. O agravante é o que ele revela: o comentário que **eu mesmo** havia escrito naquela linha diz *"quem acrescentar linha aqui: acrescente no acumulador, e escreva o caso que exige a AUSÊNCIA de `(nenhuma)`"*. Escrevi a instrução e não a segui.

Mais dois: valor entre aspas contendo `" #"` era truncado nos dois gêmeos — `criterio_de_pronto: "roda o passo #3"` virava `"roda o passo` com aspa órfã, verde sobre critério de aceite truncado; e a mitigação do teto permanente prescrevia sanitizar "o que `portfolio.exposicao` e `dados_sensiveis_excecoes` apontarem" — dois ponteiros que cobrem **um** arquivo, enquanto o `grep` dele achou nome de cliente corporativo em **21** arquivos rastreados. Prescrição dimensionada para uma fração da superfície é pior que nenhuma: dá a impressão de que há roteiro suficiente. Agora prescreve o repositório inteiro, com inventário próprio.

**Uma recomendação dele mudou o meu procedimento de fechamento**, e vale registrar como regra: a varredura havia rodado com o **index vazio**, então o `APROVADO` de `staging` era verdadeiro e vazio de conteúdo — não dizia nada sobre o que iria para o commit. **A varredura de fechamento roda depois do `git add` seletivo e antes do commit.**

E um defeito meu na correção do F6, pego pelo caso que lê o manifesto **real** e não um sintético: o padrão exigia **um** espaço antes do `#`, e o manifesto da plataforma alinha comentários com vários — `revisao_independente: "qa+security"   # derivado...` tem três. Com um só, o comentário não era cortado e as aspas deixavam de formar par.

#### Vereditos finais da 2.4 — 2026-09-14

Treze rodadas com os dois revisores em contexto isolado, mais a revisão final focada que a regra de encerramento prevê. Os dois vereditos que fecham a subfase, sobre o código que está sendo commitado:

| Revisor | Veredito | Escopo |
|---|---|---|
| `qa-reviewer` | **APROVADO** | Delta da rodada 13. Correção, regressão, cobertura, escopo, portabilidade e registro, todas aprovadas. *"Nada nesta delta é bloqueante."* |
| `security-reviewer` | **APROVADO** para o fluxo privado autorizado · **REPROVADO** para publicação, que é o portão funcionando | Seis áreas. As quatro lacunas da execução fechadas por inspeção própria, cada uma com a condição que a reabre |

**Os dois `MEDIA` de dado de terceiro são não-bloqueantes pelo critério de 2026-09-14**, e o `security-reviewer` justificou cada gatilho: o achado aparece no relatório com a severidade original; a exceção é igualdade de caminho **e** categoria; `ALTA` nunca é coberta; campo vazio ou só com espaços não cobre nada; e `-ParaPublicacao` devolveu `exit 1` anulando tudo. Ele conferiu nos refs que o blob já está no remoto — o que torna a justificativa do ADR-0010 verdadeira, e não conveniente.

**O que estes `APROVADO` significam, nas palavras dele:** *"nenhum padrão detectável, e eu li os arquivos apontados"* — não "limpo em sentido absoluto". O teto permanente continua valendo e está declarado no relatório.

#### Lacuna declarada no fechamento da 2.4

**Esta lacuna está fechada.** Ela existiu em todas as rodadas anteriores, com a mesma redação: as correções da rodada mais recente nunca tinham passado pelos revisores, o que é `INCONCLUSIVO` pela política 4.5. Na rodada 13 os dois revisaram o código que está sendo commitado e aprovaram — o `qa-reviewer` sobre a delta do último achado bloqueante, o `security-reviewer` sobre as seis áreas. Fica registrada aqui, e não apagada, porque a sequência importa: **a subfase passou doze rodadas com esta lacuna aberta**, e foi ela que impediu declarar "Concluída" antes da hora.

O que é fato verificado: os achados da décima segunda rodada foram corrigidos na causa raiz, e **as correções foram provadas por mutação executada, não por leitura** — quatro mutações aplicadas contra o repositório real, com restauração conferida por SHA-256, e as quatro mataram a suíte: reverter o portão de exceção para `-not`, trocar o despiste de comentário por identidade, alargar o casamento de campo para substring case-insensitive, e substituir o leitor de `ArquivosDeCI` por um literal. A suíte completa passa com saída `0` (a contagem vive no cabeçalho, e só lá); `plugin validate` passa nas três camadas; o fluxo privado sai com `0` e a publicação com `1`.

O que **não** é fato, e precisa estar escrito com esta precisão porque duas versões anteriores desta mesma frase foram reprovadas por afirmar demais: **nem toda correção de todas as rodadas tem par de execução.** A tabela de backlog abaixo nomeia, no item 8, os ramos que continuam sem caso — todos falham lançando, nenhum produz verde falso, e é por isso que não bloqueiam.

**O que continua valendo para a próxima subfase:** a base da coleta tem de ser o commit da rodada anterior, não o da subfase, ou o escopo volta `INCONCLUSIVO` — foi assim que o `qa-reviewer` marcou escopo inconclusivo na sexta rodada, e a correção custou uma coleta inteira.

#### Sexta rodada — a de fechamento. Os dois reprovaram, e a lista foi a melhor de todas

Evidência do commit `7bb6ebb` contra a base `5bb4f78` — 33 arquivos, 4811 linhas, zero lacunas de coleta. O `security-reviewer` devolveu `INCONCLUSIVO` (`.gitignore` não fechou) e disse com todas as letras: **a 2.4 não pode ser declarada Concluída ainda**. O `qa-reviewer` reprovou. Dez achados, e nenhum era ruído.

**O mais constrangedor foi o primeiro, e os dois acharam no mesmo lugar.** A linha do teto permanente que eu tinha **acabado de corrigir** na rodada anterior saía **truncada** do gerador: uma aspa dupla não escapada dentro de string de aspas duplas, a **quarta aparição** da armadilha documentada **onze linhas acima, no mesmo arquivo**. O texto parava em *"prescrevia sanitizar "* e a célula da tabela ficava sem o `|` de fechamento. O que sumia no silêncio era justamente a **medição** que justificava alargar a mitigação — os 21 arquivos com nome de cliente.

E o agravante é literal: o caso de regressão que escrevi para aquela correção afirmava duas frases que ficavam **antes** do ponto de corte. Verde sobre relatório corrompido. É o padrão que eu mesmo nomeei no código — *"acrescentou a linha e o teste mediu a linha, não o portão"* — agora dentro do teste da própria correção.

O conserto não foi só escapar a aspa. Entrou um caso que **varre as linhas de tabela do relatório** e exige que cada célula feche com `|`: uma string que perde o resto por aspa não escapada perde também a barra final, então **a forma da linha denuncia o defeito** sem precisar conhecer o texto dela.

*(A primeira versão desta frase dizia "todas as linhas" e "qualquer linha que alguém escreva no futuro", e o `qa-reviewer` mostrou que era falso: a varredura rodava sobre uma fixture mínima — um `.md` sem achado e sem lacuna — e cerca de catorze linhas condicionais do relatório nunca saíam ali. A fixture passou a ser rica de propósito (achado de credencial, dado pessoal, blob vazio, classe de caractere, negações irmãs), e o alcance real ficou **declarado como limitação** dentro do próprio caso, em vez de prometido. Afirmar cobertura maior do que se tem é exatamente a classe que esta subfase inteira perseguiu — e ela reapareceu no comentário do conserto dela.)*

**Sobrou um quinto `continue` silencioso, e o `security-reviewer` mostrou por que era o pior.** Em `scan-gitignore.ps1`, `ArquivosDeRegra` é fixado **antes** do laço — então um `.gitignore` rastreado e apagado do disco fazia `RegrasTotais` despencar e a linha imprimir *"71 de 71 regras sondadas"*: razão **perfeita** sobre metade do universo. O arquivo que protege o segredo de todo projeto governado deixaria de ser lido com o relatório declarando cobertura cheia.

**As duas lacunas de `.gitignore` imprimiam contagem sem identidade** — o mesmo defeito que o F6 corrigiu para o blob vazio, intacto uma área ao lado. Foi exatamente isso que impediu o revisor de fechar a área: ele fechou `historico` porque tinha o sha, e não fechou `gitignore` porque não sabia quais regras sondar. Agora as duas imprimem `arquivo:linha regra`.

**A sétima divergência entre os gêmeos, achada pelo QA, é a mais bem construída de todas: o BOM.** O harness PowerShell usa `ReadAllText(..., Encoding.UTF8)`, que **consome** o BOM; o `conftest.py` usava `read_text(encoding="utf-8")`, que não consome — e `U+FEFF` não é whitespace, então nem `.strip()` nem `.lstrip()` o removem. Com BOM, a linha 1 do manifesto (`# Preenchido por /os:new-project...`) deixa de ser reconhecida como comentário, contém `:` e vira **chave-lixo na raiz**. Um leitor cujo contrato é *"o que não entende, recusa"* aceitando comentário como dado.

E o golpe é a cobertura: **todas** as fixtures gravavam com `UTF8Encoding($false)`, então o caso de comparação não podia alcançar por construção — *"o teste gera o arquivo pelo próprio código e nunca vê o artefato real"*, que é o padrão do defeito de encoding da Fase 1. A regra estava no mesmo `conftest.py`, na docstring da fixture `csv_com_bom`: *"a leitura certa é `utf-8-sig`"*. Não tinha sido aplicada ao manifesto.

**E o ramo que eu tinha corrigido na rodada anterior não tinha caso em trilha nenhuma.** O QA mostrou a mutação que sobrevivia: apagar o bloco inteiro dos dois gêmeos e deixar só o corte genérico continua passando nas formas com o comentário **fora** das aspas — que eram justamente as duas que os casos existentes exercitavam — as duas formas que os casos existentes exercitavam. Só um `#` **dentro** das aspas discrimina, e não havia fixture assim. A proteção que pegou o defeito anterior foi **incidental, não desenhada**.

**As três declarações de situação.** `STATE.md:7`, o título da seção e `project.yaml` **já declaravam a 2.4 concluída**, contraditos pelo próprio `STATE.md` que dizia que a linha só mudaria se os revisores aprovassem. O repositório afirmava o resultado da revisão que o ciclo existia para produzir. Os três voltaram para "em fechamento". E o `CHANGELOG` estava **uma rodada inteira atrasado**, dizendo "quatro rodadas" e afirmando aprovação como estado final.

**Uma correção de método, que vale mais que os achados:** o `security-reviewer` cruzou o horário do reflog com o do relatório e mostrou que a minha afirmação de ter rodado a varredura entre o `git add` e o commit **não valia para aquela coleta** — eram 16 horas de diferença, com o index vazio. A regra continua certa; o que estava errado era afirmá-la como exercida. Uma coleta feita para revisão sobre árvore limpa tem `staging` vazio **por construção**, e isso precisa ser dito em vez de parecer cobertura.

#### Sétima rodada: os guarda-corpos eram imunes ao próprio defeito

O `security-reviewer` aprovou o fluxo privado. O `qa-reviewer` reprovou, e o achado central é o melhor de todas as rodadas até ali.

**Os dois guarda-corpos que eu tinha escrito — seguindo recomendação dele — eram imunes exatamente aos defeitos que os originaram.** Eles contavam referências no texto cru de todo `.ps1` do repositório, **inclusive no próprio arquivo do teste**, cujo comentário citava `Invoke-NativoLocal` e `ArquivosDeCIAusentes` pelo nome. Reverter a correção deixava os símbolos com referências suficientes vindas do comentário do próprio guarda: verde com o defeito de volta.

A correção que eu apliquei foi de uma linha — **menção em comentário não é chamador** — e **ela não fechou**: a rodada 9 mostrou que a via seguinte era a string literal, e a 10 substituiu tudo por contagem de chamadas no parser. Ver a nona rodada, abaixo. Fica registrado aqui porque o raciocínio da época era plausível e errado, e é isso que torna a sequência útil.

**E havia um terceiro campo órfão que os guardas não pegavam:** `RedeConsultada`, cujo inicializador é expressão entre parênteses e escapava da lista branca do regex. Lista branca de inicializador é a mesma classe de guarda-corpo que cobre menos do que promete. Ampliado, o guarda o achou na primeira execução — e o campo ganhou leitor: a linha de exposição agora declara quando a rede **não** foi consultada.

**Três coisas que ele cobrou e que valem além desta subfase:**

1. **`scripts/bootstrap.ps1` não tinha teste nenhum.** A única menção em `tests/` era "o arquivo existe". O arquivo-espelho do template tinha casos; este não. Agora há um que roda o bootstrap com o `PATH` reduzido — sem `git`, `gh` nem `py` — e exige que ele chegue ao resumo com a instrução de instalação, `BLOQUEIA` e `exit 1`. *(A primeira versão desta frase dizia que ele "exercita as três conversões de uma vez", e o `qa-reviewer` mostrou que era o contrário: os três sítios de chamada estão **dentro** dos ramos de presença, então com o `PATH` vazio nenhuma conversão executa. O caso exercita os três ramos de **ausência** — que era a regressão que importava. A conversão em si ficou sem execução provada até a rodada seguinte lhe dar um par.)*
2. **As três linhas de relatório novas não tinham asserção nenhuma.** *"As correções desta rodada estão provadas por leitura, não por execução."* Agora há caso que roda com `-SemRede` e exige que a linha declare que a rede não foi consultada, que distinga arquivo de CI **lido** de ausente, e que a de `.gitignore` traga a razão de regras efetivas.
3. **"Lacuna declarada só em conversa não é lacuna declarada."** Eu tinha dito a ele que os ramos-guarda sem par negativo entravam no backlog, e concordado com o critério de direção — mas não tinha **escrito** na tabela. Está escrito agora, como item 8.

#### Oitava rodada: o guarda-corpo consertado ainda não tinha prova de que funcionava

O `security-reviewer` aprovou o fluxo privado. O `qa-reviewer` reprovou de novo, e o achado central é o irmão exato do da rodada anterior — um nível acima.

**Os guarda-corpos consertados não tinham par de execução.** Eu tinha corrigido a imunidade deles a comentário e afirmado no `STATE.md` que "ganharam caso de regressão que exercita o ramo". Não tinham. A mutação que ele descreveu: trocar o despiste de comentário por identidade (`return $Texto`) deixava a suíte inteira verde, porque hoje todo símbolo de `scripts/` tem chamador real. **A correção central da sétima rodada estava provada por leitura, não por execução** — que é a frase textual com que este mesmo arquivo descreve o que estava errado na rodada seis.

A causa raiz não era falta de um caso: era o detector viver **dentro** do caso de teste, onde não pode ser exercitado sobre nada além do repositório real. Os dois viraram funções em `tests/_harness.ps1` — `Find-FuncaoSemChamador` e `Find-CampoSemLeitor` — e ganharam fixtures com órfã plantada, símbolo citado só em comentário, nome irmão, campo fantasma dentro de bloco de documentação, e os dois pares negativos que recusam árvore vazia e consumidor ilegível em vez de aprovar por vacuidade.

**E o casamento do guarda de campo tinha dois buracos que ele nomeou com instância viva:**

- **Título de caso de teste contava como leitor.** O texto consumidor inclui as suítes inteiras, e `-notmatch` no PowerShell é case-insensitive: apagar o leitor real do campo `Commits` não acusava nada, porque existe um caso chamado *"repo sem commits mostra TODO arquivo"*.
- **Nome irmão cobria o irmão menor.** `ArquivosDeCI` ⊂ `ArquivosDeCIAusentes`, `ArquivosDeRegra` ⊂ `ArquivosDeRegraAusentes`, e mais dois pares. Apagar o leitor do menor era invisível.

Exigir a forma `.Campo` com fronteira de palavra, e comparar com sensibilidade a caixa, fecha os dois — **e achou na primeira execução a quarta órfã da subfase**: `Cobertos`, o contador de achados desarmados por exceção aprovada, escrito e lido por ninguém. Ele agora aparece no relatório **e** é cruzado com o número de linhas da tabela, porque eram duas contagens da mesma coisa e nenhuma conferia a outra.

**O achado de portabilidade era meu, e sério.** O caso que eu tinha escrito rodava `scripts/bootstrap.ps1` **sem** `-Check` — e sem `-Check` o bootstrap cria nove diretórios no avô do repositório. Nesta máquina isso é inofensivo porque o avô é `C:\AI-WORKSPACE`. Num clone limpo em `D:\tmp\repo` — que é a verificação que a política 4.2 exige antes de handoff — a suíte criaria `D:\_platform`, `D:\work`, `D:\university` e outras **na raiz do drive**; sem permissão de escrita, morreria antes do resumo e o caso falharia com a mensagem errada, apontando um defeito inexistente. Um parâmetro resolve, e as asserções são idênticas.

**E duas afirmações minhas que o disco não sustentava:** que aquele caso "exercita as três conversões de uma vez" (os três sítios de chamada estão dentro dos ramos de presença, então com o `PATH` vazio nenhuma executa) e o placar de vereditos do `CHANGELOG`, cuja soma dava seis para sete rodadas. As duas estão corrigidas acima, e a conversão nativa ganhou o caso que faltava.

**O que esta rodada acrescenta à classe, e é o que vale registrar:** guarda-corpo é código, e código sem par negativo não está verificado. Corrigir um detector e afirmar que ele passou a detectar é a mesma falha que ele existe para pegar — só que um nível acima. Quatro mutações foram executadas de fato contra o repositório, com restauração conferida por SHA-256, e as quatro mataram a suíte. É isso que separa "provado" de "lido".

#### Nona rodada: parar de contar texto e passar a contar chamadas

O `security-reviewer` aprovou o fluxo privado, condicional. O `qa-reviewer` reprovou com **um** achado `MÉDIO`, e ele é a terceira versão do mesmo defeito — o que torna esta rodada a mais instrutiva das nove.

**O guarda de função continuava imune ao defeito que o originou. Agora por string literal.** A rodada 8 tinha fechado a via do comentário. Sobrou a via das aspas — e a instância estava viva no repositório, escrita por mim: a **mensagem de asserção** de um caso de teste dizia `"... Invoke-NativoLocal nao foi exercitada"`. Aspas duplas, sem `#` na linha, sobrevivia inteira a qualquer despiste de comentário. Desconectar as seis chamadas do `bootstrap.ps1` deixava definição + literal = duas referências, uma descontada como definição, e o guarda ficava **verde** sobre exatamente o defeito pelo qual foi escrito.

E o par positivo não podia alcançar isso **por construção**: a fixture plantava a menção num comentário. Ela provava o despiste de comentário e nada além dele.

**A correção não foi acrescentar a via das aspas à lista de coisas que não contam.** Foi trocar a pergunta. Contar texto sempre vai precisar de uma lista de exceções que alguém mantém — comentário, literal, here-string, título. Contar **chamada** não precisa: `Find-FuncaoSemChamador` passou a usar `[System.Management.Automation.Language.Parser]`, e um `CommandAst` é uma chamada enquanto um literal não é. A pergunta deixou de ser *"o nome aparece?"* e passou a ser *"alguém chama?"*.

De brinde, o parser enxerga função **aninhada** (que o regex de coluna zero não via) e **não** enxerga definição dentro de here-string de fixture (que o regex contava como código real) — dois pontos cegos do backlog que morreram junto. O guarda de campo recebeu o mesmo tratamento: leitura é acesso a membro no parser, o que mata de uma vez o título de teste, o nome irmão e a caixa.

**Do lado da segurança, a quinta aparição de "acrescentou a linha e esqueceu o portão a jusante" — dentro do conserto que documenta essa classe.** A guarda de divergência que eu tinha acabado de escrever vivia **dentro** do ramo alcançável só quando a tabela já tinha linha: cega justamente no caso perigoso, *"o portão desarmou N e a tabela mostra zero"*. E, chamando a si mesma de lacuna, não entrava no acumulador que decide imprimir `(nenhuma)` — uma execução cuja única anomalia fosse a divergência imprimiria a nota **e** "nenhuma área cai para INCONCLUSIVO", na seção que o protocolo manda ler primeiro.

Ele também mostrou que a divergência é hoje **inalcançável**: os dois números são a mesma medição lida duas vezes. Isso é bom para o relatório e ruim para a guarda, cujo valor é futuro. A saída foi a que o repositório já usa para o `gh`: uma **costura de teste declarada** na linha de modificadores, nunca silenciosa, para que a guarda tenha par negativo de verdade em vez de inspeção.

E a ressalva do item 4 do backlog — as sondas canônicas não entram na subárvore que uma negação `!` reabre — passou a sair também como **linha de lacuna do relatório**, com a contagem e as regras nomeadas. O item 4 continua no backlog, porque a limitação continua aberta: o que mudou é que ela deixou de existir *só* aqui. Ele aplicou contra ela a regra que esta subfase escreveu: *lacuna declarada só em conversa não é lacuna declarada* — e backlog, para quem lê o relatório, é conversa.

**O que a nona rodada acrescenta à classe:** quando um guarda falha pela segunda vez pelo mesmo motivo com roupa diferente, o conserto certo não é a terceira remenda — é trocar a pergunta por uma que não precise de lista de exceções. Cinco mutações foram executadas contra o repositório real, com restauração conferida por SHA-256; a primeira delas é exatamente a que o `qa-reviewer` provou sobreviver na rodada anterior.

#### Décima rodada: a conversão pela metade, e o registro que ficou uma rodada atrás

O `security-reviewer` **aprovou** o fluxo privado sem nenhum achado novo contra as mudanças — a primeira vez em toda a subfase. O `qa-reviewer` reprovou por **registro**, e tinha razão de um jeito incômodo.

**O `CHANGELOG` afirmava como vigente um remendo que já tinha sido superado.** O parágrafo dizia, no presente, que a regra do guarda é *"menção em comentário não é chamador"* — e no disco o guarda não despe comentário nenhum, porque contar comentário **não** fechava o buraco. O agravante é que o mesmo diff tinha editado aquela seção, só que para trocar a contagem de rodadas. Registro parcialmente atualizado é pior que registro velho: o velho se denuncia pela data, o parcial parece corrente.

O cenário de falha é concreto: quem retoma lê o `CHANGELOG`, conclui que a regra é despir comentário, e reimplementa assim no gêmeo do template — ou "conserta" um falso positivo voltando a contar texto. Volta o defeito que custou três rodadas. E nenhum teste pega: o caso de coerência compara versão, fase e checkpoint, não mecanismo.

**A conversão para o parser tinha ficado pela metade.** `Find-CampoSemLeitor` já contava leitura pelo AST, mas o lado da **declaração** continuava regex — `^\s{4,12}([A-Z][A-Za-z0-9]{2,})\s*=\s*\S` — com uma lista branca que ninguém tinha declarado: campo com indentação de 13 espaços ou mais, segundo campo depois de `;` na mesma linha, nome minúsculo, nome de até duas letras. E não era hipótese: **os quatro campos de cobertura de `scan-dado-pessoal.ps1`, declarados numa linha só com `;`, nunca tinham sido verificados por ninguém.** O guarda contra campo órfão tinha um detector inteiro fora do alcance.

Trocada a extração por `HashtableAst` — restrita à atribuição a `$cob`, para que a tabela de padrões de um detector não seja confundida com bloco de cobertura —, a contagem passou de 46 pseudocampos para 40 reais, incluindo os quatro invisíveis. Nenhum órfão. Junto foi a outra metade que ele apontou: **escrever num membro não é ler**, e agora a atribuição é descontada.

**E a costura de teste que eu tinha acabado de escrever curto-circuitava o predicado que ela existia para exercitar.** Ela estava à esquerda de um `-or`, então com a costura ligada a comparação real nunca era avaliada: trocar o predicado inteiro por `$false` sobrevivia verde nos dois casos. O conserto foi movê-la para um **operando** — ela perturba a entrada, e a comparação roda nos dois caminhos.

**O que a décima rodada acrescenta à classe:** conversão pela metade é a forma mais convincente de defeito, porque a metade convertida é verdadeira e a documentação fala dela. Quando a correção é "trocar o mecanismo", o trabalho só acaba quando **todos** os lados usam o mecanismo novo — e o registro tem de descrever o mecanismo que está no disco, não o que estava na rodada anterior.

#### Décima primeira rodada: o guarda não se olhava, e o mecanismo abandonado voltou como código

O `security-reviewer` aprovou o fluxo privado. O `qa-reviewer` reprovou com dois `MÉDIO`, e os dois são sobre o mesmo ponto cego: **o guarda-corpo não estava no universo que ele mesmo examina.**

**A função que a rodada 10 tornou desnecessária continuou no harness, órfã — com a docstring ensinando o mecanismo abandonado.** `Remove-ComentarioDePowerShell` não tinha um único chamador, e o texto dela afirmava, no presente, que *"menção em comentário não é chamador... e é a direção segura"*. É exatamente a frase pela qual o `CHANGELOG` foi reprovado na rodada anterior — corrigida na prosa e **reintroduzida no código, onde é mais convincente, porque é código**. Quem fosse estender o guarda ao gêmeo do template acharia a função pronta, com justificativa escrita, e voltaria a contar texto.

O agravante é o que importa: **o guarda que existe para pegar "símbolo adicionado e não conectado" não enxergava o arquivo onde ele próprio mora.** Ele varria `scripts/` e o título dizia "toda função definida", sem dizer onde. Passou a varrer `scripts/` **e** `tests/`, e o título agora nomeia as duas árvores. A primeira instância viva já estava dentro do ponto cego.

**E a conversão da rodada 10 tinha estreitado o guarda de campo sem declarar.** `Get-CamposDeCobertura` só enxerga bloco atribuído a `$cob`, e o resumo de disposição de `scan-excecoes.ps1` era devolvido direto como `[pscustomobject]`: seus quatro campos ficavam fora do alcance — **inclusive `Cobertos`, que foi a órfã que este mesmo guarda achou na rodada 9**. O regex anterior o alcançava; a correção o perdeu. A lista branca tinha virado o **nome da variável**, e ninguém a tinha declarado como lista.

Alargar para todo objeto devolvido foi medido e não serve: acusa 18 estruturas internas de trabalho. O caminho foi o outro — **declarar a convenção e trazer para dentro dela o detector que escapava**. Está na docstring, está no backlog, e o campo voltou ao alcance.

**O que a décima primeira rodada acrescenta à classe:** um guarda-corpo que não se inclui no próprio universo é uma promessa sobre código que ele não lê. E remendo superado não morre quando a prosa é corrigida — morre quando o **código** dele sai do repositório, porque código com justificativa escrita ensina melhor do que documentação.

#### Décima segunda rodada: asserção dentro de `if` é asserção que pode não rodar

O `security-reviewer` devolveu `INCONCLUSIVO` **só em `staging`** — e isso não é defeito, é procedimento: a varredura de fechamento tem de rodar **depois do `git add`**, como o `STATE.md` já manda. As outras cinco áreas, aprovadas. O `qa-reviewer` reprovou com três `MÉDIO`.

**O primeiro se corrigiu sozinho ao ser corrigido.** O caso que verificava duas lacunas do `.gitignore` afirmava **dentro de um `if`**: suprimir a emissão de uma delas deixava o `if` falso, a asserção nunca rodava, e a guarda anti-vacuidade passava pela lacuna **irmã**. Verde sobre lacuna que sumiu do relatório — e lacuna que some vira `APROVADO` indevido do lado de quem revisa.

Ao tirar o `if` e exigir as duas, o caso **falhou na hora**: a fixture nunca tinha produzido a segunda. A regra `!/examples/` só conta como "verificada em conjunto" quando **todos** os que compartilham a sonda são negação, e a fixture tinha `/examples/` junto. O caso prometia duas lacunas e verificava uma, havia rodadas, sem que ninguém percebesse — porque a promessa estava no título e a verificação estava condicionada.

**O segundo é a assimetria da rodada 11, invertida.** Endureci o `Get-Texto` do **template** contra byte inválido e deixei o da **plataforma** lendo com `[Text.Encoding]::UTF8`, que troca byte inválido por `U+FFFD` em silêncio. Consequência nomeada pelo revisor: `STATE.md` salvo em ANSI pelo Bloco de Notas — cenário que o runbook documenta como recorrente — devolveria o texto com `U+FFFD` em cada acento, e as asserções que casam string **sem** acento continuariam verdes sobre arquivo corrompido.

**O terceiro é diagnóstico que afirma o que não mediu.** Sem `git` no `PATH`, `$branch` ficava vazio e o resumo do bootstrap imprimia *"init.defaultBranch não é 'main'"* sobre uma configuração que ninguém leu. A identidade já tinha o ramo explícito; o branch não — e o público do bootstrap é justamente a máquina nova sem Git.

**O que a décima segunda rodada acrescenta à classe:** asserção condicionada é promessa, não verificação. E quando a condição some, o teste não falha — ele **emagrece em silêncio**, que é pior, porque continua verde com o nome antigo.

#### Décima terceira rodada: o contrato estava escrito trinta linhas acima do defeito

Primeira rodada sob a regra de encerramento, e ela mudou o que os revisores entregam: cada `MEDIA` veio **classificado** como bloqueante ou não, com justificativa contra o critério. Isso tirou de mim um julgamento que eu não deveria fazer — sou o construtor, e decidir se o meu próprio defeito bloqueia é o conflito que o ADR-0007 existe para separar.

O `security-reviewer` **aprovou** o fluxo privado e classificou os dois `MEDIA` conhecidos como **não-bloqueantes**, verificando cada critério: o achado aparece no relatório com a severidade original, a exceção é igualdade de caminho **e** categoria, `ALTA` nunca é coberta, e `-ParaPublicacao` devolveu `exit 1` anulando tudo. Ele foi além e conferiu nos refs que o blob já está no remoto — o que torna a justificativa do ADR-0010 *verdadeira*, e não apenas conveniente.

O `qa-reviewer` reprovou por **um** `MEDIA`, e é o único de toda a subfase que a regra classifica como bloqueante.

**`NegacoesQueAbremSubarvore` emitia linha de lacuna, entrava no acumulador do `(nenhuma)` — e não entrava no portão da coluna `Coberta`.** Um projeto governado cujo `.gitignore` fosse `/output/*` mais `!/output/` sairia com `| gitignore | sim |` e, trinta linhas abaixo, a lacuna dizendo que a razão de nomes canônicos **não vale** para aquela subárvore. Falsa garantia na tabela que o protocolo manda ler primeiro.

O agravante é que **o contrato está escrito no próprio arquivo, trinta linhas acima do defeito**: *"fato que emite linha na tabela de lacunas entra no acumulador do `(nenhuma)` **E** na coluna `Coberta`. São dois portões que consomem o mesmo fato; consertar um deixa o outro mentindo."* Eu escrevi essa regra e fiz uma ponta só. Sexta aparição da classe.

**E ele explicou por que passou verde treze rodadas:** não dispara neste repositório, porque aqui o `.gitignore` do template tem classe de caractere e `**`, que já forçam `parcial` por outro motivo. O caso que existia também mascarava — a fixture dele produzia `NaoVerificaveis` junto. O alvo real é o projeto governado, que é para onde o scanner viaja. A fixture nova é a dele, e a escolha dela é o ponto: a negação tem de ser a **única** lacuna, e o caso exige explicitamente a **ausência** das outras duas, senão a coluna cairia pelo motivo errado e o defeito continuaria mascarado.

**O que a décima terceira rodada acrescenta à classe:** escrever a regra não fecha a classe. Eu documentei "dois portões consomem o mesmo fato" e, seis rodadas depois, alimentei um só — no arquivo onde a regra está escrita. O que fecha é o caso que exercita **a segunda ponta isoladamente**, com fixture construída para que nenhuma outra lacuna mascare o resultado.

### Regra de encerramento da 2.4 — decidida pela mantenedora em 2026-09-14

Treze rodadas produziram mais de cem achados reais, e o que continua rendendo achado não é o produto — são os guarda-corpos e o registro, porque cada conserto cria superfície nova. *(A versão anterior desta frase trazia um placar de áreas aprovadas "há cinco rodadas seguidas". O `qa-reviewer` apontou que isso é placar por veredito — exatamente o que o `CHANGELOG` deste mesmo conjunto de mudanças decidiu abandonar, porque os relatórios das rodadas anteriores não são versionados e o número não é conferível no disco.)* Revisão sem critério de parada é revisão infinita, então o critério passou a ser explícito:

| Severidade | Bloqueia? |
|---|---|
| `ALTA` | **Sempre.** Confirmar, corrigir na causa raiz, regressão, suíte, evidência nova, revisão do escopo alterado |
| `MEDIA` | **Só se** puder causar comportamento incorreto material, `fail-open`, falsa aprovação ou garantia, perda de cobertura relevante, regressão funcional, problema de segurança, ou divergência real do contrato documentado |
| `MEDIA` não-bloqueante | Dívida estrutural, robustez adicional ou limitação conhecida que **erra para o lado seguro e não produz falso verde**: registrar nominalmente no backlog com justificativa, **sem** abrir outra rodada |
| `BAIXA` | Registrar no backlog quando pertinente. **Nunca** abre rodada |

**O critério de saída não é "zero observações".** É ausência de risco bloqueante conhecido, com as limitações residuais escritas e as verificações honestas. Buscar zero observações neste repositório é buscar o que ele mesmo declara impossível: o teto permanente existe e está declarado.

### Backlog conhecido da 2.4 — itens 1 a 7 de 2026-09-10; itens 8 a 13 de 2026-09-11; itens 14 a 17 de 2026-09-14

O `security-reviewer` pediu explicitamente que estes fossem **nomeados e datados**, como os três fatos `BAIXA` da 2.3, e não guardados como "limitação conhecida" genérica. Nenhum deles afetou esta execução, e cada um diz por quê.

| # | Fato | Direção da falha | Quando cobrar |
|---|---|---|---|
| 2 | ~~**`.git` como arquivo**~~ **— fechado em 2026-09-16.** `Get-CaminhosDoGit` é o resolvedor que este item pedia, e as duas guardas foram fechadas. Fica registrado, riscado, porque os itens 21 e 25 tratam só do resíduo (subdiretório e *bare*), que é outra coisa. Texto original: (worktree, submódulo, `--separate-git-dir`) faz duas guardas se comportarem mal em direções **opostas**: `scan-comum` lança e `scan-exposicao` fica inerte. Um resolvedor de `gitdir:` fecha as duas de uma vez | uma alto, uma inerte | **Antes da Fase 3**, que é quando o `CLAUDE.md` passa a recomendar worktrees — a plataforma vai recomendar exatamente a configuração em que essas guardas erram |
| 3 | **Commit vazio** (`--allow-empty`) faz `ObjetosTotais >= 1` com nenhum blob classificado, e a guarda do histórico lança. Raro, e o comentário do arquivo diz "não existe na prática" com uma certeza a mais do que devia | `exit 2`, alto | Junto do trabalho de `Test-TemCommits`, que saiu desta tabela em 2026-09-15 por ter sido concluído |
| 4 | **A sonda canônica não entra na subárvore que uma negação abre.** As 28 sondas perguntam por `templates/project-standard/.env`, nunca por `templates/project-standard/examples/.env`. A interação entre `!/examples/**` e o bloco de credenciais **não foi perguntada ao Git** — foi fechada por leitura da semântica | não detecta | **Antes de um projeto governado colocar dado real em `examples/`.** Hoje só tem `.gitkeep` de 0 byte |
| 5 | **`Invoke-GitLocal` do template é seguro por adesão, não por construção.** Devolve `Ok` e cada chamador precisa lembrar de checar — a mesma estrutura da versão do `Invoke-Git` que reprovou a rodada 1. Hoje as quatro chamadas estão corretas, mas o arquivo viaja para todo projeto e vai crescer | correto hoje | Quando o `bootstrap.ps1` ganhar a próxima chamada de git |
| 6 | **A suíte `project-tests` cobre quatro assuntos num arquivo só** — estrutura do template, o runner, o leitor de manifesto, o bootstrap. Passou do limite de arquivo novo do coletor e exigiu elevá-lo na coleta. Pede divisão | não é defeito | Próximo movimento natural em `tests/suites/` |
| 7 | **"Não foi possível verificar" sai como `exit 1`** no runner da plataforma quando falta `py` ou rede. Numa subfase cuja tese é "`2` não é variação de `1`", a plataforma ainda não tem o terceiro estado por caso. A mensagem diz explicitamente que não foi possível verificar, e a política 4.5 é clara de que `INCONCLUSIVO` bloqueia como `REPROVADO` | bloqueia, alto | Quando houver um segundo motivo para mexer no runner |
| 12 | **O guarda de órfã não enxerga `templates/project-standard/`.** Passou a cobrir `scripts/` **e** `tests/` na rodada 11 — foi assim que `Remove-ComentarioDePowerShell` apareceu —, mas o template tem o próprio `tests/_harness.ps1`, com `Invoke-GitLocal` e mais funções, e continua fora | não detecta | Quando o gêmeo do template ganhar mais superfície. O título do caso agora **nomeia as duas árvores** que ele varre, que era o defeito de verdade: guarda que examina metade do que o nome promete. **E há uma assimetria a mais, na direção do falso negativo:** `templates/` está fora do universo de *definição* e **dentro** do de *referência* — os dois harnesses definem funções homônimas (`Test-Caso`, `Assert-True`, `Get-Texto`), então uma chamada no template mantém o nome "chamado" na plataforma. Hoje não há instância viva: todas têm chamador real aqui |
| 13 | **O guarda de campo só enxerga bloco atribuído a `$cob`.** Isso é uma **convenção**, não uma heurística: detector novo que use outro nome de variável sai do alcance **sem aviso**. A alternativa — varrer todo objeto devolvido — foi medida e acusa 18 estruturas internas de trabalho, então o caminho foi declarar a convenção na docstring e trazer para dentro dela o detector que escapava (`scan-excecoes.ps1`, cujo resumo de disposição carregava justamente `Cobertos`, a órfã que este mesmo guarda achou na rodada 9) | não detecta | Quando existir um sexto detector. Enquanto isso, a convenção está escrita onde quem escreve detector vai ler |
| 14 | **O `Get-Texto` da plataforma foi endurecido sem par de execução.** Ele passou a lançar em byte inválido (rodada 12), mas o único caso que entrega byte inválido a um leitor exercita o **gêmeo do template**, dentro de projeto instanciado. Mutação que sobrevive: voltar a linha para `[Text.Encoding]::UTF8` | não detecta a regressão | `MEDIA não-bloqueante` pelo critério de 2026-09-14: o código no disco está correto, a direção da falha é lançar, e a ausência é de **regressão**, não de comportamento — não produz falso verde hoje. O item 8 cobria a classe sem nomear este |
| 15 | **Os ramos `py esta no PATH e nao listou runtime` e `gh esta no PATH mas nao respondeu` não têm caso.** O par do `git` ficou completo — ausência e presença —, os outros dois só têm o ramo de ausência | não detecta a regressão | `MEDIA não-bloqueante`: os dois ramos trocam um `[OK]` falso por `AVISO`. Erram **alto**, não afirmam ambiente que ninguém mediu |
| 16 | **As quatro listas novas do relatório truncam em 20 itens sem o sufixo "e mais N"**, ao contrário da linha de blob vazio e da de arquivos ausentes, que somam o resto | não aplicável | `BAIXA`: a contagem sai na mesma linha, então quem lê reconcilia sozinho. É inconsistência de forma, não perda de fato. Deliberadamente **não** corrigido na rodada 13, para não mexer no gerador de relatório imediatamente antes da varredura de fechamento |
| 17 | **O caso da coluna `Coberta` blinda contra duas das quatro lacunas irmãs, não contra as quatro.** Ele exige a ausência de `Classe de caractere completa` e de `compartilham sonda`, mas não de `NaoVerificaveis`, que também arma o portão. Cenário de regressão futura: alguém acrescenta uma regra com `**` ao literal da fixture, a coluna cai `parcial` por **esse** motivo, e o caso volta a passar sem exercitar a cláusula que existe para guardar | não detecta a regressão | `BAIXA` pelo critério de 2026-09-14: hoje é inalcançável pela fixture — traçado pelo `qa-reviewer` — e erra para o lado seguro. Fechar junto com o item 14 |
| 8 | **Ramos-guarda sem par negativo.** `Invoke-Git` com código `> 1` em `check-ignore` e `config --get-all`; guarda de `remote -v` vazio contra `[remote]` no `.git/config`; guarda de `cat-file --batch-check` vazio; guarda de `ls-files` vazio contra arquivo no disco. Nenhum tem caso que o exercite | todos **lançam** — nenhum produz verde falso | Quando houver motivo para mexer nesses ramos. O `qa-reviewer` concordou com o critério de direção; o que faltava era estar **escrito** |
| 9 | **O marcador de fixture é a única rota de rebaixamento que atravessa a fronteira de publicação.** Rebaixa `ALTA`→`BAIXA` por autodeclaração no cabeçalho, sem exigir caminho, categoria nem decisão registrada, e **não** é anulado por `-ParaPublicacao` — ao contrário do mecanismo de exceção, que é o rigoroso. Recomendação do `security-reviewer`: fazê-lo valer só sob `tests/` e `examples/`, e ser anulado na publicação | não detecta | **Decisão sua**, não inferência da ferramenta. Neste repositório governante, cujo template é copiado para projetos com dado real, a consequência é maior do que `BAIXA` sugere |
| 10 | **O `.gitignore` da plataforma não tem o que o do template tem.** Confirmado por `git check-ignore -v` padrão a padrão, não por leitura: `*.sqlite` (o mais grave — carrega base inteira), `*.csv`, `.aws/`, `.azure/`, `*.crt`, `*.cer`, `*.jks`, `*.keystore`, `*password*`, `*cookie*`, e os formatos **legados** de Office (`*.doc`, `*.xls`, `*.ppt` e variantes — os modernos `*.xlsx`/`*.docx`/`*.pptx`/`*.pdf`/`*.pbix` **já** estão bloqueados). **A lista é ilustrativa, não exaustiva: derive-a comparando os dois arquivos, não copiando daqui.** `secrets/` **não** está na lista — `*secret*` (`.gitignore:31`) já o casa em qualquer profundidade. Hoje não existe nenhum arquivo desses na árvore | não detecta | Custo baixo, e fecha **por caminho** o que hoje depende de ninguém errar — justamente onde o scanner roda fixtures de credencial |
| 11 | **Os leitores de conteúdo do scanner usam `[Text.Encoding]::UTF8`**, que substitui byte inválido por `U+FFFD` em silêncio — a mesma leitura que o harness do template acabou de abandonar — *o `bootstrap.ps1` do template, nao; a frase original era mais larga que o fato, e o `qa-reviewer` a estreitou.* Arquivo em **UTF-16 sem BOM** teria os NULs quebrando todo regex de credencial e apareceria no carimbo como "examinado". Desde a décima segunda rodada **está** declarado na tabela de teto permanente do relatório, que é onde o revisor lê; o item continua aberto porque declarar não é corrigir | não detecta | **FECHADO em 2026-09-17** — corrigido, não declarado como teto. Ver *Itens 26, 30 e 11 fechados*, abaixo |

E uma nuance que o `security-reviewer` levantou sobre o **fato 1 da 2.3**, que vale registrar porque não é visível em número: o mecanismo do marcador de fixture não mudou, mas a **superfície** dele cresceu — `tests/suites/collectors.ps1` ganhou 136 linhas nesta subfase, todas cobertas pela mesma declaração única do cabeçalho. A contagem de `BAIXA` não muda (21 antes, 21 agora) porque o relatório agrupa por arquivo × categoria. Se um dia estreitar o fato 1, o critério útil é por ocorrência ou por proximidade da declaração, não por arquivo: uma linha no cabeçalho cobre o arquivo inteiro, e o arquivo cresce — o `security-reviewer` mediu duas vezes e o número envelheceu entre as medições, na mesma rodada que alargou a superfície. Por isso o número saiu daqui: o que importa é o critério, não o tamanho de hoje.

## Pré-requisito da 2.5 — `Test-TemCommits` separado em dois predicados. **Concluído em 2026-09-15**

Era o item 1 do backlog da 2.4, o único marcado como obrigatório antes da 2.5. O motivo de ser obrigatório: o `/os:doctor` roda sobre repositório em **estado arbitrário**, que é onde a ambiguidade sai do improvável.

**O defeito não era o nome.** Um predicado respondia a duas perguntas diferentes — *"há histórico a varrer?"* e *"o `HEAD` resolve?"* — e era usado para as duas. Depois de `git init` + `remote add` + `fetch` as respostas **divergem**, e as duas correções óbvias estavam erradas em direções opostas: devolver falso fazia o detector afirmar *"não existe histórico a varrer"* sobre um repositório com blobs buscados; devolver verdadeiro fazia `rev-parse --short HEAD` lançar.

**Os três consumidores foram classificados antes de migrar**, não renomeados em massa:

| Consumidor | O que executa em seguida | Predicado correto |
|---|---|---|
| `scan-dado-pessoal.ps1` | `git log --all --format=%ae` | `Test-TemHistorico` — `--all` varre **refs**, não o `HEAD` |
| `scan-historico.ps1` | `rev-list --all` | `Test-TemHistorico` — mesma razão |
| `security-scan.ps1` | `rev-parse --short HEAD` | `Test-HeadResolvivel` — precisa de ponto de partida que resolva |

**`Get-CaminhosDoGit` entrou junto, e resolve o caso que a versão anterior recusava.** Quando `.git` é **arquivo** — worktree ligado ou submódulo — o predicado antigo lançava *"não dá para conferir"*. Estava certo enquanto ninguém rodava sobre worktree; o doctor roda. Em worktree ligado o `HEAD` é próprio e as refs são compartilhadas, então os dois caminhos **diferem**, e a função devolve os dois separadamente lendo `gitdir:` e `commondir`.

**Casos cobrindo os cinco estados e as duas perguntas em cada um** — a contagem não fica registrada aqui, de propósito, porque número em prosa envelhece e o cabeçalho traz o total da suíte, não o desta seção. Os estados cobertos são: recém-`init`; com commit; com `fetch` e sem `HEAD` local (o que diverge); worktree ligado; `HEAD` simbólico para ref inexistente; `HEAD` ilegível; ref existente que o git não resolve; e caminho que não é repositório. Nos três últimos o predicado **lança** — "não consegui determinar" nunca vira falso verde.

#### O caso que expôs um falso verde que eu tinha acabado de escrever

A primeira versão dos casos foi posta numa suíte que **não carrega a lib**. Três deles esperavam uma exceção, receberam *"o termo não é reconhecido"* e passaram — verde pela razão errada, exatamente a classe que a 2.4 perseguiu por treze rodadas.

Ao mover para a suíte certa e **exigir que a exceção fosse a certa, não qualquer exceção**, o caso de `HEAD` ilegível falhou de verdade e revelou o defeito:

> `git rev-parse --verify --quiet HEAD` com o **sha nulo** (40 zeros) em `.git/HEAD` sai com **`0`** e imprime os 40 zeros.

O predicado devolveria `true`, e o `security-scan.ps1` carimbaria o relatório com `0000000` como se fosse um commit. Falso verde dentro da função escrita para eliminar falso verde. A correção é `HEAD^{commit}`, que obriga o objeto a existir **e** a ser commit — verificado nos três estados: sai `1` para o sha nulo, `1` para repositório sem commits, `0` só quando há commit de verdade.

**Duas regras que saem daqui, e valem para toda a plataforma:**

- **Asserção de exceção que não olha a mensagem aceita qualquer falha**, inclusive a de o código sob teste não existir.
- **`rev-parse --verify HEAD` não prova que o `HEAD` é um commit** — prova que a string tem forma de sha. **Está no runbook** — e a primeira versão desta linha afirmava isso quando não estava. O `qa-reviewer` foi conferir, achou zero ocorrência, e mostrou o agravante: o runbook **prescrevia**, em duas entradas, exatamente o padrão que acabara de ser provado defeituoso, num arquivo que o `CLAUDE.md` manda ler antes de mexer em Git. Afirmação falsa no registro é pior que lacuna assumida — a próxima guarda escrita seguindo o runbook reintroduziria o falso verde enquanto o `STATE` dizia que a lição tinha sido capturada.

### Revisão do pré-requisito — dois `MEDIA` bloqueantes, e um achado que os dois revisores fizeram sozinhos

**`qa-reviewer`: REPROVADO** na primeira submissão, com três `MEDIA`. **`security-reviewer`: REPROVADO da delta** por um `MEDIA` bloqueante — o **mesmo** que o QA achou, por caminho independente. As seis áreas de vazamento dele saíram aprovadas: *"não há nada indevido saindo deste repositório; o que bloqueia é a garantia que a delta declara e não prova."*

**O achado em que os dois convergiram: o caso de worktree passava sem executar uma linha do código de worktree.** Os dois predicados retornam `true` nos ramos **positivos**, antes de chamar `Get-CaminhosDoGit`. Trocar o bloco inteiro de `gitdir:`/`commondir` por `return $null` mantinha os oito casos verdes. A asserção anti-vacuidade que eu tinha escrito confere que a **fixture** é um worktree — não que o **ramo** foi alcançado; dá a impressão de cobrir e não cobre. É a mesma classe que esta entrega documenta, um nível adiante.

O conserto é um caso que **força o caminho negativo dentro do worktree**: exercita `Get-CaminhosDoGit` diretamente (exige `Ligado`, exige `GitDir ≠ ComumDir`, exige que o `GitDir` contenha o `HEAD` e o `ComumDir` contenha `refs/`) e só então reescreve o `HEAD` para ref inexistente, exigindo **`false`** e não exceção — o que só acontece se os dois caminhos foram resolvidos.

**A quarta cópia do predicado, no pior lugar possível.** O `qa-reviewer` achou, fora do diff, uma cópia inline em `collect-diff.ps1` — **o coletor que produz a evidência das revisões** — com o código pré-correção e dois defeitos: `rev-parse --verify HEAD` sem `^{commit}`, e **qualquer** código diferente de zero virando `$temHead = $false`, o que fazia o relatório escrever a afirmação positiva *"o repositório não tem nenhum commit... todo o conteúdo é novo"* diante de `HEAD` ilegível ou permissão negada. O arquivo já carregava `scan-comum.ps1`: a cópia nunca precisou existir.

**Um falso verde a mais, que o `security-reviewer` mapeou sozinho.** Comparando estado a estado, ele mostrou que o predicado antigo, dado um diretório **que não é repositório**, caía até o fim e devolvia **falso** — que o detector traduz em `SemCommits` e o relatório imprime como *"não existe histórico a varrer"*. Estava contido apenas pela guarda de entrada do scanner. A separação elimina **dois** falsos verdes, não um.

#### O que as falhas de teste ensinaram nesta rodada

Duas falharam, e nenhuma foi ruído:

- **Uma era expectativa minha errada, não código errado.** Em diretório que não é repositório, `rev-list --all` sai com `128` e o predicado lança no portão do código de saída, com a razão certa para aquele estado. Ajustei a asserção ao comportamento real, em vez de ajustar o código à minha expectativa.
- **A outra revelou que a guarda que eu queria testar é inalcançável.** Plantei uma ref quebrada esperando `rev-list --all` devolver vazio com refs no disco; o git falha antes. Não encontrei fixture que produza a condição. O caso passou a afirmar o que a fixture **realmente** exercita — falha do git não vira "sem histórico" — e a guarda `refs > 0` ficou no backlog como segunda linha de defesa **sem par de execução**, declarada. *Errar alto sem caso é diferente de errar baixo sem caso*, e é essa diferença que justifica não bloquear.

#### A guarda de remoto público estava inerte em worktree — e os dois revisores discordaram sobre desde quando

Vale registrar porque a divergência é informativa, e porque um deles estava errado.

A guarda que impede um **remoto público** passar sem achado `ALTA` testava `.git\config` **por caminho**. Em worktree ligado `.git` é arquivo, `Test-Path` dá falso, e a guarda — a única `ALTA` daquela área — fica **inerte em silêncio**.

O `security-reviewer` disse que esta delta tornou o defeito **alcançável**: antes, com `.git` sendo arquivo, o predicado lançava e o scanner saía com `2` sem relatório; ao ensinar os predicados a resolver `gitdir:`, o scanner passaria a rodar sobre worktree e a emitir relatório afirmativo com a guarda dormindo. *"O que mudou agora não é o defeito, é a acessibilidade dele."*

O `qa-reviewer` foi testar essa mesma hipótese e concluiu o contrário, com o mecanismo: **o predicado antigo só lançava quando o `rev-parse` falhava** — e num worktree **com commits**, que é o caso normal, ele resolve e devolvia `true`. O scanner já rodava sobre worktree, e a guarda já estava inerte. Barreira não havia.

**O QA está certo.** A leitura do `security-reviewer` vale apenas para worktree *sem* `HEAD` resolvível, que é raro. A delta não piorou nada; o defeito era pré-existente e mais antigo do que qualquer um dos dois supôs.

Corrigi assim mesmo — a guarda passou a usar `ComumDir`, e lança quando não consegue localizar o diretório Git —, porque o conserto é de duas linhas e fecha uma guarda `ALTA` genuinamente morta. **O que não se registra é a razão errada:** o item saiu do backlog por estar corrigido, não porque a delta o tivesse criado.

Um efeito colateral que vale nomear: **quando dois revisores independentes discordam sobre o mesmo fato, a discordância é o achado.** Nenhum dos dois teria produzido sozinho a análise correta — o security nomeou o defeito, o QA nomeou o mecanismo, e só o cruzamento dos dois dá a data certa.

### Backlog aberto pela revisão do pré-requisito — 2026-09-16 (itens 18 e 20 a 27; itens 29 a 37 de 2026-09-17; 38 a 41 de 2026-09-18; **42 a 93 de 2026-09-20/22**, das dezenove rodadas da 2.5; **94 a 98 de 2026-09-27** e **99 a 120 de 2026-10-01/02**, da 2.6; o 28 foi fechado **em parte** — ver abaixo)

> **Os itens 32 e 33 foram registrados DEPOIS dos dois vereditos de aprovação**, e portanto não estão cobertos por eles. São os dois `BAIXA` finais do `qa-reviewer`, registrados porque a regra manda registrar nominalmente — e declarados aqui porque o carimbo dos relatórios é anterior a estas duas linhas. Nenhum dos dois toca código.

O item 19 não está nesta tabela porque **foi corrigido na própria rodada** — ver a seção acima. A numeração dos demais ficou como estava, para que as referências das rodadas anteriores continuem apontando para o mesmo item.

| # | O que é | Direção da falha | Quando |
|---|---|---|---|
| 120 | **O título do caso dos shims é mais largo que o que ele mede.** Achado do `qa-reviewer` na oitava rodada | a mesma classe que esta subfase perseguiu sete rodadas, agora em escala pequena | Quando o caso dos shims for revisto, junto dos itens 117 e 118 |
| 119 | **A borda de cima da regra de controle não tem amostra.** As amostras são `0x00`, `0x08`, `0x1B` e `0x7F`; a mutação `-lt 32` → `-lt 28` **sobrevive**, porque nada entre `0x1C` e `0x1F` é exercitado. Achado do `qa-reviewer` na oitava rodada | com essa mutação, `0x1C` a `0x1F` passariam pelo guarda com a suíte verde — é falso verde estreito, mas é falso verde | Conserto barato: uma amostra em `0x1F`. Não foi feito nesta rodada para não alargar a delta após os dois `APROVADO` |
| 118 | **Sobrou UMA cópia do predicado de ASCII**, em `tests/suites/hooks.ps1`, no caso dos shims: ele escreve `$_ -gt 127` na própria linha em vez de chamar `Get-BytesNaoAscii`. Achado do `qa-reviewer` na oitava rodada | mesma classe do bloqueante da sétima rodada, em escala menor — trocar por `-gt 255` ali não derruba nada | **E corrige uma afirmação minha:** eu escrevi *"não há mais cópia"*; o certo é *"não há mais cópia nos `.ps1`"*. Junto dos itens 117 e 120 |
| 117 | **O guarda de byte varre só `*.ps1`.** Os shims de `githooks/` não têm extensão e ficam de fora. Achado do `security-reviewer` na sexta rodada; ele varreu o repositório e **não achou nada hoje** | o mesmo caractere invisível que desarmou uma regex pode entrar num shim sem ninguém ver | Quando o guarda for revisto. O caso próprio dos shims recusa byte acima de 127 e `CR` — então, **dos controles, ele cobre só o `CR`**: `0x08`, `0x7F`, `0x00` e `0x1B` passariam por ele. *(A primeira redação dizia que aquele caso "cobre parte disto" sem dizer que parte, e era mais larga que o código — contra a própria lição de que "ASCII não é o mesmo que imprimível". Achado do `qa-reviewer`.)* |
| 116 | **DEZ dos DEZESSEIS padrões do scanner não têm teste POSITIVO.** Sem amostra que case, um padrão quebrado — por caractere invisível, erro de digitação ou âncora errada — deixa a suíte verde e o relatório seguir dizendo *"8 padrões"*. Achado do `security-reviewer`, respondendo à pergunta que a 2.6 levantou. Sem teste positivo hoje: PAT fino do GitHub, chave da Anthropic, chave estilo OpenAI, access key da AWS, token Bearer, e os cinco webhooks de exposição | **detector desarmado não falha: ele APROVA.** É falso verde no componente cuja única função é não produzir falso verde | Ele classificou **MEDIA, não bloqueante agora** — leu os 16 padrões, todos ASCII, entre aspas simples, sem controle, sintaxe plausível: *"a cobertura atual se sustenta por inspeção, mas não por teste"*. **Vira condição antes de qualquer `-ParaPublicacao`.** A forma que ele prescreveu: um caso que percorre `Get-PadroesConteudo` e `Get-PadroesExposicao` exigindo amostra fabricada para cada entrada, e que **falha se surgir padrão novo sem amostra** |
| 115 | **A forma `& $exe -File $x` — nome do executável numa VARIÁVEL — não é detectável por regex**, e traz o stderr do filho igual às outras. É a **mesma forma da porta legítima** (`& $Comando @Argumentos`, em `bootstrap.ps1:42`), então nem distinguir uma da outra por texto é possível. Achado do `qa-reviewer` na sexta rodada | o guarda de invocação tem teto estrutural, não de implementação: nenhuma regex fecha isto | **Declarado, não prometido:** o título do caso passou a dizer "grafias **LITERAIS**", e o código carrega escrito o que não alcança. O resto depende de revisão humana |
| 114 | **`Start-Process` com o nome em posição inesperada.** `-FilePath powershell` e caminho montado por variável passaram a ser detectados na quinta rodada. Achado do `qa-reviewer` | **risco menor, e por um motivo específico de `Start-Process`:** sem redirecionamento, ele não traz o stderr do filho para quem chama — que é o defeito que o guarda existe para impedir. *(A primeira redação deste item juntava este risco com o da forma `& $variavel`, que é **maior** e virou o item 115 — ali o stderr vem. E citava um título de caso que não existia. Duas correções do `qa-reviewer` na sexta rodada.)* | Se a forma aparecer |
| 113 | **O `$ehPorta` liberava qualquer linha que MENCIONASSE o nome de uma porta**, inclusive num comentário ao lado de uma chamada direta. Achado do `qa-reviewer` | permissão por menção de texto — e o ramo nunca disparava legitimamente | **Fechado em 2026-10-02:** o ramo foi removido junto com o marcador; a lista fechada substituiu os dois |
| 112 | **`Invoke-FilhoDoHook` não zera `$LASTEXITCODE` antes da chamada.** Se o `& powershell` não chegasse a executar, o valor lido poderia ser o de um comando anterior. Achado do `security-reviewer` na terceira rodada | ele próprio classificou **não bloqueante** e disse o porquê: o hook já está rodando num `powershell` que o shim chamou pelo nome, e erro de comando dentro do `try` deve propagar ao `trap`. **Ele registrou que não mediu o segundo motivo** | Conserto barato que ele nomeou: zerar `$global:LASTEXITCODE` antes e tratar `$null` como "não rodou" |
| 111 | **O título do caso estrutural prometia mais do que a regex media**, duas vezes: varria só `hook-*.ps1`, e só a forma com `&`. Achado do `qa-reviewer` nas rodadas 2 e 3 | foi assim que `bootstrap.ps1:239` passou despercebido — o guarda não olhava para o arquivo onde o defeito estava | **Reaberto em 2026-10-02, pela segunda vez.** A primeira tentativa foi declarada fechada e **não estava**: o caso isentava `bootstrap.ps1` e `hooks-comum.ps1` por ARQUIVO, então uma chamada direta **nova** neles passaria — o defeito da rodada 3, no mesmo arquivo. E a grafia sem `&` só era reconhecida no **início da linha**, o que deixava de fora a forma com atribuição, que é a habitual aqui. Achados do `qa-reviewer` na quarta rodada. A **segunda** tentativa também foi declarada fechada e também não estava: o marcador `PORTA-PROTEGIDA` era **permissão que se autodeclara** — bastava copiar a linha com o comentário junto. A **terceira** forma remove o que havia para declarar: **lista fechada no teste**, por caminho relativo + conteúdo exato, com **contagem**. *(E este item **não se declara fechado**: duas declarações de fechamento já vieram com ponto cego, e quem fecha é o revisor, não eu.)* |
| 110 | **`collect-diff.ps1:322` tem o mesmo padrão de stderr**, com `try/catch`. Uma suíte que **passa** e escreve em stderr é registrada pelo coletor como *"falhou ao ser executado"*, com exit `-1`. Observação do `qa-reviewer`, que declarou explicitamente **não ser achado desta delta** — é anterior à subfase | *fail-closed*, mas com **diagnóstico errado na ferramenta que produz a evidência da revisão**. Nesta coleta não ocorreu: exit 0, saída completa | **É a exceção NOMEADA do caso estrutural dos hooks** — nomeada e com prazo por EVENTO, não por data. *(Eu havia escrito "NOMEADA e DATADA" e não há data nenhuma; achado do `qa-reviewer`.)* Quando fechar, o par positivo daquele caso falha de propósito e manda remover a exceção junto |
| 109 | **Os códigos sentinela `97` e `98` do `pre-push` podem COLIDIR** com uma suíte que saia por conta própria com esses valores: ela seria rotulada como não tendo rodado. *(O rótulo exato citado na primeira redação deste item — "não invoquei" — deixou de existir quando a mensagem do `97` foi reescrita na mesma rodada. Achado do `qa-reviewer`.)* Achado do `security-reviewer` na segunda rodada | **só diagnóstico** — o hook continua barrando com `2`, então não há *fail-open* | Se algum projeto governado usar esses códigos. A saída alternativa é o filho gravar o código num arquivo em vez de codificá-lo no exit |
| 108 | **A mensagem de BLOQUEIO do `pre-commit` não lembra o lado da fricção:** quando ele barra, não diz que o achado pode estar num arquivo **não rastreado**, fora do commit. O caminho aparece na lista de achados, então dá para descobrir. Sugestão do `security-reviewer`, explicitamente **não** condicional | é o momento exato em que alguém aprende `--no-verify` | Quando a mensagem de bloqueio for revista. Junto do item 99 |
| 107 | **`pre_push` como escalar vazio (`pre_push: ""`) cai no PADRÃO, enquanto o mesmo vazio como item de lista BARRA.** Medido. As duas formas dizem a mesma coisa e recebem tratamentos diferentes. Achado do `qa-reviewer` | incoerência entre formas equivalentes; nenhuma das duas é falso verde depois do conserto da rodada 2 | Quando o leitor de manifesto distinguir "campo sem valor" de "campo com valor vazio" |
| 106 | **A suíte do projeto é executada como CÓDIGO PowerShell dentro de `-Command`**, com `verificacao.comando` entrando cru. É a mesma confiança do código do próprio checkout, e o `hooks.md` já declara isso. Observação do `security-reviewer`, não é achado novo — `& $comando` já existia | não é escalada de privilégio: quem escreve o manifesto já escreve o código que roda | Se a plataforma passar a executar manifesto de origem que não seja a mantenedora |
| 105 | **Casos que conferem CÓDIGO DE SAÍDA sem conferir CAUSA**, listados pelo `qa-reviewer`: o do segredo no `pre-commit` não distingue `1` de `2` — o próprio `trap` do hook casaria a asserção; o de *"NÃO mexe no staging"* não compara o staging depois, então um `git add -A` dentro do hook sobreviveria; o de *"mensagem só de comentários"* não mede a filtragem, porque a regra da linha 2 reprovaria igual | mesma classe que a mutação já expôs duas vezes nesta Fase: asserção de saída sem asserção de causa aceita qualquer falha | Quando a suíte de hooks for revista |
| 104 | **A invariante das dimensões canônicas não tem caso que exercite o `throw`.** Remover a guarda de `doctor.ps1` sobrevive à suíte, porque a execução saudável nunca diverge. Achado do `qa-reviewer` | guarda-corpo sem par negativo não está verificado — a lição da nona rodada da 2.4, aqui de novo | Conserto barato: dimensão duplicada numa fixture. Junto do item 50 |
| 103 | **Clone novo e a seção 5 do `bootstrap` (hooks) não têm caso.** O `bootstrap.ps1` resolve a **própria** raiz a partir do caminho dele, então não dá para apontá-lo a uma fixture sem refatorá-lo. Portabilidade ficou `INCONCLUSIVO` por isso na primeira rodada | o passo que fecha o contrato de clone-and-run é o único sem evidência executada | Quando o `bootstrap` aceitar `-Raiz`, ou num teste de clone real com evidência gravada |
| 102 | **`scan-historico.ps1` chama `Test-ArquivoDeTexto` SEM `-Raiz`**, então caminho relativo sem extensão é resolvido contra o **diretório corrente**. Achado do `qa-reviewer` | continua *fail-closed*, mas a cobertura do histórico deixa de ser determinística: muda conforme de onde o scanner é chamado | O comentário atual diz que é deliberado, e a razão (caminho do histórico pode não existir no disco) continua válida — mas passar `-Raiz` resolve as duas coisas. Conserto de uma linha |
| 101 | **Os hooks transcrevem stdout E STDERR de processo filho para o terminal — e daí para o transcript da sessão.** *(Era "stdout" até 2026-10-02; com `2>&1` sob `Continue` o stderr do filho também entra na saída capturada, e antes desta subfase ele derrubava o hook em vez de chegar à tela. Achado do `security-reviewer`.)* Dois lugares: o `pre-commit` despeja o stdout inteiro do scanner quando sai com `2`, e o `pre-push` imprime as últimas 10 linhas da suíte quando a etapa `tests` não passa. **Ampliado em 2026-10-02 a pedido do `security-reviewer`**, que notou que o segundo caso é a mesma classe: num projeto instanciado, uma asserção que falha pode imprimir dado real. O `security-reviewer` registrou que **não verificou** o que esse stdout pode conter; tudo indica que são mensagens de erro e caminhos | transcrição não auditada para a tela, e daí para o transcript da sessão | Quando o caminho de erro do scanner for revisto |
| 100 | **O `commit-msg` diverge do `cleanup` do próprio Git.** Com `-m` e `-F` o Git usa `cleanup=whitespace` e **mantém** as linhas iniciadas por `#`; o hook as descarta sempre. Dois efeitos, achado do `qa-reviewer`: **falso bloqueio** — `git commit -m "#42 corrige X"` barra como "mensagem vazia" — e **falso verde** — com `-F`, linha 2 igual a `#123 relacionado` passa, e o commit final sai com o assunto colado, que é exatamente a classe de `f6e3d5b`. Também: `git revert` de assunto entre 92 e 100 caracteres estoura o limite | o falso verde atinge o hook no **próprio defeito que ele existe para pegar**, e no modo (`-F`) que esta casa usa para commitar | Classificado `BAIXA` por ele. Declarado no `hooks.md`. O conserto exige distinguir o modo de invocação, que o Git não informa ao hook — sem heurística frágil |
| 99 | **O `pre-commit` lê o DISCO, não o ÍNDICE.** Prescrição nominal do `security-reviewer` ao aceitar a declaração como condição mínima: ler os blobs de `git ls-files -s` | enquanto não for feito, o falso verde descrito no `hooks.md` continua existindo — agora **declarado**, que era a condição para não bloquear | Quando valer a pena abrir superfície nova no scanner. Hoje a 2.6 a evitou de propósito |
| 98 | **O `pre-push` roda a bateria inteira também quando o push APAGA um branch** (`git push --delete`), em que não há histórico novo a verificar. Ele lê a política e executa como em qualquer push | custo sem contrapartida; ninguém ganha nada varrendo para apagar uma ref | Quando começar a atrapalhar. O hook recebe as refs por stdin e dá para distinguir |
| 97 | **O `pre-commit` varre o REPOSITÓRIO inteiro, não só o que está em staging.** Hoje são 8,2 s em 93 arquivos; o custo cresce com o projeto, e a pergunta do momento é sobre o que está entrando | um dia vira lento o bastante para ensinar `--no-verify`, que é o modo de falha que o desenho inteiro tenta evitar | Quando passar de ~15 s. A alternativa é um modo do scanner limitado aos caminhos em staging — **superfície nova no scanner**, que é justamente o que a 2.6 evitou |
| 96 | **Hooks de PLUGIN do Claude Code: um, desde 2026-10-16.** `hooks/hooks.json` declara o guarda `PreToolUse` de git destrutivo para agentes (`hooks/guarda_git.py`, motivado pelo incidente r13) e `project.yaml` declara `hooks: 1`. Antes eram zero: a 2.6 entregou hooks de **Git**, que são outra coisa | o hook só vale numa sessão depois de atualizar/reinstalar o plugin (`0.1.3`; a cópia instalada é congelada); o que ele não cobre está em `docs/runbooks/hooks.md` | **Atendido** pela política de ferramenta do guarda. Outros hooks de plugin: quando houver política que valha impor |
| 95 | **A frase *"todo hook do Git roda com `GIT_DIR`"*, no registro do item 30, é mais larga que o medido.** A sonda da 2.6 mostrou `GIT_DIR` **vazia** no `commit-msg` deste Git for Windows | afirmação larga sobre verificação estreita — a classe que a 2.5 perseguiu a subfase inteira. Não afeta código: a fixture daquele caso **define** a variável, então o que ela mede continua válido | Quando a seção do item 30 for revista |
| 94 | **DECISÃO DA MANTENEDORA, pendente. O template não ganhou hooks**, e as duas saídas têm custo real: (a) copiar scanner e doctor para dentro de cada projeto — duplica a plataforma e cria seis detectores divergindo; (b) o template receber **só o `commit-msg`**, que é função pura sobre texto — barato e portátil, mas cria **segunda implementação da mesma regra**, que é a origem de sete defeitos da 2.5. Caminho absoluto para o plugin desta máquina está descartado: é a dependência oculta do computador atual | projeto governado novo nasce **sem** guarda-corpo local, e ninguém é avisado disso | Antes da 2.8. A opção (b) com **uma** fonte de verdade — o template gerando o arquivo a partir da função da plataforma no `/os:new-project` — é a que eu proporia |
| 93 | **"As sete formas de raiz, medidas em execucao" enumera SEIS.** A setima — `.git` como **arquivo** — so aparece na lista do `CHANGELOG`. Achado do `qa-reviewer` na rodada 19 | rotulo mais largo que a enumeracao, no arquivo que quem chega le primeiro | Pre-existente. Quando a secao for revista |
| 92 | **Numero posicional em prosa, DUPLICADO em dois arquivos:** *"a palavra aparece de novo seis linhas abaixo"* no `STATE` e *"6 linhas abaixo"* no comentario do caso de contrato. Hoje e verdade; inserir **uma** linha na `SKILL.md` torna as duas falsas ao mesmo tempo. Achado do `qa-reviewer` na rodada 19 | mesma familia do "200 linhas" e do "40 linhas" que as rodadas anteriores removeram, agora em duplicata | Quando a `SKILL.md` for reescrita |
| 91 | **O `security-report.md` soma rastreados e nao rastreados sem dizer QUAIS sao quais** — e essa distincao e o que separa *"ja vazou"* de *"vaza no proximo `add`"*. O `security-reviewer` fechou a duvida cruzando com o `diff-report.md`: **acoplamento entre dois relatorios, que nao deveria ser necessario**. Achado dele na rodada 19 | obriga o revisor a compor evidencia de duas fontes para responder o que uma deveria responder | Quando o relatorio de seguranca for revisto. Junto do item 68 |
| 90 | **`Remove-RepoDoctor` usa `-ErrorAction SilentlyContinue`:** fixture orfa pode sobrar em `%TEMP%` sob lock, sem ninguem saber. Achado do `security-reviewer` na rodada 19 | fora do repositorio e sem dado real — registrado para nao ficar implicito | Se o `%TEMP%` comecar a acumular fixture |
| 89 | **A fixture roda `git add -A` e `git commit` sem assercao de que o `git init` deu certo**, com `2>$null` e `ErrorActionPreference = Continue`. Se o init falhar em silencio, o `add -A` sobe procurando repositorio ancestral — em `%TEMP%` hoje nao acha nada, entao **a garantia e do ambiente, nao do codigo**. Achado do `security-reviewer` na rodada 19 | o dano possivel seria **fora** deste repositorio, e depende de o `%TEMP%` nunca estar sob repositorio | Conserto barato, que ele mesmo nomeou: `Assert-True (Test-Path .git)` logo apos o `init`, antes de qualquer `add`. Junto do item 47 |
| 88 | **DECISÃO DA MANTENEDORA, pendente.** O prazo do item 86 está em "antes do fechamento da 2.6", e o `qa-reviewer` sugeriu a **2.5**. A consequência, nomeada por ele e não contestada por mim: **a 2.5 fecha com o contrato publicado (`SKILL.md`) carregando afirmação verificável — códigos de saída, regra de dominação, o caso `raiz` — sem detector algum** | o contrato publicado pode divergir do código em silêncio, e já divergiu uma rodada inteira | **DECIDIDO em 2026-09-22: construir o detector antes de fechar a 2.5.** Feito — ver *"o detector que a 2.5 ganhou"* na seção da subfase |
| 87 | **Na seção `## git diff` do relatório de coleta, acento sai MOJIBAKE**, enquanto a seção `Arquivos novos` sai correta. Causa: o stdout do `git` é decodificado pela codepage do console, e o `collect-diff.ps1` não troca `[Console]::OutputEncoding` como o `scan-historico.ps1` faz. Achado do `qa-reviewer` | **um `.md` rastreado genuinamente gravado em ANSI e um íntegro produzem a mesma aparência nesse canal** — regressão de encoding em arquivo rastreado fica invisível para o relatório | Pré-existente, fora da delta. Antes de o coletor ser usado para julgar encoding |
| 86 | **A prosa do relatório (`Write-RelatorioDoDoctor`) e da `skills/doctor/SKILL.md` não tem detector nenhum.** Nenhum caso compara o texto fixo do relatório, e a `SKILL.md` só é verificada por `plugin validate` (estrutura, não conteúdo). Foi por isso que uma afirmação **falsa** sobre código de saída sobreviveu uma rodada inteira depois de eu a ter corrigido no código. Achado do `qa-reviewer` | o contrato publicado pode divergir do código em silêncio | **FECHADO EM PARTE em 2026-09-22**, por decisão da mantenedora (item 88). **O que tem detector:** a escada de status, o mapa de código de saída da `SKILL.md`, os cenários que ela nomeia — com o código esperado **extraído da própria prosa** — e o código que o **relatório declara de si mesmo**. Provado por mutação em toda rodada que o tocou, **inclusive mutações que mudam só a prosa** — entre elas a que o `qa-reviewer` entregou pronta na rodada 14 e a que ele derivou na rodada 15, as duas sobreviviam antes do conserto. **O que continua SEM detector:** o resto do texto fixo do relatório, e o parágrafo da regra de dominação. **E o que tem detector, tem por ENUMERAÇÃO:** os cenários são chaves fixas no caso — veja `$cenarios` e `$doisDaLinha` em `tests/suites/doctor.ps1`, que é onde a lista vive e onde ela se mantém atual. Uma promessa **nova** acrescentada amanhã à linha de códigos nasce **sem detector, em silêncio**. Delimitação cobrada pelo `qa-reviewer` na rodada 15 — e na 17 ele mostrou que **a lista escrita aqui já tinha envelhecido** com o rename da própria rodada 16: por isso ela deixou de ser transcrita e passou a apontar para o código. Delimitação cobrada por ele na rodada 14 — eu tinha marcado "FECHADO" com a afirmação mais larga que a medição, dentro do item que existe para pegar exatamente isso |
| 85 | **Dois pares de rótulos que diferem por uma palavra na mesma dimensão**, hoje inalcançáveis porque os ramos são exclusivos por `continue`: `ambiente` (`"a ferramenta X"` × `"ferramenta X"`) e `manifesto` (`"se X esta declarado"` × `X`). Achado do `qa-reviewer` — as duas instâncias concretas que o item 76 descrevia como hipótese futura | nem a invariante nem o caso de cruzamento alcançam, se algum dia os ramos deixarem de ser exclusivos | Junto do item 76 |
| 84 | **O canal `Resultado` tem asserção em 4 dos 15 pontos de emissão.** O que a nona e a décima fecharam foram os **quatro pontos de "campo ausente"**, não o canal. Mutação que sobrevive hoje, apontada pelo `qa-reviewer`: fixar `doctor-git.ps1:52` em `True` faz o `doctor.json` afirmar `historico legivel = True` num repositório sem commits, **com a suíte inteira verde** | falsidade no contrato de máquina, invisível para a suíte | Antes de a Fase 3/4 consumir `coverage.verificado` |
| 83 | **`raiz` sobre caminho que não é repositório emite lacuna e sai `1`, não `2`.** É legítimo — o fato da própria dimensão está determinado, e a lacuna é sobre as **outras** —, e o `exit 1` é decisão registrada e testada. O que estava errado era o **texto fixo do relatório** e duas afirmações minhas que diziam "a única lacuna do doctor inteiro". Achado do `qa-reviewer`; **texto e afirmações corrigidos na décima; a `SKILL.md` carregava a MESMA afirmação falsa e só foi corrigida na décima primeira** — eu tinha consertado o relatório e esquecido o contrato publicado, que é a forma exata do defeito | direção segura: sai 1, que bloqueia | Fechado **no texto, nos dois lugares**. O comportamento continua como está: uniformizar é decisão de governança. E a prosa do relatório e da `SKILL.md` **não tem detector nenhum** — foi assim que a afirmação falsa sobreviveu uma rodada inteira |
| 82 | **`schema_version` continuou 1 embora o domínio de `resultado` tenha mudado para dois rótulos.** Levantado pelo `security`... na verdade pelo `qa-reviewer` na nona rodada. **Decisão explicita, e não por omissão:** `resultado` **nunca** foi `True|False` — sempre foi string livre, e já carregava caminho absoluto em `raiz do repositorio` e o comando em `verificacao.comando`. O contrato do campo não mudou; o que mudou foi o **valor** em dois rótulos | nenhum consumidor escrito ainda | Subir a versão quando a Fase 3/4 começar a ramificar sobre `resultado` |
| 81 | **Falha de leitura virando fato medido em `retomabilidade`.** Se `rev-list --count` falha, a contagem vira `?` e o achado sai *"entraram ? commit(s)"* — uma leitura que falhou apresentada como contagem. Direção segura (WARN, e o booleano segue correto). Achado do `qa-reviewer`; **texto corrigido na nona rodada** para não afirmar contagem que não houve | afirma medição que não aconteceu, na dimensão que acabou de trocar `True` por `nao se aplica` para não fazer isso | Fechado no texto; o ramo em si continua sem caso |
| 80 | **O caso do HEAD órfão afirma a lacuna pelo RÓTULO, e o ramo vizinho emite o mesmo rótulo.** Uma lacuna vinda de `Test-TemHistorico` lançando satisfaria as três asserções com o ramo alvo intocado. Achado do `qa-reviewer`; **fechado na nona rodada** com asserção sobre o `Porque` | o caso mede menos do que o nome promete | Fechado |
| 79 | **O `collect-diff.ps1` não traz nada sobre os arquivos de `artifacts/review/` que o `STATE` cita.** Se o registro aponta para vereditos como evidência, a existência deles precisa ser afirmada por **detector**, não por prosa — foi o que faltou para o item 78 ser pego antes de chegar ao revisor. Recomendação do `qa-reviewer` | prosa apontando para arquivo ausente, sem ninguém conferir | Complicação real: `artifacts/` é **ignorado**, então o detector não pode exigir existência num clone limpo — tem de conferir **coerência entre as citações** e declarar o salto |
| 78 | **O `STATE` citava `veredito-25-r{1..7}` numa linha e `{1..6}` em outra, e o `r7` não existia no disco.** Achado do `qa-reviewer`; **corrigido na oitava rodada** — os vereditos das rodadas até ali estavam salvos e as duas citações dizem o mesmo | registro apontando para evidência ausente, no parágrafo escrito justamente para dar lastro | Fechado; a classe fica no item 79 |
| 77 | **A guarda local repetia o literal do rótulo, em dois arquivos.** Trocar o texto da lacuna desarmava a guarda **em silêncio** — e foi assim que o ramo do `git log` ficou de fora. Achado do `qa-reviewer`; **corrigido na oitava rodada**: a emissão passou a ser decidida por um **fato do fluxo** (`$mediuTests`, e o ramo que estabelece o fato), não por comparação de string | guarda por string tem a mesma fragilidade do defeito que ela conserta | Fechado nas duas dimensões que emitem os dois canais |
| 76 | **A invariante de `New-DimensaoDoDoctor` compara `O_que` por igualdade de string.** Ela alcança quem escrever o rótulo **idêntico**; dimensões cujos rótulos diferem por uma palavra ficam fora. **A justificativa que eu escrevi aqui — "os ramos são mutuamente exclusivos" — era factualmente falsa**, e o `qa-reviewer` a derrubou na nona rodada: em `frescor` a verificação saía para **todo** artefato, fora do `switch`, e o ramo `invalido` emitia lacuna sobre o mesmo artefato com outro rótulo. A condição de disparo que eu reservei para o futuro **já estava no disco**. `frescor` e `ambiente` foram corrigidos na nona; a limitação da invariante (compara string) permanece | cobre menos do que a frase promete | Quando alguma dimensão nova emitir os dois canais sobre o mesmo fato com rótulos diferentes |
| 75 | **A ordem das regras no `.gitignore` do template é narrada em comentário, não verificada.** A negação `!/examples/**` (linha 39-40) reabre, dentro de `examples/`, tudo que só é ignorado por regras **anteriores** a ela. O bloco de segredos vem depois e vence — hoje. Achado do `security-reviewer`, com o conserto: asserção de **posição** (índice da primeira negação `!/examples` < índice de toda regra de credencial) | qualquer regra nova de segredo escrita **acima** da linha 39 nasce sem efeito dentro de `examples/`, em silêncio | Junto do item 59 — transformar o comentário em guarda-corpo |
| 74 | **O canal `Verificacoes` não tinha nenhuma asserção de CONTEÚDO na suíte** — só existência da chave `coverage`. Por isso a contradição entre os dois canais não podia ser pega por teste nenhum. Achado do `qa-reviewer`. **Eu registrei "fechado na sétima rodada" e era falso:** a sétima fechou colisão de **rótulo**, no construtor; asserção de **conteúdo** (`Resultado`) continuou sem existir até a nona, e por isso a correção da oitava podia ser revertida com a suíte verde. Fechado **na nona** para os **quatro pontos de "campo ausente"** — **não o canal inteiro**, que tem asserção em 4 de 15 pontos de emissão (item 84). O `qa-reviewer` pediu essa delimitação na décima rodada | um lado do contrato `coverage` era medido, o outro não | Fechado. Fica registrado porque a classe "canal sem asserção de conteúdo" pode reaparecer em campo novo |
| 73 | **O guarda de placeholder de `Get-CampoDoProjeto` só alcança ESCALAR.** Item dentro de lista — `ambiente.dependencias` — retorna antes dele, então uma entrada com `{{FERRAMENTA}}` dentro não seria detectada. Sem efeito hoje. Achado do `qa-reviewer` | fail-open estreito, no único campo de lista que o doctor lê | Se o template passar a publicar placeholder dentro de `dependencias` |
| 72 | **Não há antes/depois para os 7 arquivos não rastreados.** Eles são `??` no `git status`, então o `git diff` do coletor entrega **conteúdo**, não delta: o revisor julga o estado final e não consegue confirmar por evidência o que mudou entre rodadas. Ressalva de método do `qa-reviewer` | nenhuma verificação "por diff" é possível sobre a biblioteca do doctor até o primeiro commit | Some sozinho no commit da 2.5; volta em toda subfase que criar arquivo novo |
| 71 | **`exit 2` significa duas coisas**, e a delta tornou a segunda rotineira: "a ferramenta não rodou" e "rodou e não conseguiu verificar parte". Achado do `security-reviewer` | sem consequência hoje | **Vira `MEDIA` quando a Fase 3/4 ramificar sobre o código de saída ou sobre `doctor.json`** — mesma condição do item 56 |
| 70 | **O par negativo do caso da lacuna mede só a emissão, não o status.** Se a regra de dominação passasse a disparar por outra condição, o par não pegaria. Achado do `qa-reviewer` | teste mais fraco do que parece | Quando a dimensão ganhar outra fonte de lacuna |
| 69 | **Booleano do YAML 1.1 — `yes`/`no`/`on`/`off` — em `verificacao.tests` passa a produzir lacuna e `exit 2`.** O gêmeo também guarda string, então **não há divergência entre leitores**: é política da dimensão. Achado do `qa-reviewer` | **fail-closed** e nomeada — a direção certa | Se algum manifesto governado usar essa forma |
| 68 | **A guarda de destino pulada não emite lacuna — some em silêncio.** Com `-Path` relativo, que é o **default** dos dois coletores, a pergunta "meu destino está ignorado?" simplesmente não é feita, e nenhum dos dois relatórios diz que deixou de fazê-la. Contestação de cobertura do `security-reviewer` | é o **mesmo padrão** que esta subfase consertou no leitor: "não verifiquei" sumindo em silêncio, contra a política 4.5 | **Junto do item 63**: quando a guarda for pulada, emitir lacuna nomeada |
| 67 | **Nenhum caso exercitava o ramo do placeholder de instanciação, em dimensão nenhuma** — `grep` por `{{` em `tests/suites/doctor.ps1` dava zero. Foi o que deixou o fail-open atravessar cinco rodadas. Achado do `qa-reviewer`; **fechado na sexta** para a dimensão manifesto | as outras dimensões continuam sem caso para esse estado | Antes de qualquer dimensão nova que leia campo do manifesto |
| 66 | **A delta acrescentou o nome do perfil Windows da mantenedora em comentário de código**, em três arquivos. Identidade da própria autora (`BAIXA` por ADR-0009) e nenhum detector a enxerga. Achado do `security-reviewer` | a superfície de sanitização manual cresceu, e `portfolio.elegivel` é `true` | Antes de qualquer publicação — junto do item 9 |
| 65 | **`ambiente.dependencias[].para` e `[].ferramenta` viajam VERBATIM para o artefato.** São prosa livre do manifesto, e num projeto governado corporativo `para:` é exatamente onde se escreve o nome do sistema do cliente — categoria que nenhum detector representa. Achado do `security-reviewer` | inócuo aqui; expõe nome de cliente lá | **Mesma condição do item 56** |
| 64 | **`Get-Command $Nome` trata o nome como CURINGA.** `ferramenta: "git*"` devolve comando e a dimensão reporta "encontrada no PATH" sem existir ferramenta com aquele nome. Pré-existente, não introduzido pela delta. Achado do `security-reviewer` | **falsa garantia barata** — diz que tem o que não tem | Conserto: `-Name` com `-TotalCount 1` e recusa explícita de curinga |
| 63 | **A guarda de destino também fica desarmada quando `-Path` é RELATIVO** — e foi assim que eu invoquei o `collect-diff.ps1`. `StartsWith` entre `.` e um `-Out` absoluto dá falso, o `check-ignore` não roda, e o relatório afirma sobre si mesmo que está fora do repositório-alvo — estando dentro. `MEDIA` do `security-reviewer`, construto idêntico em `collect-diff.ps1:115` e `security-scan.ps1:130` | **fail-open com garantia falsa escrita no artefato** | **Junto do item 43** — normalizar com `GetFullPath` nos dois gêmeos, e caso que mede `-Path .` com `-Out` absoluto |
| 62 | **O meu script de mutação relatou `SOBREVIVEU` para duas mutações que, aplicadas à mão, matam o caso.** Vive no scratchpad (item 31), e erra para o lado do **falso alarme** — me fez olhar, e a prova saiu correta pela mão. Ainda assim: a ferramenta que existe para provar detecção não é confiável, e é a segunda vez nesta plataforma que o instrumento de mutação mente — a primeira foi o `Write-Host` indo para o fluxo 6 e o `>` não capturando | seguro desta vez; a direção oposta seria falso verde | **Junto do item 31**, quando o script sair do scratchpad |
| 61 | **Nada compara mais os ACESSORES.** A paridade virou leitor-contra-leitor, o que é certo para a afirmação do cabeçalho — mas `Get-CampoDoProjeto` e o acessor do gêmeo têm contratos deliberadamente diferentes, e agora ninguém mede isso. Observação do `qa-reviewer` | divergência de acessor passa despercebida | Quando algum consumidor depender dos dois |
| 60 | **A aspa dobrada foi medida doctor × gêmeo PowerShell, e só LIDA contra o gêmeo Python.** O `security-reviewer` conferiu `_sem_aspas` no `conftest.py` por leitura e os três concordam — mas leitura não é execução. Recomendação dele | terceiro leitor sem medição nesta forma | Acrescentar a forma às entradas do caso PS × Python |
| 59 | **A cobertura de segredo dentro de `examples/` repousa em ORDEM DE REGRA lida, não em medição.** O `security-reviewer` fechou a lacuna inferindo que o bloco de credenciais vem depois das negações — e declarou a inferiência. Existe caso equivalente só para binário de Office | a aprovação de uma área inteira depende de leitura, não de `git check-ignore` | Caso que pergunte por `examples/fixtures/x.pem` e `examples/id_rsa` |
| 58 | **`StartsWith('>')` contra o `Test-IndicadorDeBlocoYaml` estrito do gêmeo.** `criterio: >= 90` vira `NaoLegivel` no doctor e string no gêmeo, e o doctor passa a engolir toda linha mais indentada. YAML inválido dos dois lados. Achado do `qa-reviewer` | **fail-closed** no doctor | Quando o gêmeo endureceu essa regex foi porque `|2` escapava — copiar a dele |
| 57 | **`IndexOf` acha a primeira aspa REPETIDA, não a que fecha.** Com aspa dobrada mais comentário alinhado — `criterio: 'diz ''pronto'''   # meta` — o comentário não é cortado e o par não sai. Os **dois** leitores erram igual: teto compartilhado, não divergência. O `qa-reviewer` cobrou a **afirmação** do comentário, que era mais larga que o código — já estreitada | valor sai com comentário colado | Junto do item 42, se o manifesto deixar de ser subconjunto de YAML |
| 56 | **O doctor não pergunta se o destino do artefato está ignorado, e grava a raiz ABSOLUTA dentro dele.** O `security-scan.ps1` tem caso próprio para essa pergunta; `doctor-comum.ps1` não tem nenhum `check-ignore`. Achado do `security-reviewer` | hoje inócuo — o destino padrão está ignorado nos dois `.gitignore`. **Compõe com o teto "estrutura de diretório interna, que nenhum detector representa"** | **Condição dele para promover a `MEDIA`:** quando `doctor.json` virar contrato consumido, ou um projeto governado tiver `artifacts/` rastreado |
| 55 | **Comentário SEM espaço antes do `#` depois da aspa que fecha agora sobrevive INTEIRO dentro do valor.** `comando: "x.ps1"# nota interna` — antes era descartado junto com o miolo; agora viaja verbatim para `doctor-report.md` e `doctor.json`, sem o truncamento de 40 caracteres, que só vale para mensagem de erro. Achado do `security-reviewer` | sem exposição nova — é conteúdo do próprio `project.yaml`, rastreado e já varrido, para destino ignorado. Mas **alarga o que o doctor transcreve**, contra a própria documentação dele | Junto do item 52. **A outra face, contestada pelo `security-reviewer` na rodada 5, JÁ FOI tratada:** o mesmo comentário colado fazia `DeclaraTests` virar falso e a única regra `FAIL` da dimensão não disparar, **em silêncio**. Medido: os dois leitores devolvem o mesmo e os **dois estão certos** — em YAML um `#` sem espaço antes não abre comentário. Não era divergência nem fail-open do leitor; era a dimensão calar sobre valor que não reconheceu. Agora vira lacuna, e lacuna **domina** o status |
| 54 | **No template, `!/examples/fixtures/**/*.csv` e `!/examples/synthetic/**/*.csv` reabrem CSV, e o guarda-corpo é o NOME do diretório.** Decisão documentada da mantenedora; registrada porque é o único ponto onde dado pessoal em formato de texto entra versionado por default. Observação do `security-reviewer` | guarda-corpo **social**, não técnico | Se algum projeto governado começar a pôr CSV real ali |
| 53 | **Eu invoquei os revisores com o código de saída dentro do pedido** — *"Termine com `QA_EXIT=0`"*. Isso entrega ao revisor a resposta junto com a pergunta. O `security-reviewer` nomeou o problema e registrou que decidiu por conta própria. Defeito **meu**, de método, não do código | contamina a independência que o ADR-0007 existe para garantir | **Já**: nenhuma invocação futura de revisor pode conter o código de saída esperado |
| 52 | **O truncamento em 40 caracteres da mensagem do `throw` ainda transcreve VALOR num formato de linha.** Continuação de escalar simples multi-linha não tem `:`, cai no ramo que lança, e os 40 caracteres transcritos são valor, não chave. Achado do `security-reviewer` | limite bem definido: 40 caracteres de uma linha, para dentro de `artifacts/`, que aqui é ignorado | Compõe com o 47 — em repositório de terceiro o destino muda |
| 51 | **O leitor não detecta chave duplicada, e a regex mais frouxa aumentou a chance de colisão.** `"chave"` e `chave` normalizam para a mesma, e `$pai[$chave] = ...` sobrescreve em silêncio: **o último vence**. Achado do `security-reviewer` | sem superfície de execução — não há `Invoke-Expression`, e `verificacao.comando` só é impresso | **Vira `MEDIA` no dia em que algo derivar rigor de `classificacao.criticidade` lido por este leitor** |
| 50 | **O conserto do `try/catch` foi pontual, a estrutura não.** `scripts/doctor.ps1` chama as seis dimensões sem guarda própria: exceção não tratada em qualquer uma reabre o buraco "exit 2 sem gravar relatório nem JSON". Sem entrada concreta hoje. Observação do `qa-reviewer` | o padrão foi corrigido **numa cópia** — a mesma lição, um nível acima | **GATILHO DISPARADO e REAVALIADO em 2026-10-01:** a 2.6 acrescentou a dimensão `hooks` sem tratar o item, e o `qa-reviewer` cobrou. Reavaliado: continua **sem entrada concreta**, a direção continua *fail-closed* (o `trap` global sai `2`, que é "não rodou"), e a dimensão nova tem a mesma estrutura das outras — `Get-EstadoDosHooks` devolve em vez de lançar. Segue aberto, agora junto do item 104 |
| 49 | **A decisão "é `chave: valor`" acontece antes de saber de aspas.** `- "SharePoint: pasta do cliente"` — escalar citado legítimo, e `SharePoint` é o exemplo que o próprio template sugere — casa a chave `"SharePoint` e o item vira **mapa**. Achado do `qa-reviewer` | fail-closed pela razão errada: cairia em `NaoSondadas` → `INCONCLUSIVO`. Sem efeito hoje — o doctor não lê `dependencias_externas` | Se `ambiente.dependencias` ganhar escalar citado com `:` |
| 48 | **A lista de NOMES de skills no `STATE.md` não tem detector — só a contagem tem.** Um nome errado, ou uma skill nova fora da enumeração com a contagem certa, passa verde | registro envelhece em silêncio, no arquivo que quem chega lê primeiro | Quando a próxima skill entrar |
| 47 | **O doctor pode gravar `artifacts/doctor/` dentro de repositório de TERCEIRO.** Com a raiz `indeterminada`, o destino é o `-Path` perguntado, e o artefato contém os caminhos absolutos dos **dois** diretórios Git. Se o alvo não ignora `artifacts/`, o arquivo é rastreável. Achado do `security-reviewer` | expõe caminho, não segredo | Junto do item 43 — reusar ali a pergunta "o destino está ignorado?" |
| 46 | **`skills/doctor/SKILL.md` documenta só o `exit 2`.** O `1` de `FAIL` e o `1` de "fora de repositório" — que é resposta diferente do `2` de *bare*, e é o ponto do desenho — só existem no CHANGELOG. Achado do `qa-reviewer` | documentação incompleta; o código está certo | Quando a SKILL.md for revista |
| 45 | **O frescor não distingue "do `HEAD`" de "descreve o disco".** `Get-EstadoDoArtefato` compara só o carimbo de `HEAD`; com trabalho não commitado a evidência sai `do-head` e a dimensão sai `PASS`. O agregado não mente, porque a dimensão `git` dá `WARN` — mas a linha lida **isolada** no `doctor.json`, que é o contrato de máquina da Fase 3/4, afirma frescor sobre código que a evidência não cobre. Achado do `qa-reviewer` | otimista **dentro da dimensão**, corrigido pela agregação | Antes de a Fase 3/4 consumir `dimensions[].status` isoladamente |
| 44 | **A guarda de raiz não representa `GIT_COMMON_DIR` nem `GIT_INDEX_FILE`, e compara caminho como STRING.** `--absolute-git-dir` continua devolvendo `B/.git` enquanto refs resolvem contra o commondir do ambiente; e `GetFullPath` não expande 8.3 nem resolve junction/symlink — em worktree sob `%TEMP%` os dois lados podem divergir **por forma, não por repositório**, e sair `indeterminada`. Achado do `security-reviewer`, derivado por leitura, não executado | erra **alto**: desliga o doctor no cenário de worktree que a Fase 3 planeja | Antes de a Fase 3 usar worktrees |
| 43 | **A guarda que impede o relatório de segurança de ser commitado é pulada, e o relatório afirma que a pergunta "não se aplica".** `security-scan.ps1:128-141` compara `$Out.StartsWith($raizComSep)` como string crua, sem normalizar: com `-Out` relativo, forma 8.3 ou unidade mapeada, o `git check-ignore` **não roda** e a seção *Escopo NÃO VARRIDO* declara que o relatório está fora do repositório-alvo — e ele está dentro. **Falsa garantia**, na seção de que todo veredito de segurança depende. `MEDIA` do `security-reviewer`; **fora da delta da 2.5**, e sem exposição aqui porque `/artifacts/*` cobre | afirma verificado o que não verificou | **Condição nomeada do `security-reviewer`:** antes de apontar o `security-scan.ps1` para projeto governado ou repositório de terceiro |
| 42 | **O manifesto lido pelo doctor é um SUBCONJUNTO de YAML, e isso não está no contrato.** Lançam: `---` e `...`, continuação de escalar simples multi-linha (**o `yaml.dump` do Python quebra em ~80 colunas — qualquer `justificativa:` longa reescrita por ferramenta cai aqui**), coleção em fluxo quebrada em linhas, âncora/alias e o merge `<<: *base`. Achado do `security-reviewer`, confirmado pelo `qa-reviewer` | **fail-closed**. Teto compartilhado no **fato** — nenhum dos dois entende esses construtos —, mas **não no raio**, e o `qa-reviewer` cobrou a imprecição: em lista aninhada dentro de item, o doctor **lança e perde o manifesto inteiro**, enquanto o gêmeo pula e perde só a chave da lista | Quando um manifesto legítimo cair nisto. Declarar no contrato e fixar os construtos na suíte |
| 41 | **O artefato do doctor concentra a categoria que nenhum detector representa.** O relatório e o `doctor.json` gravam o caminho **absoluto** da raiz — que nesta máquina carrega o nome da mantenedora no perfil —, `identidade.nome`, `criticidade`, `verificacao.comando` e o texto `para:` de cada dependência. O teto permanente do scanner diz que estrutura de diretório, nome de projeto e nome de cliente **não são representados por detector nenhum**. Achado do `security-reviewer` | contenção existe (`/artifacts/*` na raiz **e** no template) e some se o artefato for anexado a handoff, colado num chat ou movido para fora de `artifacts/` | Antes de o `/os:handoff` passar a anexar artefato de diagnóstico |
| 40 | **`ambiente.dependencias` e `ambiente.dependencias_externas` descrevem o mesmo fato em formatos diferentes.** Decisão da mantenedora em 2026-09-18: o primeiro é a fonte estruturada que o Doctor lê; o segundo fica como campo narrativo **legado**, sem sincronização automática nesta subfase | dois registros do mesmo fato divergem com o tempo, e o Doctor cobra só um | Quando houver migração de schema. **Não** ampliar a 2.5 para isso |
| 39 | **`Get-RaizDoRepositorio` classifica o diretório `.git` de um repositório normal como `bare`.** `-Path .git` devolve exit 2 "forma não suportada" em vez da raiz. Está declarado no comentário do ramo. Achado do `qa-reviewer` | erra alto: recusa em vez de diagnosticar o lugar errado | Se alguém rodar o doctor apontando para o `.git`. Hoje ninguém faz |
| 38 | **O caso que prova a cobertura do doctor roda sobre UMA fixture saudável.** Chave de cobertura que só exista em ramo não visitado por ela não seria vista. Hoje não ocorre, porque cada dimensão monta `$cob` inteiro no topo — propriedade que **ninguém verifica** e que a próxima pessoa pode quebrar. Ressalva do `qa-reviewer` ao aceitar o ponto 9 | cobertura não medida onde o ramo não é visitado | Quando uma dimensão passar a montar `$cob` por partes |
| 37 | **Nenhum limite de tamanho no working tree.** O histórico tem `-MaxBlobKB`; a leitura de arquivo do disco não tem nada. `ReadAllBytes` carrega o arquivo inteiro em memória, e `.csv`, `.tsv`, `.sql` e `.xml` estão na lista de extensões de texto — os formatos que ficam grandes em projeto governado com dado real. A direção é segura (`ReadAllBytes` lança, o leitor devolve `$null`, o arquivo vira lacuna), mas o **rótulo** é errado: diria "ilegível como texto" onde a causa foi tamanho. Recomendação do `security-reviewer` | rótulo errado manda quem for consertar ao lugar errado | Antes de a plataforma governar projeto com dado real grande. `-MaxArquivoKB` simétrico ao `-MaxBlobKB`, com lacuna própria |
| 36 | **Arquivo que começa com `FF FE` sem ser UTF-16** é decodificado como UTF-16 e, se não gerar `NUL` nem comprimento ímpar, passa com texto errado. A linha de teto fala de "texto de byte único", não desse caso. Achado residual do `qa-reviewer` ao conferir as bordas do preâmbulo | texto errado sem recusa, muito estreito | Junto do item 34, se alguém encontrar o caso na prática. É rebuscado |
| 35 | **O `bootstrap.ps1` do template lê o `project.yaml` com `[Text.Encoding]::UTF8` leniente** — `templates/project-standard/bootstrap.ps1`. Ele decide se o projeto declara `tests: true`, e é o arquivo que viaja para **todo** projeto governado. Achado do `qa-reviewer` ao conferir uma frase minha do item 11 que era mais larga que o fato | manifesto corrompido rebaixa BLOQUEIA para aviso, em silêncio | Quando a 2.5 tocar o template, ou antes se algum projeto governado gravar manifesto em ANSI |
| 34 | **RESOLVIDO em 2026-10-12 (`5a568b5`, revisão r8 S6): o detector lê os bytes e decodifica em UTF-8 estrito.** Texto original: **A recusa do detector de histórico é por sinal INDIRETO.** As outras cinco áreas recusam sobre os **bytes**; o histórico recusa `NUL` e `U+FFFD` no texto que o console já decodificou, então blob com `U+FFFD` legítimo é recusado junto (erra alto) e byte inválido mapeado para outra coisa passa. Declarado na tabela de teto permanente do relatório, que é onde o revisor lê | mais fraca que as outras cinco, e declarada | Quando valer a pena ler o blob como **bytes** — `cat-file --batch` com leitura binária. Não antes: o custo é um processo por blob |
| 32 | **O `finally` do caso novo perde a mensagem da guarda.** Com `$origem` vazio, a guarda lança com o texto explicativo e o `finally` executa `Remove-Item` com string vazia — falha de *binding* que `-ErrorAction SilentlyContinue` não suprime, e exceção levantada em `finally` **substitui** a que estava propagando. O caso segue vermelho; quem lê vê o erro errado | direção certa, mensagem errada | Duplamente inalcançável hoje. Junto de qualquer mexida naquele caso |
| 33 | **O `throw` de pré-condição do caso novo é ramo-guarda sem par de execução** — a classe que os itens 8, 18 e 26 registram. O `qa-reviewer` levantou e aceitou o contra-argumento: aqueles são guardas em detector de produção, este é pré-condição dentro de um caso de teste | **lança** — erra alto | **Decisão sua:** a regra de par negativo se estende a pré-condição de teste, ou vale só para código de produção? |
| 31 | **A prova por mutação não é reproduzível pelo repositório.** O script que aplica a mutação, roda a suíte, restaura e confere por SHA-256 vive no scratchpad da sessão. Três rodadas já citaram mutação executada como evidência central, e nenhuma delas é conferível por quem ler o repositório depois | a afirmação sobrevive, a evidência não | Quando a mutação virar prática recorrente o bastante para merecer ferramenta versionada — ou quando alguém precisar reproduzir uma prova antiga |
| 29 | **O terceiro consumidor — `security-scan.ps1` — não tem par de execução para a troca de predicado.** Mutá-lo de `Test-HeadResolvivel` para `Test-TemHistorico` mantém a suíte verde: os dois só divergem no estado *fetch-only*, e nenhum caso roda o scanner completo nesse estado. O mesmo teto vale para a quarta cópia, em `collect-diff.ps1` | **erra alto**, mas pelo motivo errado: o scanner sairia com `2` sem relatório em todo repositório com `fetch` e `HEAD` não nascido | Quando houver razão para mexer nesses pontos. A asserção certa é *o scanner completo chega ao relatório, com `HEAD: (sem commits)`* — não sai com 2 |
| 30 | **A escolha `ComumDir` em `scan-exposicao.ps1` não tem par de execução.** Mutá-la para `GitDir` é inerte porque `Get-CaminhosDoGit` devolve `GitDir` e `ComumDir` com o **mesmo valor** fora de worktree ligado: só **worktree sem remoto** discrimina. *(A primeira versão deste item dizia que nenhum caso entra naquele bloco, porque as fixtures declarariam remoto. É falso e conferível: `collectors.ps1` usa uma fixture que nunca chama `git remote add`, então o bloco **é** alcançado. Quem fosse fechar este item pela receita errada procuraria "repositório sem remoto", que já existe e não prova nada. Achado do `qa-reviewer`.)* O item 26 cobre os dois `throw` da guarda, **não** esta escolha: fechar o 26 com fixture de repositório comum deixaria esta linha órfã | guarda `ALTA` inerte em silêncio | **FECHADO em 2026-09-17**, junto do 26, com a fixture de worktree ligado |
| 26 | **A guarda de sanidade do *fallback* de remoto vazio não tem par de execução, em nenhum dos dois ramos.** Nem o `throw` pré-existente (`config` declara `[remote]` e `remote -v` vem vazio) nem o `throw` novo (`Get-CaminhosDoGit` nulo). `Grep` por `[remote` em `tests/`: zero. **A detecção de remoto público em si tem quatro casos** — a manchete anterior deste item dizia o contrário e era mais larga que o fato | **lança** — erra alto | **FECHADO em 2026-09-17** — quatro ramos, quatro pares de execução. Ver a seção abaixo |
| 27 | **`Get-CaminhosDoGit` não consulta `config.worktree`.** Com `extensions.worktreeConfig=true`, remoto declarado só no config por-worktree não seria visto pelo *fallback* | `fail-open` num caminho muito estreito | Inalcançável hoje porque o git leria esse config — **exceto justamente quando quem falhou foi o git**, que é a razão de o *fallback* existir. A justificativa anterior deste item dizia "impacto ≈ nulo" pela razão errada, e o `security-reviewer` corrigiu |
| 18 | **A guarda `refs > 0` de `Test-TemHistorico` não tem par de execução.** `rev-list --all` falha antes de devolver vazio em toda fixture que tentei | **lança** — segunda linha de defesa, erra alto | Se alguém achar o estado que a alcança |
| 20 | **`Get-IdentidadesDoRepositorio` trata autor de `refs/remotes/*` como identidade do próprio repositório** (→ `BAIXA`). Num projeto clonado de remoto corporativo, todo colaborador vira `BAIXA` em vez de `MEDIA` "e-mail de terceiro" | enfraquece na área de dado pessoal | Antes de a plataforma governar projeto clonado de remoto compartilhado |
| 21 | **`Get-CaminhosDoGit` assume que `$Path` é a RAIZ do repositório.** *(E, onde estes itens dizem "worktree", leia **`.git` como arquivo**: worktree ligado, submódulo e `--separate-git-dir`. O `security-reviewer` apontou que a última se aplica ao repositório **principal** — é como se tira o `.git` de pasta sincronizada, cenário real nesta casa pelo ADR-0002 —, o que torna esta família de defeitos mais larga que a moldura "worktree".)* Não sobe diretórios nem usa `git rev-parse --git-dir`. O ramo positivo funciona de subdiretório porque o git sobe sozinho; todo ramo negativo lança | `exit 2` com diagnóstico errado | **A 2.5** — o `/os:doctor` é justamente o consumidor que remove a proteção da guarda de entrada do scanner |
| 22 | **`rev-list --all` não vê objeto alcançável só por `FETCH_HEAD`/`ORIG_HEAD`, nem objeto solto** | não varre, e declara vazio | Teto a declarar no relatório |
| 23 | **A linha de cobertura do histórico não distingue ref local de `refs/remotes/*`.** Em repo *fetch-only* o que se varre é conteúdo que o remoto já tem: achado real, disposição diferente | relatório impreciso | Junto do 22 |
| 25 | **A forma "repositório *bare*" não está coberta pelo item 21.** Em *bare* não há `.git` nem como diretório nem como arquivo: `Get-CaminhosDoGit` devolve `$null` e os dois predicados lançam, onde o predicado antigo devolvia falso. O item 21 registra a forma **subdiretório**, não esta | **lança** — erra alto | Junto do 21, na 2.5. *Bare* não é forma de projeto governado |
| 24 | **Casos sem par:** `HEAD` ausente e `ReadAllText` lançando não têm caso; o caso 5 é quase redundante com o 1 | não detecta regressão | Com o item 14 |

### Item 28 fechado **em parte** — e o caso passou pela razão errada até a mutação mostrar

O item 28 era o que a mantenedora mandou fechar antes da 2.5. **Não era o único marcado "antes da 2.5"** — restavam o item 26, que é justamente a guarda que impede um remoto **público** passar sem achado `ALTA` e cuja manchete dizia que nada provava que ela funciona; o item 30, cujo "quando" era *junto do 26* e portanto herdava a marca; e o item 11 do backlog da 2.4, que pedia corrigir a leitura `UTF8` dos detectores **ou declará-la como teto**. **Os três foram fechados em 2026-09-17** — ver a seção logo abaixo. Esta frase fica como está, no passado, porque ela é o registro de um erro de leitura do próprio backlog e apagá-la apagaria a lição. **E não era o único cuja direção é falso verde:** o item 27 declara `fail-open`, o 22 "não varre e declara vazio", o 20 "enfraquece na área de dado pessoal".

*(A primeira versão desta frase afirmava as duas coisas, e o `qa-reviewer` as derrubou contra a tabela doze linhas acima, no mesmo arquivo. Quem lesse concluiria que a 2.5 abre com tudo fechado, e abriria com o item 26 em pé. É a forma que este repositório já reprovou antes — afirmação falsa no registro é pior que lacuna assumida.)*

**A lacuna:** os predicados estavam bem cobertos, mas **qual detector faz qual pergunta** não estava pinado por teste nenhum. Reverter `scan-historico.ps1` ou `scan-dado-pessoal.ps1` para `Test-HeadResolvivel` mantinha tudo verde — e faria o detector voltar a declarar `SemCommits`, que é afirmação **positiva** de cobertura, sobre um repositório com histórico buscado por `fetch` e blobs no banco.

O caso novo usa o mesmo estado divergente: `git init` + `remote add` + `fetch`, sem `HEAD` local. Ele afirma três coisas, porque a lacuna tinha três consequências — `Cobertura.SemCommits -eq $false`; `Cobertura.Commits -gt 0`, senão "não está vazio" passaria com zero commits varridos; e que a identidade do autor do commit buscado **é lida**, porque se `scan-dado-pessoal` perguntasse pelo `HEAD` a lista voltaria vazia e **todo e-mail do repositório viraria "de terceiro"**.

#### Três camadas de falso verde, e cada uma só apareceu porque a de baixo foi executada

O caso passou de primeira. A mutação mostrou que **passava pela razão errada**: `Get-IdentidadesDoRepositorio` lê também `git config --get-all user.email`, e a fixture configurava o mesmo e-mail no clone. A identidade vinha do *config*, não do histórico — então reverter o detector não derrubava a asserção, e a mutação de `scan-dado-pessoal` **sobreviveu**.

A fixture passou a isolar: a origem assina com um endereço e o clone configura outro, então o e-mail do autor **só pode** vir de `log --all`. Entrou junto a asserção do par — a identidade local continua sendo lida —, para que o conserto não quebre o outro caminho em silêncio.

**E o script de mutação tinha o mesmo vício.** A linha final dizia *"nenhum SOBREVIVEU"* de forma **incondicional**: a ferramenta construída para detectar falso verde tinha um falso verde no resumo. A saída trazia `SOBREVIVEU` em vermelho três linhas acima, e o resumo afirmava o contrário — que é exatamente como este tipo de erro sobrevive a uma leitura apressada. Corrigido para contar e falhar.

#### Duas ressalvas que o `qa-reviewer` levantou e que ficam registradas

**O item 28 foi fechado pela metade, e o registro agora diz isso.** A linha que ele ocupava nomeava **quatro** pontos de mutação; o caso novo fecha **dois**. Os outros dois — o terceiro consumidor, em `security-scan.ps1`, e a escolha `ComumDir` — voltaram à tabela como itens 29 e 30, nominalmente. Apagar a linha inteira declarando "fechado" foi alegação mais larga que a evidência.

**A asserção da identidade pina como exigido o que o item 20 quer mudar.** Ela exige que o autor de um commit alcançável só por `refs/remotes/*` apareça como identidade *do próprio repositório* — e o item 20 registra exatamente isso como defeito a corrigir, porque num projeto clonado de remoto corporativo todo colaborador viraria `BAIXA` em vez de `MEDIA`. Hoje código e teste concordam; quando o item 20 for fechado, **este caso vai ficar vermelho e a mensagem dele vai argumentar contra a correção**. Fica escrito aqui para que quem mexer no 20 saiba que precisa mexer neste caso junto.

**A prova por mutação não está versionada.** O script que executou as duas mutações vive no scratchpad da sessão, não no repositório: a lição sobreviveu, a ferramenta e a saída não. O `qa-reviewer` refez as duas mutações **por leitura** e confirmou que as duas matam o caso — evidência de tipo diferente, suficiente para a discriminação lógica e insuficiente para afirmar que rodou. Contraria o princípio do `CLAUDE.md` de que nada crítico exista só na conversa, e está no backlog como item 31.

**O que isto acrescenta à classe:** ferramenta de verificação é código, e **resumo que não deriva do resultado é afirmação, não medição**. Vale para o script de mutação tanto quanto valeu para a coluna `Coberta` do relatório e para o acumulador de lacunas — é a mesma forma, pela terceira vez, agora no ferramental.

## Subfase 2.6 — hooks de Git. **Concluída em 2026-10-02**, após oito rodadas de revisão

Guarda-corpos **locais** que barram erro previsível antes de ele entrar no histórico ou sair para o remoto. Eles **orquestram** o que já existe — `security-scan.ps1`, `doctor.ps1`, o `verificacao.comando` do manifesto — e não implementam verificação própria: detector novo aqui seria dois detectores divergindo em silêncio, que esta plataforma já pagou mais de uma vez.

### O mecanismo, e por que ele não copia nada

`core.hooksPath` apontando para a pasta **versionada** `githooks/`. Não há cópia para `.git/hooks`, e isso é desenho, não economia:

- `.git/` **não viaja num clone**. Hook que mora lá depende de alguém lembrar de recriá-lo — é o "arquivo manual escondido" que o contrato de portabilidade não aceita;
- **cópia diverge da origem.** Sem cópia, o que roda **é** o arquivo versionado que a revisão leu.

O valor gravado é **relativo** (`githooks`), e o que ainda pode divergir — o shim ficar para trás da versão que o código espera — **tem detector**: cada shim carrega `# os-hooks-versao: N`, e a dimensão `hooks` do doctor acusa quando não bate. É a lição da 2.5 aplicada de saída: afirmação de versão sem detector não é afirmação, é prosa.

**Quatro fatos medidos nesta máquina, não supostos**, antes de qualquer linha de implementação — sonda executada em repositório descartável:

| O que se queria saber | O que a sonda devolveu |
|---|---|
| `core.hooksPath` relativo funciona? | **Sim**, e resolve contra o topo da working tree. Disparou idêntico da raiz e de um subdiretório |
| qual o diretório corrente do hook? | o **topo** da working tree |
| `GIT_DIR` vem preenchida? | **Não** neste Git for Windows, no `commit-msg`. O `STATE` afirmava que *"todo hook do Git roda com `GIT_DIR`"* — verdadeiro para alguns hooks, e não para este. Nada aqui depende dela: a raiz sai de `Get-RaizDoRepositorio`, que trata as duas situações |
| caminho com espaço (OneDrive)? | funciona, com aspas em toda expansão do shim |

### Os três hooks

| Hook | O que barra | Custo medido |
|---|---|---|
| `commit-msg` | mensagem estruturalmente inválida | instantâneo |
| `pre-commit` | segredo entrando no working tree — `security-scan.ps1 -SemHistorico -SemRede` | **8,2 s**, 93 arquivos |
| `pre-push` | o que o **manifesto** declarar: `doctor` (2 s), `security` completo, `tests` | conforme a política |

**`commit-msg` — três regras, todas estruturais.** Assunto não vazio; **se existir linha 2, ela tem de ser vazia**; assunto até 100 caracteres. Convenção estilística **não entra**: bloquear gosto transforma o hook em coisa que se contorna por hábito, e hook contornado por hábito não protege nada.

> A regra da linha 2 vem de um defeito **desta casa, de cinco dias atrás**: o commit de fechamento da 2.5 foi criado sem a linha em branco separadora, e o assunto engoliu o primeiro parágrafo inteiro do corpo — 350 caracteres numa linha que `git log --oneline` trunca. O conteúdo estava certo; a estrutura, não. A correção custou um `--amend` autorizado caso a caso. **O caso de teste usa a mensagem que produziu `f6e3d5b` — um trecho dela, com a estrutura intacta — e a corrigida que virou `75cc1b4` como par positivo.** *(A primeira redação dizia "a mensagem exata"; o `qa-reviewer` conferiu e a fixture carrega ~228 caracteres do primeiro parágrafo, não os 350. O caso mede a REGRA, e não o texto — e era só a palavra "exata" que era mais larga que a evidência.)*

O limite de 100 existe porque a regra da linha 2 **não alcança** a mesma frase escrita numa linha só, sem corpo. É generoso de propósito — a convenção do Git recomenda 50 — justamente para não virar regra de estilo. Não bloqueiam: comentários que o próprio git injeta, o diff do `--verbose`, e `fixup!`/`squash!`/`amend!`, que o `rebase --autosquash` exige numa linha.

**`pre-commit` escreve em `artifacts/hooks/`, nunca em `artifacts/review/`.** Não é organização: `artifacts/review/security-report.md` é a **evidência das revisões independentes**, e um hook que a regravasse a cada commit destruiria a evidência do fechamento em curso. Tem caso que mede isso por SHA-256, e a mutação que aponta o destino de volta para `review/` mata a suíte.

**`pre-push` é composto pelo manifesto, com vocabulário fechado** — `security`, `doctor`, `tests`, `nenhum`. Valor fora dele **barra**, nomeando o valor: a mesma direção decidida na 2.5 para `verificacao.tests`, em que valor não reconhecido virou lacuna em vez de virar falso. Campo **ausente** segue a semântica fixada em 2026-09-17 para `ambiente.dependencias`: cai no padrão (`doctor` + `security`), porque ausente não é *"não verifique"* e também não autoriza impor o caro. `["nenhum"]` é o desligamento **explícito** — a diferença entre *"não quero"* e *"não pensei"*.

**`tests` não entra no padrão, nem nesta plataforma**, que tem suíte própria: ela leva ~12 min, e um portão de 12 min em todo push ensina `--no-verify` em uma semana. A suíte completa continua sendo critério de **pronto**, rodada no fechamento de subfase — que é quando ela responde alguma coisa.

### Código de saída 2: a regra que mais importa

`0` passou, `1` reprovou, **`2` não conseguiu verificar — e barra também**. É a política 4.5 aplicada ao hook: *"não consegui conferir" nunca vira "está bom"*. Scanner que não rodou não autoriza commit nenhum; manifesto ilegível **não** cai no padrão, porque assumir o padrão sobre manifesto quebrado seria verificar **menos** do que o projeto pode ter pedido, em silêncio.

### A revisão independente reprovou a 2.6, e achou três fail-opens que a suíte verde não via

**Rodada 1 — `qa-reviewer` REPROVADO, `security-reviewer` APROVADO nas seis áreas de exposição e REPROVADO no código novo.** Nenhuma `ALTA`. **Quatro `MEDIA BLOQUEANTE`**, e as três do QA eram buracos de verdade, derivados por leitura e **confirmados por execução antes de qualquer conserto**.

| # | Onde | O que, e por que bloqueava |
|---|---|---|
| 1 | `hook-pre-push.ps1`, etapa `tests` | **O pior fail-open da subfase.** `& $comando; exit $LASTEXITCODE`: quando o `&` lança — comando com erro de digitação, arquivo renomeado, `pytest` sem o venv — a exceção encerra **só aquela instrução**, o `exit` seguinte roda, e num processo novo `$LASTEXITCODE` **nunca foi definido**: `exit $null` sai com **zero**. O hook imprimia `ok - tests passaram` sobre uma suíte que não rodou — o oposto exato da regra central da 2.6, que está escrita em três arquivos |
| 2 | `hook-pre-push.ps1`, leitura da política | **`pre_push: []` desligava tudo e anunciava sucesso.** O leitor devolve `Object[]` de zero itens, e `$null -ne @()` é **verdadeiro**: a política virava lista vazia, nenhum valor era desconhecido, `'nenhum'` não estava lá, nada entrava na fila — e saía `ok -  passaram`, exit 0. Um **segundo** jeito de desligar, sem documentação, com mensagem de aprovação sobre zero verificação |
| 3 | `tests/suites/hooks.ps1` | **O caso que prova o padrão passava por qualquer implementação.** Mutação: acrescentar `tests` ao `$PADRAO`. Com a fixture sem `project.yaml`, a etapa caía no ramo de comando ausente, cuja mensagem não contém `run-tests` — então o `-notmatch` seguia verde. E o `-match 'doctor'` casava com a **linha da política**, não com a execução: tirar `doctor` da ordem também sobrevivia |
| 4 | `hook-pre-commit.ps1` | **O hook lê o DISCO, não o ÍNDICE**, e prometia *"antes de o conteúdo entrar"*. `git add` de um arquivo com segredo seguido de limpeza **só no disco** põe o blob no commit com a mensagem de aprovação. Achado do `security-reviewer` |

**Os dois revisores discordaram no quarto, e a discordância valeu mais que o consenso.** Os dois acharam o mesmo fato. O `qa-reviewer` classificou `BAIXA` porque o `STATE` já dizia *"working tree"*, o que é honesto, e porque o `pre-push` completo pegaria depois. O `security-reviewer` classificou `MEDIA BLOQUEANTE` porque o *docstring* e o runbook prometiam mais do que o código faz — **falsa garantia**, que está nominalmente no critério de 2026-09-14. Venceu o segundo: o critério nomeia a classe, e os **dois prescreveram o mesmo conserto**, então não havia conflito de ação — só de severidade.

> **O que eu fiz antes de consertar, e é o que separa esta rodada das primeiras da 2.5:** os dois fail-opens vieram com a ressalva *"derivei pela semântica do PowerShell, não executei"* — o `qa-reviewer` é read-only por desenho (ADR-0008). Rodei as duas sondas. Comando inexistente dentro de `-Command` devolveu **0**, e o controle, com comando existente saindo `3`, devolveu **3**. `pre_push: []` devolveu `Object[]` de **contagem 0, não-nulo**. Os dois mecanismos estavam certos, medidos, e só então foram tocados.

**Rodada 2 — o que foi feito:**

| Conserto | Causa atacada |
|---|---|
| o filho do `tests` responde por si: `try/catch` com sentinelas `97` (não consegui invocar) e `98` (terminou sem código), que caem em "não rodou" → exit 2 | depender de `$LASTEXITCODE` sobreviver a uma instrução que lançou é depender de algo que o PowerShell não promete |
| as aspas simples de `$raiz` passaram a ser **dobradas** | caminho com apóstrofo quebrava a sintaxe do filho e o resultado saía rotulado *"a suíte reprovou"* sobre suíte que nem começou. Achado do `security-reviewer`, mesma família |
| `[]` passou a ser **idêntico** a `["nenhum"]`, com a mesma mensagem honesta e a origem declarada | a semântica de 2026-09-17 já dizia que `[]` é declaração explícita de vazio; o que faltava era o código concordar com ela |
| o caso do padrão passou a medir **dois fatos separados**: a linha da política nomeia exatamente `doctor` e `security`, e o **marcador de etapa** (`  doctor...`) só é impresso quando a etapa executa | confundir *"está na política"* com *"rodou"* é a asserção que aceita qualquer implementação |
| `docstring`, mensagem de sucesso e `hooks.md` declaram que o `pre-commit` lê o disco — **nos dois sentidos**: o falso verde, e a fricção de barrar commit que não contém o segredo | declaração foi a condição mínima que o revisor pôs; ler o índice virou item **99**, nominal |
| a frase *"o que roda é o arquivo versionado que a revisão leu"* foi reescrita | era falsa com árvore suja, e `core.hooksPath` **relativo** faz o checkout de outra branch trocar os hooks sem reinstalar nada |
| `-ComEspaco` na fixture, e dois casos novos com caminho contendo espaço | **portabilidade estava `INCONCLUSIVO`**, e com razão: eu afirmava ter medido por sonda, e a sonda vivia no scratchpad — sem lastro nenhum na evidência que o revisor recebeu |
| um **terceiro** caso de espaço, agora com a **ferramenta** em caminho com espaço | ver abaixo: os dois primeiros não mediam o que eu achava que mediam |

**E a mutação pegou o conserto pela metade — o meu, desta vez.** Das cinco mutações desta rodada, quatro morreram. A quinta — tirar as aspas de `"$dir/../scripts/..."` no shim — **sobreviveu**, e o motivo é instrutivo: os dois casos novos põem o espaço no **repositório**, enquanto `core.hooksPath` aponta para o `githooks/` **da plataforma**, que vive em `C:\AI-WORKSPACE\...`. O `$dir` do shim nunca continha espaço, então as aspas nunca eram exercitadas. **Dois lugares diferentes podem ter espaço, e eu tinha coberto só um.**

O caso que faltava copia a ferramenta para uma pasta com espaço, e a asserção que discrimina é a **positiva**: com as aspas quebradas o caminho se parte, o shim falha, e a mensagem **válida** passa a ser barrada. Barrar continua acontecendo nos dois mundos — por isso o caso negativo sozinho não discriminava.

*(E a primeira versão desse caso falhou **sem mutação nenhuma**, por defeito da fixture: ela copiava `githooks/` inteiro, o `pre-commit` passou a disparar, e o `hook-pre-commit.ps1` não tinha sido copiado junto. O diagnóstico vale mais que a falha, e diz o contrário do que ela sugeria: a mensagem de erro trazia o caminho **com os espaços intactos** dentro do `-File`. As aspas do shim já funcionavam; o que estava incompleto era a cópia. A fixture passou a copiar só o shim do `commit-msg` — o Git pula hook que não existe.)*
| o título *"traz as SEIS dimensões"* e a lista escrita à mão saíram; a lista vem de `Get-DimensoesDoDoctor` | **o número em prosa que esta mesma subfase afirmou ter fechado**, sobrevivendo dentro da suíte |

**A lição desta rodada, e ela é sobre MIM, não sobre o código:** três dos quatro bloqueantes são afirmações minhas mais largas que o fato — *"exit 2 nunca vira está bom"* com dois ramos saindo 0 sem verificar, *"antes de o conteúdo entrar"* sobre um hook que lê o disco, e *"medido por sonda"* sobre medição que não viajou para a evidência. A 2.5 fechou com o detector de contrato porque **prosa não tem detector**; a 2.6 mostrou que o problema não era o contrato publicado — era eu escrever a garantia antes de o código merecê-la.

**Rodada 2 — `security-reviewer` APROVADO, `qa-reviewer` REPROVADO de novo.** O Security aprovou as seis áreas, declarou que **não sobrava condição antes do commit**, e fechou o próprio limite com honestidade: *"Não executei nada. A afirmação de que o fail-open foi confirmado por execução é sua; eu confirmei por leitura do código."* O QA achou **dois bloqueantes novos**, e o primeiro é o pior tipo:

| # | O que, e por que bloqueava |
|---|---|
| 1 | **O meu conserto do `[]` criou o defeito.** Pus o filtro de vazios **antes** da conferência de vocabulário: `- ""` e `- "   "` sumiam, a contagem caía a zero, e a lista caía no ramo de `nenhum` — **desligando toda a verificação com exit 0**, sob o rótulo **falso** de *"lista vazia (`[]`)"*. Medido: `- ""` devolve lista de **um item vazio**; `[]` e o hífen sozinho devolvem **zero itens**. Fatos diferentes, e eu os tinha jogado no mesmo caminho |
| 2 | **A armadilha que o runbook desta casa documenta, na terceira porta.** Sob `$ErrorActionPreference = 'Stop'`, o stderr de executável nativo redirecionado com `2>&1` vira `ErrorRecord` **terminante**: o `trap` do hook pegava e o push saía `2` dizendo *"não consegui rodar"*. Uma suíte que **passou** e imprimiu um aviso **barrava o push**; uma que **reprovou** saía `2` em vez de `1` |

> **A lei desta subfase, agora com nome:** *o meu conserto é código novo, e código novo tem o mesmo direito a defeito que o original.* O achado 1 não existia antes da rodada 2 — **eu o criei fechando o irmão errado**, dentro do conserto da classe "um ramo ao lado". A única defesa que funcionou foi a mesma de sempre: um revisor que lê o código sem acreditar no relato de quem o escreveu.

**Confirmei os dois por execução antes de editar**, inclusive a sonda que o próprio QA prescreveu: com `Stop` **lançou**; com `Continue` saiu `0`. E medi o terceiro ponto dele: um `.ps1` que termina **sem** `exit` deixa `$LASTEXITCODE` nulo dentro de `-Command`, então o sentinela `98` **é alcançável de fato** — ele só não tinha caso, que era a crítica dele.

**Rodada 3 — o que foi feito:**

| Conserto | Causa atacada |
|---|---|
| item vazio passou a **barrar**, nomeando a causa, antes de qualquer filtro | vazio **não é desligamento**: não dá para saber se faltou escrever o valor ou se era para não verificar nada |
| o rótulo deixou de citar a grafia `[]` | ele dizia `[]` para formas que não eram `[]` — registro falso dentro do próprio aviso |
| **`Invoke-FilhoDoHook`**, em `hooks-comum.ps1`, nos quatro sítios dos **dois** hooks — e, na rodada seguinte, o quinto sítio pela **outra** porta: `bootstrap.ps1` usa `Invoke-NativoLocal`, que já existia nele. São **cinco sítios por duas portas**, e não cinco usos da mesma função — a redação anterior dizia a segunda coisa. Achado do `qa-reviewer` | o defeito do stderr estava no `pre-push`, no `pre-commit` **e no `bootstrap`**. Consertar só onde o revisor apontou seria repetir, no conserto, a classe que o conserto fecha — e foi o que aconteceu: eu parei nos dois hooks, e o terceiro arquivo só caiu na rodada 3 |
| a mensagem do sentinela `97` passou a cobrir os **dois** casos que caem nela | ela dizia *"não consegui invocar"*, e o `throw` interno de uma suíte que **começou** também cai ali: barrava certo, com a causa impressa errada |

Quatro casos novos: item vazio nas duas grafias; suíte que escreve em stderr e **passa**; suíte que escreve em stderr e **reprova** (sai `1`, não `2`); e suíte que termina sem código de saída. Mais dois unitários, porque o conserto do `pre-commit` tinha ficado **sem caso**: `Invoke-FilhoDoHook` sob `Stop` não pode lançar e tem de devolver o código do filho; e **nenhum hook pode invocar `powershell` direto**, com par positivo exigindo que os dois usem a função.

### O instrumento de medição tinha o defeito que eu estava medindo

Das quatro mutações da rodada 3, três morreram e uma foi reportada como **sobrevivente**. Era mentira do medidor.

A mutação deixava um `try` sem `finally` — **erro de parse**, não regressão plausível. O PowerShell aborta antes de rodar, `$LASTEXITCODE` fica indefinido, e o meu script de mutação fechava com `exit $LASTEXITCODE` dentro de `-Command`: `exit $null` sai com **zero**. O script leu zero como "suíte verde" e concluiu "o guarda não pegou".

> **É exatamente o fail-open que esta subfase acabou de fechar dentro do `pre-push`** — a mesma linha, a mesma causa — vivendo dentro do instrumento que mede o conserto. Terceira vez que a prova por mutação mente nesta plataforma (item 62 do backlog).

Conferido em separado: o harness **não** é fail-open. Com a biblioteca quebrada ele falha alto, com `ParserError`, e o código de saída nem chega a existir. O defeito era só do medidor.

Duas correções no medidor: a invocação deixou de depender de `exit $LASTEXITCODE`, e **ausência da linha de resumo passou a ser `EXECUÇÃO INVÁLIDA`, nunca sobrevivência** — porque "a suíte não rodou" não pode virar "o guarda não pegou". A mutação foi refeita numa forma sintaticamente válida.

**E com o medidor consertado, a mutação sobreviveu de verdade — mas pelo motivo certo.** Mover a leitura para dentro do `try` não a matou, e aí a medição deu a resposta: **atribuir `$ErrorActionPreference` dentro de uma função é de escopo da função.** Mesmo com o `finally` devolvendo o valor errado, quem chamou continua com o seu.

> A mutação é **equivalente** — não muda comportamento observável —, então sobrevive **por direito**, e não por buraco de teste. E a asserção que eu estava tentando escrever testava algo que a própria linguagem garante: **ela nunca poderia falhar.** Pareceria rigor e não mediria nada.

A asserção saiu, com o motivo escrito no lugar dela, e o comentário da função passou a dizer que o `finally` é **simetria, não proteção** — prometer proteção que o escopo já dá seria mais uma garantia falsa, na mesma subfase que fechou três.

**Quatro instâncias da mesma família numa subfase só:** asserção posicionada onde ela sempre vale; teste cujo `exit` vem de outro lugar; mutação lida de um código de saída que ninguém definiu; e asserção sobre o que a linguagem já garante. Nenhuma das quatro é pega por suíte verde.

### O achado que nenhum revisor pegou, porque nem a suíte conseguia vê-lo

Depois de a quinta rodada reprovar, um caso novo começou a falhar com uma mensagem impossível: a regex casava quando eu a testava isolada, e **não casava** dentro do arquivo. Quase atribuí a "ordem de escrita entre duas edições".

A causa era um **caractere `0x08` (backspace) literal dentro da regex**. Um heredoc interpretou `\b` como escape em vez de passar as duas letras, e o padrão virou `Start-Process<BS>[^#]*powershell` — que nunca casa com nada.

> **O guarda que aquele padrão sustentava estava desarmado, em silêncio, com a suíte verde.** E o guarda de ASCII não viu, porque `0x08` é **menor** que 127: *"ASCII" não é o mesmo que "imprimível"*.

Duas lições, as duas agora em código:

1. **O runbook desta casa já prescrevia** escrever script de patch por arquivo, com a ferramenta `Write`, em vez de heredoc — justamente por causa de escapes. Eu quebrei a própria regra e paguei o mesmo preço.
2. O caso de ASCII em `tests/suites/scripts.ps1` passou a recusar **qualquer caractere de controle fora de TAB, CR e LF**, com o motivo escrito dentro. Uma regex desarmada por caractere invisível é pior que uma regex errada: a errada falha, a desarmada **passa**.

#### Vereditos finais da 2.6 — 2026-10-02

**Oito rodadas** com os dois revisores em contexto isolado (ADR-0007), read-only (ADR-0008). O `security-reviewer` emitiu **sete** vereditos (rodadas 2 a 8); o `qa-reviewer`, **oito**. Os dois vereditos que fecham a subfase, sobre o código que está sendo commitado:

| Revisor | Veredito | Escopo |
|---|---|---|
| `qa-reviewer` | **APROVADO** | Delta da rodada 8. Bloqueante da sétima fechado; três `BAIXA` (itens 118 a 120). Ele conferiu as quatro mutações **lendo o código linha a linha**, sem aceitar o relato: *"fecho a cobertura pela minha própria inspeção, não pelo relato"* |
| `security-reviewer` | **APROVADO** para o fluxo privado | Seis áreas. *"Não sobra condição minha antes do commit."* As lacunas da execução fechadas por inspeção própria, cada uma com a condição que a reabre |

**`portabilidade` fica `INCONCLUSIVO`, e isso está declarado, não apagado.** O item **103** — clone novo e a seção de hooks do `bootstrap` sem caso executado — não foi fechado, e eu não inventei caso para fechá-lo. O `bootstrap.ps1` resolve a própria raiz a partir do caminho dele e não aceita ser apontado para uma fixture sem refatoração. **Não é material para o escopo aprovado:** os três hooks têm caso ponta a ponta, inclusive em caminho com espaço, e a instalação tem caso de idempotência.

**O que estes `APROVADO` significam, e não mais do que isso**, nas palavras dele: *"nenhum padrão detectável, e eu li os arquivos apontados"*. Não quer dizer limpo em sentido absoluto.

**Números fechados**, que só entram agora porque só agora são números fechados: **oito rodadas**, **37 mutações** aplicadas contra o repositório real com restauração conferida por SHA-256, **sete bloqueantes** encontrados e fechados, e **22 itens de backlog** abertos (99 a 120). A suíte fechou em **419 casos**, dos quais **60** são da subfase.

**A conta que importa mais que as outras:** dos sete bloqueantes, **cinco estavam em código que eu tinha acabado de escrever para consertar o bloqueante anterior**. E nas três últimas rodadas não houve **nenhum** defeito de comportamento no produto — houve afirmação minha excedendo o que o código faz, derrubada uma a uma. O `security-reviewer` aprovou o produto em **sete** rodadas seguidas; o `qa-reviewer` reprovou a camada que o **mede** em sete delas.

### O padrão que esta subfase realmente ensinou: todo guarda que escrevi nasceu mais estreito que o título dele

Quatro vezes, e só a mutação mostrou nas quatro:

| O guarda prometia | O que ele media de fato |
|---|---|
| *"nenhum hook invoca `powershell` direto"* | só os três `hook-*.ps1` — **não via `bootstrap.ps1`, onde o defeito estava** |
| as quatro grafias de invocação | só a forma com `&`; **nenhum script usa as outras três**, então a largura não era medida por nada |
| *"o padrão não inclui `tests`"* | casava com a **linha da política**, não com a execução |
| *"os hooks rodam em caminho com espaço"* | o espaço estava no **repositório**, nunca na **ferramenta** |

Nenhum desses é defeito de produto. São **promessas de cobertura**, e a suíte verde confirmava todas sem medir nenhuma.

O conserto que funcionou nas quatro foi o mesmo, e é o mesmo da 2.5: **tirar a regra de dentro do caso e dar par próprio a ela.** A detecção de invocação virou `Test-LinhaInvocaPowershell`, com treze amostras positivas e quatro negativas — comentário, menção em prosa, e `WindowsPowerShell` dentro de um caminho. As amostras vivem **no teste**: plantar chamada ruim num script de produção para o guarda achar é exatamente o que ele existe para impedir.

### Quatro defeitos reais achados pela própria construção

**1. Um laço infinito, e a armadilha era do PowerShell.** O trim de linhas vazias das pontas usava `$uteis[1..($uteis.Count - 1)]`. Com **um** elemento, `$uteis[1..0]` não é intervalo vazio: o operador **inverte o sentido** e devolve dois itens (`$null` e o elemento). O array nunca encolhia, e a suíte travou sobre uma mensagem feita só de espaço. A guarda existia no laço de baixo e **faltava no de cima** — *o mesmo defeito, um ramo ao lado*, pela oitava vez nesta Fase. Os dois laços saem agora pela mesma porta.

**2. O leitor de manifesto não lê coleção em fluxo, e eu declarei em fluxo.** `pre_push: ["doctor"]` chegou ao hook como **uma string com colchete dentro** — é o item 42 do backlog, aberto pelo `security-reviewer` na 2.5 e ainda válido. A direção estava certa por acidente (barrou, com exit 2), mas a mensagem mandaria procurar erro de digitação num valor escrito corretamente. O hook passou a **detectar a forma** e a dizer que a causa é a lista de fluxo, com o exemplo em bloco; `project.yaml` foi declarado em bloco; e há par positivo, para que uma implementação que barrasse **toda** política declarada não passasse no caso.

**3. O leitor de YAML do próprio harness tinha o fail-open que ele existe para pegar.** `Get-CampoYaml`, em `tests/suites/docs.ps1`, buscava por **nome** e usava `\s*` depois dos dois-pontos. Quando `verificacao.hooks` passou a existir ao lado de `plugin.hooks`, duas coisas quebraram ao mesmo tempo: `\s` inclui quebra de linha, então a **chave de bloco** capturou `pre_push:` da linha seguinte como se fosse o valor; e quem pedia `hooks` recebia a **primeira** ocorrência — o bloco irmão respondendo pelo caminho pedido.

> É literalmente o defeito que o leitor de manifesto do doctor fechou na 2.4 — *"bloco irmão satisfazendo o caminho pedido"* — vivo **dentro do harness que deveria pegar esse tipo de coisa**. O guarda-corpo acusou: ele morreu tentando converter `pre_push:` para inteiro.

Conserto na raiz, e não no sítio: o valor passou a ter de estar na **mesma linha**; **nome ambíguo lança** em vez de escolher por posição; e entrou `-Bloco`, que é o mais perto de caminho pontuado que um leitor de teste precisa ter. Os **nove** sítios de chamada foram qualificados — não só o que quebrou, porque corrigir um e deixar os outros é o padrão que esta Fase viu oito vezes. E o leitor novo ganhou par negativo **e** positivo: chave de bloco devolve `$null`, o bloco pedido responde com o próprio valor, e nome ambíguo lança.

*(A primeira versão desse caso errou a asserção de ambiguidade, e o caso acusou: no manifesto real as duas chaves `hooks` **não** são ambíguas para este leitor, porque uma é chave de bloco e a regra 1 já a torna invisível — sobra uma só. Ambiguidade de verdade é dois **escalares** com o mesmo nome, e a fixture dela passou a ser outra. Asserção que descreve errado o mecanismo passa a valer quando o mecanismo mudar, e aí passa a mentir.)*

**Um segundo guarda-corpo acusou junto:** eu havia declarado em `tests/suites/hooks.ps1` o marcador `TESTE-CITA-PADROES-PROIBIDOS`, e o detector recusa **mais de um** arquivo isento. Ele estava certo duas vezes — a suíte de hooks monta o token sintético por concatenação e nunca o escreve literal, então não precisava da isenção, e declará-la roubaria a isenção que pertence a `tests/suites/scripts.ps1`.

**4. A coleta de evidência da própria 2.6 declarou os três shims como "não é texto reconhecido".** Os hooks são os **primeiros arquivos sem extensão** que este repositório versiona — e são justamente os que **executam a cada commit**. `Test-ExtensaoDeTexto` decidia pela extensão e, para quem não tem nenhuma, caía numa **lista de nomes** (`Jenkinsfile`, `Dockerfile`, `Makefile`).

> Consequência medida, não suposta: o `diff-report.md` saiu com **três lacunas**, e o efeito é que o `qa-reviewer` e o `security-reviewer` **não veriam o código que roda na máquina da mantenedora**. A lista já havia falhado duas vezes pelo mesmo motivo — `.npmrc`, achado do `security-reviewer`, e `.gitkeep`, lacuna que o revisor fechou à mão em duas rodadas seguidas. Esta é a terceira.

A regra desta casa para guarda que falha três vezes pelo mesmo motivo é **trocar a pergunta**, não acrescentar a quarta entrada. `Test-ExtensaoDeTexto` virou `Test-ArquivoDeTexto` — **o nome mudou junto com a pergunta**, porque o antigo prometia decidir pela extensão e era exatamente isso que estava errado:

| Caso | Quem decide |
|---|---|
| tem extensão | a lista de extensões, como antes |
| nome conhecido sem extensão | continua valendo |
| **sem extensão, fora da lista** | **o conteúdo** — byte `NUL` nos primeiros 8 KB significa binário |

É como o próprio Git decide, e é como `New-ProjetoDeTeste` **já decidia** no harness: a regra existia nesta casa, só não estava onde precisava. A mudança **só alarga** cobertura — nenhum arquivo que hoje é lido deixa de ser — e continua *fail-closed*: o que não dá para abrir devolve falso e quem chama declara a lacuna. Os **cinco** sítios de chamada foram atualizados, não só o que quebrou — `security-scan`, `collect-diff`, `scan-historico`, `scan-dado-pessoal` e `scan-exposicao`, mais a definição em `scan-comum`; `scan-historico.ps1` ficou deliberadamente **sem** raiz, porque os caminhos dele vêm do histórico e podem não existir no disco.

### O doctor ganhou a sétima dimensão — e uma invariante

`hooks`: `PASS` instalado e na versão esperada (ou o projeto não versiona hooks, que é **fato**, não defeito); `WARN` não instalado, apontando para outro lugar, ou shim fora da versão; `INCONCLUSIVO` quando a pergunta não pôde ser respondida. **`WARN`, e não `FAIL`:** hook ausente não torna o projeto incorreto — torna-o desprotegido contra erro previsível, que é coisa diferente. E o doctor **não instala**: há caso que mede que ele não tocou em `core.hooksPath`.

Quem responde é `Get-EstadoDosHooks`, a **mesma** função que o instalador chama no `-Verificar`. Duas implementações da mesma pergunta divergem — sete vezes na 2.5, sempre do mesmo jeito.

E entrou `Get-DimensoesDoDoctor`, a **lista canônica**: o doctor confere o que emitiu contra ela antes de escrever qualquer coisa e **lança** se divergir. Uma dimensão que deixasse de ser chamada produziria um relatório menor e igualmente verde — o doctor afirmando saúde sobre o que parou de olhar. O caso de teste lê a expectativa **dessa função**, e não de um número repetido no teste: era a classe que custou uma rodada inteira na 2.5.

### Dezesseis mutações, e a que sobreviveu foi a mais útil

**Vinte e duas** mutações aplicadas contra o repositório real ao longo da subfase, cada uma desligando **um** guarda, com restauração conferida por SHA-256 — treze nos hooks, três no preditor de texto e seis nos consertos da revisão. **Duas sobreviveram, e as duas viraram caso novo: no fim, todas morrem.** Na primeira leva, das treze, **doze morreram** — a regra da linha 2, o limite do assunto, a isenção do `fixup!`, a tesoura do `--verbose`, o caminho apontando para outro lugar, a marca de versão do shim, a extração que não pode ler a seção de exceções, o destino do relatório em `artifacts/review/`, o valor fora do vocabulário ignorado, o instalador sobrescrevendo configuração alheia, a dimensão sumindo da composição, e o projeto sem `githooks/` sendo acusado.

**Uma sobreviveu na primeira passada: desligar a guarda de manifesto ilegível do `pre-push`.** Depois do conserto descrito abaixo, ela morre — **treze de treze**. E ela expos um defeito **no meu próprio caso**, não no código:

> O manifesto que eu escolhi como "ilegível" — uma lista solta dentro de `identidade:` — **o leitor lê sem lançar**, devolvendo a chave que entendeu. O `exit 2` que o caso media vinha de outro lugar: a política **padrão** falhando num repositório **sem commit**. O caso passava, e continuava passando com a guarda desligada.

É a terceira vez nesta Fase que um caso passa pela razão errada, e a lição não é sobre este caso: **asserção de código de saída sem asserção de CAUSA aceita qualquer falha**, inclusive a de o código sob teste nem ter sido alcançado — exatamente a regra que o runbook já registrava para exceção cuja mensagem não se casa. O conserto foi triplo, e nenhuma parte dele é opcional:

1. o manifesto passou a ser ilegível **de verdade** — byte inválido para UTF-8, que a leitura estrita recusa por contrato (item 11, fechado em 2026-09-17);
2. a fixture ganhou **commit**, então o caminho padrão estaria limpo: o único motivo possível para barrar é o manifesto;
3. entrou **pré-condição** — o mesmo repositório, sem o manifesto quebrado, tem de sair `0` — e a asserção passou a exigir que a mensagem **nomeie** `project.yaml`.

**E a pré-condição pagou o próprio preço na primeira execução:** ela falhou, mostrando que a fixture continuava pobre demais — sem `project.yaml` e sem `docs/STATE.md`, o `doctor` sai `2` **legitimamente**, porque não tem o que medir. O caso barraria de novo pelo motivo errado, agora com o motivo errado oposto. A fixture passou a ter manifesto válido e `STATE`, e só então o único motivo possível de bloqueio é o que o caso diz medir. *Pré-condição não é formalidade: ela é o que separa "o teste barrou" de "o teste barrou pelo que ele afirma".*

### `--no-verify` existe, e não é combatido

Nenhum mecanismo aqui tenta impedí-lo. Fingir que hook local é incontornável seria **falsa garantia** — a forma exata que este repositório trata como pior que lacuna.

| Camada | O que é | Contornável pelo autor? |
|---|---|---|
| hooks (2.6) | feedback local rápido, na máquina de quem escreve | **sim, por desenho** |
| `pre-push` | portão antes de o histórico sair | sim — mesmo mecanismo |
| CI (2.8) | verificação **independente**, fora da máquina | não |

Proteção de branch no servidor não está disponível neste repositório privado no plano atual — decisão já registrada —, por isso a camada que vale é a CI da 2.8, e não esta.

### O que a 2.6 deliberadamente NÃO fez, e por quê

**O template não ganhou hooks.** A avaliação foi feita e a resposta é "ainda não", com o motivo nomeado: um projeto governado teria de receber ou **cópia** do scanner e do doctor — duplicando a plataforma inteira em cada projeto — ou um **caminho absoluto** para o plugin desta máquina, que é exatamente a dependência oculta do computador atual que o contrato proíbe. Há um meio-termo real — o template receber **só o `commit-msg`**, que é função pura sobre texto e não depende de nada —, e ele tem o custo de criar uma **segunda implementação da mesma regra**. Está no backlog com as duas opções e as duas consequências, para ser decidido, não esquecido.

**Os hooks de PLUGIN do Claude Code continuam zero.** `hooks/hooks.json` não existe, e `project.yaml` continua declarando `hooks: 0` — agora com o comentário dizendo que são **outra coisa**, em `githooks/`. O roadmap de 2026-09-18 anotava *"pré-requisito da verificação de hook `PreToolUse` na 2.6"*; isso não foi feito e está registrado como pendência nominal, não como concluído por omissão.

> **Atualização 2026-10-16:** o primeiro hook de plugin existe — `hooks/hooks.json` com um `PreToolUse` (matcher `Bash|PowerShell`) que bloqueia git destrutivo emitido por agentes, depois do incidente da r13. `project.yaml` declara `hooks: 1`; o plugin foi para `0.1.1`, e o hook só vale numa sessão depois de atualizar/reinstalar o plugin (a cópia instalada é congelada). Item 96 do backlog atualizado.

## Subfase 2.7 — branch / diff / PR client-side. **CONCLUÍDA em 2026-10-08** — o estado das rodadas está na tabela *Estado da verificação*, e só lá

Quatro arquivos novos, uma suíte nova, uma decisão de governança formalizada
em ADR e um guarda de byte que nasceu de um defeito desta própria subfase.

### O que entrou, e a separação de responsabilidades que a organiza

| Arquivo | Responde |
|---|---|
| `scripts/branch.ps1` | criar, listar, estado, trocar — com guarda-corpo em toda troca |
| `scripts/lib/branch-comum.ps1` | `Get-EstadoDeBranch`, `Get-BaseDeIntegracao`, `Test-NomeDeBranch` |
| `scripts/pr.ps1` | consultar e abrir PR, com **três portões** |
| `scripts/lib/pr-comum.ps1` | `Invoke-Gh`, `Get-EstadoDoGh`, `Test-EvidenciaParaPr`, `Get-ArgumentosDePrCreate`, `Get-CorpoDePr` |
| `tests/suites/fluxo.ps1` | a suíte da subfase, em duas camadas (a contagem vive no cabeçalho) |

A separação é deliberada e foi exigida pela mantenedora: `branch.ps1` cuida de
criação/estado/troca; `collect-diff.ps1 -Contra <base>` produz evidência;
`pr.ps1` integra via `gh` **sem manipular token**; os hooks da 2.6 são gates
locais; a CI da 2.8 será a verificação independente. Nenhum deles refaz o
trabalho do outro.

### Os portões do PR, e dois deles nasceram de falsa garantia minha

1. `gh` presente **e autenticado** — ausente e deslogado são estados distintos,
   porque levam a ações distintas;
2. `diff-report.md` existindo e **carimbado com o HEAD atual** — relatório de
   outro commit descreve outro código;
3. `security-report.md` carimbado **e sem achado bloqueante**.

O terceiro portão foi escrito **depois** do resto, e o motivo importa: o
cabeçalho do `pr.ps1` já afirmava que a segurança era verificada *"com o fluxo
privado tendo saído 0"* enquanto o código **só conferia que o arquivo existia e
citava o commit**. Um relatório cheio de `ALTA` passava. Eu encontrei isso
escrevendo o briefing do `security-reviewer` — redigindo a pergunta que eu
queria que ele atacasse, descobri que a resposta era "não, não verifica".

Falsa garantia é pior que lacuna: a lacuna se vê, a garantia falsa tranquiliza.
O código foi corrigido, não a frase — e a frase antiga ficou registrada no
cabeçalho como o que ela foi.

A leitura dos achados **reusa** `Get-AchadosBloqueantesDoRelatorio`, de
`hooks-comum.ps1`, porque ela já sabe a única distinção difícil: achado real
não é achado **aceito por exceção** (ADR-0010), e as duas seções do relatório
têm linhas `MEDIA`. Mas aquela função devolve lista vazia quando não consegue
ler — deliberado no contexto do hook, onde quem chama já sabe pelo código de
saída do scanner que houve bloqueio. Aqui ninguém sabe. Por isso a exigência da
seção `## Achados` vem **antes** da leitura: sem ela, "não reconheço o formato"
viraria "nada achado, pode abrir". Relatório de formato desconhecido sai **2**.

### Quatro defeitos achados pela execução, não pela leitura

- **`origin` listado como se fosse branch.** `%(refname:short)` de
  `refs/remotes/origin/HEAD` é `origin`, sem o `/HEAD`. O filtro passou a ser
  sobre o refname completo.
- **Linha fantasma `#    ()` na lista vazia de PRs** — e **meu primeiro
  diagnóstico estava errado**. Eu afirmei que `ConvertFrom-Json` sobre `[]`
  devolvia `$null`. Medido: devolve um `Object[]` **vazio** como **um** item do
  pipeline. Filtrar pela forma também quebraria o caso de um PR só. Há caso
  para zero, um e dois PRs exatamente por isso.
- **Um `·` (U+00B7) não-ASCII** em `pr-comum.ps1`.
- **Atribuição à variável automática `$args`** em `pr.ps1`.

### O byte CR, e o terceiro guarda de byte

Escrevendo o terceiro portão, o `\r` de `artifacts\review` passou por uma
camada de ferramenta que interpretou escapes e virou **0x0D de verdade** dentro
da string. O caminho ficou `artifacts<CR>eview\security-report.md`.

O arquivo continuou ASCII. Continuou sem caractere de controle proibido —
porque o guarda de controle **permite** 0x0D, e tem de permitir: CRLF é fim de
linha legítimo. Continuou com sintaxe válida. A suíte continuou verde. E o
portão de segurança que aquela linha sustentava simplesmente nunca encontraria
o relatório.

É a mesma classe do `0x08` da 2.6, e a lição é a mesma: **uma regra errada
falha; uma regra desarmada passa.** Entrou `Get-CrSoltos` na suíte `scripts` —
CR que não é seguido de LF —, com o defeito real reproduzido byte a byte no par
positivo, e com assertivas de que os outros dois guardas **não** pegam esse
arquivo (senão o guarda novo seria redundante).

### O primeiro lote de mutações, e as duas que sobreviveram eram a mesma falha minha

Na primeira rodada, duas sobreviveram: remover a recusa de `branch == base` e
remover a exigência de `-Titulo`. Os dois casos **passavam pelo motivo errado**:
com o portão removido, o fluxo caía no portão seguinte — evidência ausente — e
produzia o mesmo código de saída. O caso media o número certo pela razão errada.

A correção foi satisfazer todos os outros portões, para que só o portão sob
teste pudesse recusar. É a classe que a 2.6 pagou repetidas vezes — a contagem
dela vive na seção da 2.6, e só lá — e ela reapareceu na primeira subfase seguinte.

Duas asserções foram reforçadas **antes** de rodar a mutação, por raciocínio
sobre o que ela faria:

- a de `origin` só procurava a palavra `origin` — afrouxar o filtro faria
  `refs/remotes/origin/HEAD` virar `HEAD`, e ela aprovaria. Virou contagem do
  conjunto inteiro;
- a de `gh` ausente aceitava qualquer `exit 2` — mas sem o portão o script sai
  2 adiante, pelo motivo errado. Passou a exigir a mensagem do `PATH`.

### O limite declarado do mock

O `gh` é mockado por um `.cmd` posto na frente do `PATH`. **Medido:** o `gh`
real é um `.exe` e o mock é um `.cmd`, que passa
pelo `cmd.exe`, e um argumento multilinha — que é exatamente o caso do
`--body` — chega **truncado na primeira quebra de linha, sem erro nenhum**.

O mock serve para medir código de saída e qual subcomando foi chamado. Ele
**não** serve para medir o conteúdo dos argumentos. Por isso a montagem da
linha de comando saiu para `Get-ArgumentosDePrCreate` e é pinada em memória.
Um teste que afirmasse `--body` correto pelo log do mock estaria afirmando o
que o mock não pode testemunhar.

### O que a 2.7 deliberadamente NÃO fez

- **Não** há proteção de branch, e o código não finge que há (ADR-0011). O
  `pr.ps1` diz isso em voz alta ao abrir, e o corpo do PR repete.
- **Não** manipula token. O `gh` autentica por navegador (ADR-0003, item 5).
- **Não** transcreve evidência no corpo do PR — `artifacts/` é gitignored, não
  viaja num clone, e publicar achado de segurança num PR nunca foi autorizado.
  O corpo aponta e diz como regerar.
- **Não** faz `stash` por conta própria: esconder trabalho sem pedido é a
  forma mais rápida de perdê-lo.
- **Não** roda scanner nem coletor. Lê o que eles deixaram. Rodar duplicaria
  ferramenta, que é o que a 2.6 evitou.

### Rodada 1 de revisão independente — **os dois revisores REPROVARAM**, 2026-10-02

Isto está registrado aqui porque a seção acima foi escrita **antes** da revisão e
dizia "Concluída". Ela estava errada, e registro que se contradiz é a classe que
este repositório trata como pior que lacuna.

| Revisor | Veredito global | Áreas reprovadas |
|---|---|---|
| `security-reviewer` | **REPROVADO** | exposição externa (1 MEDIA) |
| `qa-reviewer` | **REPROVADO** | correção e cobertura (5 MEDIA) |

#### Os cinco bloqueantes, e os dois revisores acharam o primeiro independentemente

1. **O portão comparava com o HEAD LOCAL, mas o PR publica o REMOTO.**
   `gh pr create --head <branch>` não faz push: o GitHub monta o PR com o que
   está no remoto. Caso comum — empurro Y, commito Z aqui, coleto em Z, abro o
   PR: o PR mostra Y e o corpo **publicado** afirma Z. Falsa garantia num texto
   que sai da máquina. Entrou `Test-PublicavelNoRemoto`, que recusa árvore suja,
   branch não empurrado e ponta divergente.
2. **O carimbo era procurado em qualquer ponto do texto.** O `diff-report`
   transcreve o diff do `STATE.md`, e o `STATE.md` cita SHAs — hoje seis. A
   evidência do branch A valia como evidência do branch B. Entrou
   `Test-CarimboDeHead`, ancorado no bloco de cabeçalho.
3. **O `diff-report` passava registrando suíte vermelha, ou gerado com
   `-SkipTests`.** A mesma classe que o terceiro portão tinha corrigido — eu
   consertei a segurança e deixei o irmão dela como estava.
4. **Um teste meu passava pelo motivo errado** (`Get-BaseDeIntegracao`). Apagar
   o bloco do `symbolic-ref` inteiro não derrubava o caso: o fallback
   convencional respondia `main` do mesmo jeito. Era a *terceira instância* da
   classe, e o briefing tinha pedido explicitamente que a procurassem.
5. **`catch { $prs = @() }`** transformava JSON ilegível em "nenhum PR aberto"
   com exit 0. Fail-open na consulta.

Mais um achado que o QA classificou como BAIXA e que foi tratado como maior
porque é **destrutivo**: `-Criar x -De -m` virava `git branch x -m`, que
**renomeia o branch atual**. O script então imprimia "você continua em 'main'" —
e `main` não existia mais.

#### Duas afirmações minhas que a medição derrubou

- Minha prosa dizia que `check-ref-format` **aceita** espaço e hífen inicial.
  Medido: recusa os dois (exit 128). O QA tinha razão.
- **E a correção dessa prosa também estava errada.** Eu escrevi que o 128 do
  `-flag` seria "o git lendo opção desconhecida". O QA contestou de novo e deu
  a medição: `check-ref-format --flag-inventada` sai **129**, que é erro de
  uso; `--branch '-flag'` sai **128**, que é recusa de nome. Então as **duas**
  regras manuais são redundantes quanto ao veredito, e o que elas acrescentam
  é só a mensagem — que agora é o que o caso de teste mede. A mesma linha
  esteve errada em duas rodadas seguidas, de dois jeitos diferentes.
- O QA afirmou que aspas em `-Titulo` chegariam ao `gh.exe` como três
  argumentos, com injeção de flag. Medido com uma sonda `.exe`: chega como **um**
  argumento, com as aspas removidas.

  **E essa conclusão estava errada, por generalizar de uma medição só.** O
  `qa-reviewer` pediu, na rodada 2, que eu medisse o caso com ESPAÇO antes da
  aspa. Medido com a mesma sonda:

      -Titulo 'fix "a --draft"'                 ->  [1]=fix a   [2]=--draft
      -Titulo 'corrige o "modo seguro" do hook' ->  [1]=corrige o modo
                                                    [2]=seguro do hook

  **Há injeção de flag**, e o revisor estava certo nas duas rodadas. O
  `--draft` chega ao `gh` como flag, não como texto, e um título natural com
  aspas quebra em dois argumentos. O `pr.ps1` passou a **recusar** aspa dupla
  no `-Titulo`: escapar exigiria reproduzir a regra de citação do PowerShell
  5.1, que é justamente a regra que me enganou duas vezes.

#### O padrão da subfase, e ele é o mesmo da 2.6

Um guarda meu nasceu mais estreito que o título que dei a ele **muitas vezes**
nesta subfase — a contagem corrente vive em *O padrão desta subfase*, mais
abaixo, e **só lá**. O `qa-reviewer` mostrou, na rodada 5, que a regra que eu
criei proibia repetir contagem de **rodada** fora da tabela e deixava a
contagem de **instâncias** solta, repetindo o mesmo defeito num campo vizinho.
A regra passa a valer para toda contagem.

Boa parte delas foi descoberta **depois** de eu já ter corrigido o que os
revisores apontaram — pela mutação, no código que eu tinha acabado de escrever
para consertar o bloqueante anterior.

As três últimas foram todas a mesma coisa: **a fixture falhava por mais de um
motivo ao mesmo tempo**, então o caso nunca media a regra que ele existia para
medir. Um caso só prova uma regra quando essa regra é a *única* coisa capaz de
derrubá-lo.

#### Estado da verificação neste ponto

| Verificação | Estado em 2026-10-08 |
|---|---|
| Suíte `fluxo` | **verde** — a contagem vive só no cabeçalho deste arquivo |
| Suíte completa | **verde** — a contagem vive só no cabeçalho deste arquivo, de propósito. Rerodada pelo coletor da rodada 7: o resultado real está em `artifacts/review/diff-report.md` |
| Mutação | lote consolidado, executado em 2026-10-05 entre 09:46 e 12:24, depois do veredito da rodada 6 (08:54) e da correção do token em `fluxo.ps1` (09:05) — saídas em `artifacts/review/mutacoes-27.md`. **As saídas não carimbam o estado da árvore**: que elas descrevem o código atual é inferência por horário, não prova. Lacuna apontada pelo QA na rodada 6, ainda aberta |
| `plugin validate` | passou, com 1 aviso **pré-existente** sobre `CLAUDE.md` na raiz do plugin, alheio à 2.7 |
| `/os:doctor` | `exit 0`, 7 dimensões, 1 WARN (trabalho não commitado) |
| Segurança | `exit 0`, ALTA 0; os `MEDIA` são só as exceções do ADR-0010, identificadas por caminho e categoria |
| Evidência | a coleta de 2026-10-05 **antecedia** as correções da rodada 6 e deixou de valer; recoletada em 2026-10-08 para a rodada 7 |
| Revisão rodada 1 | **REPROVOU** nos dois revisores — 5 `MEDIA`, corrigidos |
| Revisão rodada 2 | security **APROVADO**; QA **REPROVOU** com 2 `MEDIA`, corrigidos |
| Revisão rodada 3 | **REPROVOU** nos dois — 1 `ALTA` e 2 `MEDIA`, corrigidos. Ver abaixo |
| Revisão rodada 4 | security **APROVADO**; QA **REPROVOU** com 2 `MEDIA`, corrigidos |
| Revisão rodada 5 | security **APROVADO**; QA **REPROVOU** com 1 `MEDIA` — a 13ª instância, corrigida |
| Revisão rodada 6 | security **APROVADO**; QA **REPROVOU** com 2 `MEDIA`, corrigidos. Ver abaixo |
| Revisão rodada 7 | **APROVADO nos dois revisores**, 2026-10-08. QA: 4 `BAIXA`; security: 1 `BAIXA`. Nenhum abre rodada (regra de 2026-09-14) — viraram backlog 130 a 134. Vereditos em `artifacts/review/veredito-27-r7-{qa,sec}.txt` |

#### A rodada 6 achou duas coisas que eu tinha declarado corrigidas

**A primeira é mecânica, e vale guardar:** eu corrigi uma contradição dentro de
`artifacts/review/mutacoes-27.md` e **regerei o arquivo logo depois**,
sobrescrevendo a correção com o cabeçalho antigo. Então afirmei no briefing que
estava feito. Arquivo **gerado** se conserta no gerador — que por isso saiu do
scratchpad e passou a viver versionado em
`artifacts/review/ferramentas/montar-mutacoes.py`, com os números **contados**
das saídas em vez de redigidos por mim.

**A segunda é de segurança, e eu contrariei o próprio registro.** O caso de
CONTRATO novo precisava de um token em formato válido, o scanner acusou `ALTA`
no arquivo rastreado, e eu declarei o marcador de fixture chamando isso de
"convenção da casa". O registro diz o oposto para arquivo **novo**, e com todas
as letras, desde a 2.5: *"Acrescentar um terceiro arquivo sob o marcador
aumentaria a dívida"* — o marcador é a única rota de rebaixamento que
`-ParaPublicacao` **não** anula, e ela cobre o arquivo inteiro.

A correção foi a mesma que a 2.5 adotou: montar o token **por concatenação**,
como `hooks.ps1` e `doctor.ps1` já fazem. O marcador saiu, `ALTA` voltou a 0, e
`BAIXA` voltou de 22 para 21 — sem dívida nova. A fixture no disco continua
recebendo o token inteiro, então o caso não perdeu força nenhuma.

**E uma correção de instrumento:** a mutação que eu havia escrito para esse
cenário desarmava o **leitor**, não o **gerador** — então derrubava também os
casos de fixture, e não distinguia "o teste lê o formato real" de "o teste lê o
que eu escrevi". Agora ela muta o `security-scan.ps1` para emitir
`| **ALTA** |`, e derruba **exatamente um** caso: o de CONTRATO.

#### A rodada 3 achou o defeito mais grave da subfase, e ele era invisível

**`ALTA`, confirmado por execução antes de consertar:** a tabela `Escopo
COLETADO` do relatório tem **duas** linhas que casavam com a minha regex, e a
primeira é a do `git diff --stat`. O leitor extraía `Referencia = --stat HEAD`,
que não resolve para commit nenhum — então o portão devolvia `INDETERMINADO`
para **toda coleta real**. O `-Abrir` não autorizava nada, nunca.

A suíte estava verde porque **a minha fixture escrevia só a segunda linha**.
Ela fabricava a entrada a partir do meu modelo do formato, e não do formato.

O que fecha isso não é a regex corrigida — é o **caso de CONTRATO**, que roda o
`collect-diff.ps1` de verdade e entrega a saída dele ao portão. Esse contrato
entre os dois arquivos existia só na minha cabeça.

**`MEDIA` do security, e era sobre mim:** eu afirmei no briefing que a pendência
do `ls-remote` estava no backlog e que o comentário errado fora corrigido. O
revisor foi ao disco e mostrou que **nenhuma das duas coisas era verdade**.
Afirmação falsa feita a quem revisa é pior que o defeito que ela esconde.

**`MEDIA` do QA:** o registro se contradizia em seis pontos. Corrigido com uma
regra estrutural: o estado das rodadas vive **nesta tabela**, e os outros
lugares apontam para ela.

#### A rodada 4 achou a correção da rodada 3 medindo outra coisa

O caso que eu escrevi para **corrigir** a classe "teste que mede outra coisa"
era, ele mesmo, mais uma instância dela — a décima segunda.

Ele se chamava *"o relatório que o coletor REALMENTE gera é aceito pelo
portão"*, e **não chamava `Test-EvidenciaParaPr` em lugar nenhum**: só
`Get-ComparacaoDaColeta`. Pior, rodava o coletor com `-SkipTests`, que produz
um relatório **sem** a linha de código de saída — exatamente o que o portão
real recusa. O caso afirmava que o portão aceita um relatório que o portão
teria recusado.

O contrato tem **quatro** partes — referência, carimbo do HEAD, linha de exit e
seção `## Achados` — e só a primeira estava protegida. Agora os **dois**
geradores rodam de verdade dentro do caso, o portão lê a saída dos dois, e há
par negativo: a mesma coleta com `-SkipTests` tem de dar `INDETERMINADO`.

**E o registro ainda se contradizia em três pontos**, depois de eu ter afirmado
no briefing que estava consertado. Um deles mandava uma sessão futura *"repetir
o lote 2 até 12/12"* — trabalho de duas rodadas atrás. A correção virou regra:
**nenhum lugar fora da tabela conta rodada**, e o roteiro de retomada descreve
o ciclo, não um ponto dele.

#### O padrão desta subfase, em uma frase

**Treze vezes** um caso meu mediu algo diferente do que o título dele
anunciava. Os revisores acharam cinco; a mutação achou as outras oito — e cinco
delas estavam em código que eu tinha acabado de escrever para consertar a
anterior.

**As duas últimas estavam dentro do caso de CONTRATO**, que eu escrevi
justamente para corrigir essa classe. A 12ª: ele não chamava o portão. A 13ª:
ele rodava o scanner sobre uma fixture **limpa**, então o leitor de achados
nunca era exercitado contra uma linha real — e um leitor que nunca acha nada
passa exatamente como o leitor certo num repositório limpo. Essa falharia
**aberta**: PR publicado com `ALTA` em aberto.

A correção estrutural não foi escrever casos melhores: foi **parar de fabricar
a entrada**. O caso de CONTRATO roda os geradores reais porque fixture que
escreve o formato a partir do meu modelo dele mede o meu modelo, não o
formato — e foi exatamente assim que o `ALTA` da rodada 3 ficou invisível.

#### Duas medições que os revisores pediram e não podiam fazer

| Previsão | Medido | Quem estava certo |
|---|---|---|
| `check-ref-format --flag-inventada` sai 129, e 128 é recusa de nome | `--flag-inventada` → **129**; `--branch '-flag'` → **128** | o revisor. Minha prosa errou **duas vezes** na mesma linha |
| aspa com espaço antes injeta flag | `fix "a --draft"` → `[1]=fix a` `[2]=--draft` | o revisor. Eu disse que era só corrupção |
| barra invertida no fim quebra o argumento | `corrige path C:\temp\` → **COUNT=2**, o título engole `--body` e `--base` | os dois previram, e é **pior**: não falha fechado |

#### Backlog aberto pela 2.7

- **121.** Trocar a leitura da ref de acompanhamento local por `git ls-remote`
  em `Test-PublicavelNoRemoto`. Hoje o portão lê a ref **local**, que só está
  correta porque uma única pessoa empurra, desta máquina. `git ls-remote` lê o
  remoto **sem escrever ref nenhuma** — a justificativa antiga (*"não busco
  porque `fetch` escreve refs"*) era um falso dilema, apontado pelo
  `security-reviewer`. **Gatilho: antes de a subfase 2.8 passar a empurrar
  branches.**
- **122.** Teste para o override por `-Base` no `pr.ps1`. Se regredir, o PR
  abre contra a base errada sem falhar. O log do mock já registra `--base`,
  então o caso é barato. Prioridade do `qa-reviewer` entre as guardas sem caso.
- **123.** O `catch` que lista branches remotos devolve `Indeterminado` e **não
  tem caso**: forçá-lo exigiria instrumentar o `Invoke-Git`. Declarado no
  código, não medido.
- **124.** O corpo do PR não declara se a varredura usou `-SemHistorico` ou
  `-SemRede`. O `security-reviewer` disse que não bloqueia, e recomendou
  declarar os modificadores — é metadado, não transcrição de achado.
- **125.** `plugin validate` passou a avisar que `CLAUDE.md` na raiz do plugin
  não é carregado como contexto. É estrutura **pré-existente**, anterior à 2.7.
- **126.** **Guardas sem mutação**, listadas pelo `qa-reviewer` e nenhuma
  bloqueante. Ficam registradas porque guarda sem caso não falha: ela aprova.
  - o ramo `INDETERMINADO` de *"não consegui resolver ref/base"* — é ele que
    fez o `ALTA` da rodada 3 falhar **fechado**, e não tem caso próprio;
  - o fallback do `@{upstream}` em `Test-PublicavelNoRemoto`;
  - o `catch` do `Invoke-Gh`;
  - **o repasse de `-Rascunho:$Rascunho` no `pr.ps1`** — é a de maior
    consequência das quatro: se o repasse sumir, um PR pedido como rascunho
    sai pronto para revisão, em silêncio.
- **127.** **Até onde o guarda de byte alcança.** `Get-BytesDeControle` permite
  TAB, CR e LF, porque os três são legítimos num `.ps1`; `Get-CrSoltos` olha só
  CR sem LF. Duas vezes nesta subfase uma camada de ferramenta interpretou
  escape e plantou byte de controle num literal — `\r` virou CR (pego pelo
  guarda novo) e `\t` virou TAB (não pego; estava num comentário, sem efeito).
  Num literal de caminho, um TAB desarmaria o portão com a suíte verde. Avaliar
  um guarda de TAB **dentro de string**, que é diferente de TAB na indentação.
- **128.** **O frescor do `/os:doctor` olha o commit, não a árvore.** Em
  2026-10-08 o doctor deu `PASS` em frescor com `diff-report` e
  `security-report` carimbados no `HEAD` atual, mas **anteriores** a cinco
  arquivos editados depois da coleta. A frase do doctor é literalmente
  verdadeira (*"descreve o commit atual"*), e a dimensão `git` acusa `WARN`
  pelo trabalho não commitado — mas nada liga uma coisa à outra, e quem lê só
  `frescor: PASS` conclui que a evidência vale para o que está no disco.
  Candidato: carimbar no relatório um hash da árvore de trabalho (ou a lista
  de mtimes dos arquivos cobertos) e o doctor comparar. Achado da abertura da
  sessão 3, por comparação de datas, não por revisor. Escopo da 2.5, não da 2.7.
- **129.** **Duas pernas do contrato só existem com formato inventado**
  (`BAIXA` 5 do `qa-reviewer`, rodada 6; falham **fechadas**). A fixture da
  coleta com suíte falhando escreve `(FALHOU)` (`fluxo.ps1`, em
  `New-EvidenciaFixture`), e o gerador real escreve `(NAO passou)`
  (`collect-diff.ps1`); a regex só lê o número, então hoje não há defeito. E o
  título da seção de achados aceitos por exceção na fixture difere do real
  (`security-scan.ps1`, seção `ACEITOS POR EXCECAO`). Se esse formato mudar, o
  `-Abrir` fica inutilizável **nesta plataforma**, que tem `MEDIA` aceitos.
  Correção: um caso de CONTRATO para cada perna, rodando o gerador real.
- **130.** **Nenhum hook nem o doctor consulta o manifesto do mutador**
  (`BAIXA` do `security-reviewer`, rodada 7). A mutação 21 só muda a forma da
  linha de achado do `security-scan.ps1` — não muda código de saída nem
  contagem —, então um resíduo de mutação commitado passaria pelo pre-commit e
  pelo pre-push e deixaria o portão do `pr.ps1` **aberto** com `ALTA`. Vale
  para todo o lote 27 (`pr-comum.ps1`, `pr.ps1`). Exige duas falhas juntas
  (mutador morto antes do `finally` **e** commit sem ler status e diff).
  Correção: o pre-commit (ou o doctor) recusa quando
  `%TEMP%\os-mutacao-backup\manifesto.json` **não** estiver vazio.
- **131.** **Carimbo da árvore no mutador** (`BAIXA` 1 do `qa-reviewer`,
  rodada 7). O QA reduziu a lacuna por leitura — os alvos de todas as mutações
  do lote estão intactos e as edições posteriores em `fluxo.ps1` só acrescentam
  asserção — e a julgou não bloqueante. Para o próximo lote: `mutar.py`
  imprime no bloco `== base ==` o SHA-256 dos alvos e das suítes, e o cabeçalho
  gerado por `montar-mutacoes.py` deixa de afirmar *"sobre um unico estado de
  codigo"* como fato. O bloco da sessão 2 em `SESSIONS.md` diz o mesmo e **não
  é reescrito** — a correção está no bloco da sessão 3.
- **132.** **`montar-mutacoes.py` conta o que rodou, não o que devia rodar**
  (`BAIXA` 2 do QA, rodada 7). Apagar uma saída de lote faz a tabela encolher
  sem aviso, e `MORREU PELO MOTIVO ERRADO` fica fora do total. Correção:
  conferir o conjunto de índices contra a lista do mutador. O artefato atual
  está certo — o QA conferiu os índices um a um.
- **133.** **O caso 3 de CONTRATO copia a regex do leitor, e a mutação do
  leitor sumiu** (`BAIXA` 3 do QA, rodada 7). A asserção de formato em
  `fluxo.ps1` repete a regex de `hooks-comum.ps1` em vez de chamar
  `Get-AchadosBloqueantesDoRelatorio` — contra o comentário do próprio
  `pr.ps1`. E a mutação do lado do leitor foi **substituída** pela do gerador,
  não complementada. Falha fechada. Correção: chamar o leitor real e devolver
  ao lote uma mutação na regex de `hooks-comum.ps1`.
- **134.** **"Sete vezes" em comentário de código se contradiz** (`BAIXA` 4 do
  QA, rodada 7). `pr.ps1` e `branch-comum.ps1` atribuem à 2.6; o `STATE.md`
  atribui à 2.5. Tirar a contagem dos dois comentários — mesma regra que já
  vale para a prosa. A frase quebrada do `CHANGELOG` foi corrigida no
  encerramento.
- **135. CORRIGIDO na branch `vnext` (2026-10-08).** **A suíte falhava em
  clone limpo.** `Get-CampoYaml` (`tests/suites/docs.ps1`) terminava o padrão
  em `$`, que no .NET com `(?m)` casa só antes de `\n`. O `.gitattributes`
  fixa `eol=crlf` para `.ps1`, então num checkout novo o literal de várias
  linhas do caso ganha `\r`, e `hooks: 0\r` não casava. Na máquina de trabalho
  o arquivo tinha ficado em LF (`git ls-files --eol` → `w/lf`) e o caso
  passava. Achado pela primeira suíte completa rodada numa worktree recém-criada
  — o mesmo cenário de uma máquina nova. Correção: `\r?$`, e o caso agora
  exercita LF **e** CRLF explicitamente. Prova por mutação: devolvido o `$`
  antigo, o caso cai com *"em CRLF"*. É a armadilha que o runbook já
  descrevia, e que só um restore em máquina limpa mede.
- **136.** **Item 66 ampliado** (`BAIXA` 5 do `security-reviewer`, r1 do
  motor): `docs/vnext/PROGRAMA-VNEXT.md` cita 16 caminhos com o perfil Windows
  da mantenedora e o inventário de projetos corporativos. Mesmo gatilho do 66:
  antes de qualquer publicação. Os contratos do registry usam `${USERPROFILE}`.
- **137.** **Symlink no WIP sem caso executado nesta máquina.** O motor marca
  symlink como não protegível (r2), mas o caso `test_symlink_no_wip_nao_e_protegivel`
  é pulado aqui: o Windows não cria symlink sem privilégio de desenvolvedor.
  Declarado, não medido.
- **138.** **Três listas de nome de segredo** (`BAIXA` 3 do `security-reviewer`,
  r2 do motor). O motor tem agora **uma** regra (`gitinfo.nome_de_segredo`,
  famílias `NOME_DURO` e `NOME_PALAVRA` desde a r5, usada no WIP, no L4 e no check), mas o scanner PowerShell
  (`scripts/lib/scan-*.ps1`) tem a dele, com 28 nomes canônicos. Unificar
  exige uma fonte única lida pelas duas linguagens (um arquivo de dados
  versionado). Falha para o lado seguro onde divergem.
- **139.** **A prova por mutação não vem do coletor** (`qa-reviewer`, r2 do
  motor). Desde a r3 ela carimba HEAD e SHA dos alvos e roda a base sem
  mutação, mas continua sendo produzida por quem construiu. O passo certo é
  o `collect-diff.ps1` rodar o `unittest -v` do motor e a mutação ele mesmo.
- **140.** **O scanner de dado pessoal não vê CPF de assinatura digital.** O
  texto ICP-Brasil "Assinado digitalmente por NOME:12345678909" traz o CPF
  sem pontuação logo depois do nome. A 1ª passada da sanitização do Semanal
  (2026-10-11) não o redigiu, porque o callback exigia CPF formatado ou "cpf"
  a até 20 caracteres, e `scripts/lib/scan-dado-pessoal.ps1` também não o
  acusou. Foi achado pela varredura pós-adoção, com o leitor genérico de
  11 dígitos com DV. Correção aplicada no instrumento de sanitização (2ª
  passada). **Falta no scanner da plataforma:** acusar 11 dígitos com DV
  válido a até 80 caracteres de `cpf|digitalmente por|assinad[oa] por`. A
  varredura de todos os 11 históricos achou o padrão só no Semanal.
- **141.** **Semanal: `output/visual_review/golden/` (35 PNG de páginas
  renderizadas).** A mantenedora decidiu em 2026-10-11 que saem do Git. Já
  saíram do **rastreamento** (`63be648`, publicado), com os originais no Drive.
  Continuam no **histórico publicado**: tirá-las de lá exige reescrever e
  forçar o push. O espelho sanitizado está pronto e provado em
  `_recovery/sanitizacao-golden/prog-relatorio-semanal/`, com 69 commits. A
  adoção espera autorização explícita de force push (H3). **Resolvido em 2026-10-11:** a titular autorizou
  o force push, e o clone novo do GitHub tem 70 commits e zero golden (journal, evento
  `golden-fora-do-historico-publicado`); conferido de novo em 2026-10-16: `origin` sem nenhum commit com golden.
- **142.** **`git.exe` plantado no diretório corrente** (`BAIXA` 2 do
  `security-reviewer`, r4 do motor). O `CreateProcess` procura no diretório
  corrente antes do PATH. Exige plantar binário na máquina. Correção possível:
  resolver o `git` por `shutil.which` uma vez e chamar pelo caminho absoluto.
- **143.** **`filter=lfs` + `.lfsconfig` no restore** (`BAIXA` 3 do
  `security-reviewer`, r4). Com git-lfs instalado, uma árvore restaurada pode
  fazer o checkout buscar num `lfs.url` escolhido por quem controla o bundle.
  É requisição de rede, não execução local. Mesmo risco aceito do ADR-0013
  (integridade da nuvem).
- **144.** **Redação da cauda do smoke só por valor de AMBIENTE** (`BAIXA` 4
  do `security-reviewer`, r4). Desde a r5 cobre as formas JSON e URL e o campo
  `erro`. Continua não cobrindo segredo lido de arquivo (`machine.yaml`, cofre)
  e codificações menos comuns, como base64.
- **145.** **Contratos do registry contra o disco** (`qa-reviewer`, r4,
  INCONCLUSIVO). O revisor não alcança as pastas dos projetos. Desde a r5 há a
  evidência `artifacts/review/registry-vs-disco.txt`: para cada contrato, a
  existência dos arquivos declarados. **Quem a gera não é o coletor**, e sim uma
  ferramenta do journal (`RUN-20261008-001/tools/registry_vs_disco.py`, fora do
  repositório), apontado pelo QA na r5. O passo certo é virar comando do motor
  (`eos audit-registry`) e o coletor chamá-lo. Não dá PASS falso: o motor confere
  o disco de novo em tempo de execução.
- **146.** **`segredos_no_historico` sem `-z`** (`BAIXA` 1 do `qa-reviewer`,
  r5). Um caminho com TAB, aspas ou `\` (commit feito em Linux ou WSL) sai
  entre aspas no `git log`, e então `.env"` não casa com a regra. Correção:
  `-z` e separar por `\0`, como o `wip()` já faz.
- **147.** **`allowed_paths` aceita nome de cofre real** (`BAIXA` 1 do
  `security-reviewer`, r5): `token.json`, `credentials.json`, `secrets.toml`
  e `cookies.txt` são da família da palavra e passam na validação. Correção:
  recusar ali extensão de dado (`.json`, `.toml`, `.yaml`, `.ini`, `.txt`,
  `.csv`), ou varrer o conteúdo do caminho declarado a cada backup, falhando
  fechado. Hoje a conferência do conteúdo é humana.
- **148.** **Redação não cobre o escape `\u00XX` do PS 5.1** (`BAIXA` 2 do
  `security-reviewer`, r5). O `ConvertTo-Json` escapa `'`, `<`, `>` e `&`
  como `\u0027` etc. Além disso, a saída do smoke é decodificada como UTF-8,
  mas o PS 5.1 escreve em OEM, então um valor com acento não casa. Correção:
  somar essas formas, com um caso que tenha `'` e `&` no valor.
- **149.** **`islink` não vê junção NTFS** (informativo do `qa-reviewer`,
  r5). Não há vetor: o restore não consegue criar junção, e o `realpath` a
  resolve. Mas a docstring de `restore.py` ("sem symlink no trajeto") promete
  mais do que a checagem entrega.
- **150.** **Intent-to-add apagado do disco não é restaurável** (`BAIXA` 3 do
  `qa-reviewer`, r6). Status `' D'` sem o arquivo: cai em `removidos`, e o
  destino não tem o caminho no índice. Falha **fechada** (o restore não se
  declara ok), provado pelo `test_r7` caso 05. Corrigir exige distinguir o
  `-N` apagado de um rastreado apagado (flag do índice).
- **151.** **Manifestos anteriores à r7 com renomeação STAGED ou com `-N`**
  (consequência da r7, `BAIXA` 1 do `qa-reviewer`). (a) Com `--no-renames`,
  `R  novo\0velho` passa a pôr `velho` em `removidos`. (b) A impressão soma
  `intencao\0<caminho>` para todo intent-to-add, então **qualquer** manifesto
  do motor r6 tirado de árvore com `git add -N` (ex.: o backup do G2 de
  2026-10-11 18:54) falha a verificação no restore com o motor r7, mesmo tendo
  sido restaurado certo. Nos dois casos a falha é fechada e some com um backup
  novo. Manifestos sem `-N` e sem renomeação staged têm impressão idêntica.
- **152.** **Endurecimentos opcionais do `security-reviewer` (r7, BAIXA).**
  `diff --cached` do backup com `--no-renames` (coerência com o status; hoje
  não muda exposição); recusar controles C1 e bidi (U+0080–U+009F, U+202E) em
  `_caminho_seguro` (só engano visual em log, a contenção não quebra).
- **153.** **Smoke do Dashboard: escopo do L6 e pasta nos caminhos de falha**
  (`BAIXA` 1 e 2 do `qa-reviewer`, 1 e 2 do `security-reviewer`, r7b). O L6 do
  Dashboard certifica "ambiente reconstruível + testes que dispensam a fonte"
  (as 4 guardas puras e o resto sem a fonte), **não** o pipeline sobre a fonte
  real, que só o `test_command` na máquina de trabalho cobre. Se `venv`/`pip`
  falharem, a pasta vazia `%TEMP%\eos-fonte-vazia-<guid>` fica (só acúmulo).
- **154.** **Redação da cauda do smoke com saída em cp1252** (`BAIXA` 3 do
  `security-reviewer`, r7b, no motor). `portability.py` lê a saída como UTF-8
  com `replace`; um valor de ambiente com acento impresso em cp1252 chega com
  `U+FFFD` e não casa com a redação. Correção: rodar o smoke com `PYTHONUTF8=1` e
  decodificar pela página de código do console, somando as duas formas.
- **155.** **Certificado fora do coletor** (`BAIXA` 3 do `qa-reviewer`, r7b).
  A evidência decisiva da Fase 8 (o JSON do certificado no Drive) é anexada à
  mão. O `collect-diff.ps1`, ou um coletor de certificação, deve anexá-la com hash.
- **156.** **`security-scan.ps1` aborta com nome de arquivo não-ASCII** (achado em
  2026-10-11 no `prog-gerador-dossie`: `CAPAS/CAPA DOSSIÊ.docx`). `Invoke-Git ls-files`
  roda sem `-z` e sem `core.quotepath=false`; o Git devolve `"CAPAS/CAPA DOSSI\303\212.docx"`
  entre aspas e o `Join-Path` falha com "Caracteres inválidos no caminho". Falha FECHADO
  (nada é declarado limpo), mas o repo fica sem varredura. Contorno usado: `git config
  core.quotepath false` no repo (local; o relatório sai com o nome em mojibake de cp850, mas
  varre). Correção: `ls-files -z` decodificado como UTF-8 em todas as chamadas, com teste
  de nome acentuado.
  **CORRIGIDO em 2026-10-12** (commit `2313a1c`). Toda listagem de caminho dos detectores
  (`ls-files`, `--others`, `diff --cached --name-only`, `rev-list --objects`,
  `log --find-object --name-only`, `check-ignore -v`) passa por `Invoke-GitCaminhos`
  (`scan-comum.ps1`): `-z` + `core.quotepath=false`, stdout lido em bytes e decodificado como
  UTF-8 sem depender da codepage do console. Achados da reprodução que entraram junto:
  `check-ignore` só aceita `-z` com `--stdin`, e o .NET Framework emite BOM no stdin quando o
  console está em UTF-8 (sentinela por lote); `Sort-Object -Unique` e `-contains` tratavam
  nomes NFC e NFD como iguais e descartavam o arquivo com o segredo (agora deduplicação
  ordinal); `Test-Path` sem `-LiteralPath` errava em nome com colchete. Testes:
  `tests/suites/scanner.ps1`, casos `nomes (item 156): ...` (5) — falhavam em `16f611e`
  com exit 2 "Caracteres inválidos no caminho". **Resíduo no coletor, CORRIGIDO no mesmo
  dia:** `collect-diff.ps1` listava caminhos sem `-z` e abortava igual (reproduzido: exit 2);
  agora usa `Invoke-GitCaminhos` (`-z`), `Get-CaminhosUnicos` (ordinal), `Test-Path
  -LiteralPath`, e transcreve status/stat/diff em UTF-8 sem citação octal (`Get-LinhasGitUtf8`)
  — isso também fecha o item 87 (mojibake na seção `## git diff`). Caso novo em
  `tests/suites/collectors.ps1` ("nome NAO-ASCII nao aborta a coleta"); collectors+agents+fluxo
  118/0. **Resíduo aberto (baixo):** o `Resolve-RaizDoRepositorio` (doctor/hooks) lê
  `rev-parse --show-toplevel` pela codepage do console; raiz de repositório com acento não foi
  provada (nenhum repo do portfólio tem acento na raiz).
- **157.** **O scanner grava `artifacts/review/` dentro do repo-alvo mesmo quando
  `artifacts/` não é ignorado lá** (`prog-organizacao-sharepoint`, 2026-10-11): o relatório
  vira arquivo não rastreado no WIP da mantenedora. Contorno: relatório movido para o journal.
  Correção: quando `artifacts/` não estiver ignorado no alvo, gravar fora (`-Out` padrão no
  journal/temp) e dizer onde.
  **CORRIGIDO em 2026-10-12** (commit `2313a1c`). Sem `-Out`, o scanner pergunta ao Git
  (`check-ignore -q artifacts/review/security-report.md`): ignorado → lugar de sempre (caso da
  plataforma); não ignorado → `%TEMP%\emmily-os-scan\<repo>-<data-hora>\security-report.md`,
  impresso no console e registrado na tabela de lacunas do próprio relatório; código ≠ 0/1 →
  exit 2. `-Out` explícito continua respeitado (e o `MEDIA` de destino não ignorado continua
  valendo nele). Testes: casos `destino (item 157): ...` (3) em `tests/suites/scanner.ps1` —
  o de alvo sem `.gitignore` prova `git status --porcelain` idêntico antes/depois e falhava em
  `16f611e` com `?? artifacts/review/security-report.md`.

**A contagem de mutações desta subfase foi refeita de propósito.** Eu havia
somado "20 do lote 1 + 12 do lote 2 = 32", e o `qa-reviewer` mostrou que isso
não é uma medição: o lote 1 rodou em 2026-10-02, **antes** das correções da
rodada 1, então os dois números descrevem estados de código diferentes. O lote
consolidado roda sobre a árvore atual. A contagem dele vive na tabela acima, e só nela.

#### Resíduo de mutação, e a rede de proteção que nasceu dele

**Três** execuções do mutador foram interrompidas no meio — uma pelo
desligamento da máquina, duas pelo limite de tempo do processo em segundo
plano. As três deixaram **código mutado no disco**, porque o `finally` que
restaura nunca chegou a rodar.

Nas duas primeiras a recuperação foi por varredura de padrões conhecidos,
escritos à mão. Isso é a mesma classe de defeito que esta subfase passou
corrigindo: **uma rede de proteção mais estreita que o nome dela**. Uma mutação
cujo padrão eu esquecesse de listar passaria em silêncio, e o código desarmado
seria commitado como se fosse bom.

O mutador foi reescrito: antes de tocar no arquivo, o original vai para backup
**fora do repositório** e um manifesto registra caminho e SHA-256; ao iniciar,
manifesto não vazio significa que a execução anterior morreu, e os arquivos são
restaurados **a partir do backup**, não de padrão. Na terceira interrupção o
mecanismo funcionou: a execução seguinte imprimiu `restaurado (OK)` e seguiu.

O `.bak` é apagado só **depois** de o SHA conferir — recomendação do
`security-reviewer`, porque o manifesto era esvaziado e a cópia ficava para trás
sem prazo.

#### Para retomar, nesta ordem

Este roteiro **já esteve desatualizado** e mandou repetir trabalho de duas
rodadas atrás — foi achado de revisão. Ele agora descreve o ciclo, e não um
ponto do ciclo: o ponto está na tabela acima.

1. **Varrer resíduo de mutação antes de confiar na árvore.** Rode o mutador:
   se o manifesto não estiver vazio, ele restaura a partir do backup e diz o
   que restaurou. Não confie em varredura de padrão escrita à mão — foi assim
   que duas interrupções quase passaram despercebidas.
2. Suíte completa, `plugin validate`, `/os:doctor`.
3. Lote consolidado de mutações (`artifacts/review/ferramentas/mutar.py 27`),
   em blocos de **cinco** — o processo em segundo plano é morto aos 30 minutos,
   e a suíte ficou mais lenta depois dos casos de CONTRATO, que rodam o coletor
   e o scanner de verdade. Depois, gere o artefato com
   `ferramentas/montar-mutacoes.py`, que **conta** os números das saídas: não
   edite `mutacoes-27.md` à mão, porque ele é regerado por cima.
4. **Recoletar** `diff-report` e `security-report` sobre a árvore atual. A
   evidência carimbada com outro estado não vale.
5. Briefings da rodada seguinte em `artifacts/review/brief-27-r<N>-{qa,sec}.md`,
   citando o que a rodada anterior achou e o que foi feito.
6. QA + Security em paralelo. Aplicar a regra de encerramento de 2026-09-14.

O que **não** pode se perder, se as ferramentas sumirem: **ausência da linha de
resumo da suíte é EXECUÇÃO INVÁLIDA, nunca sobrevivência**, e a mutação só
morre se os casos **esperados** falharem.

## Programa vNext — fase final (F10): o que entrou depois da r9

Registrado aqui porque só existia em commit e conversa (achado A4 do QA na r9).

- **`eos mirror <id>... | --todos`** — espelha os `data[]` com `policy: cloud-mirror` em
  `<drive_root>/dados/<path>`: cópia aditiva, versão anterior preservada em `dados-anteriores/<ts>/`,
  conferência de tamanho e md5 depois da cópia, manifesto `mirror-<ts>.json` + journal da máquina.
  Desde a r10: entrada com `decisao_pendente: true` nunca sobe (e o check a acusa); arquivo de texto
  ≤ 2 MB com credencial no conteúdo é recusado; o manifesto não grava caminho absoluto.
- **`eos secrets-push|secrets-pull|secrets-status <id>`** — `.env`/`.env.local` no Bitwarden (Secure
  Note `emmily-os/<id>/<arquivo>`), valor só por stdin do `bw`, manifesto `cofre-<ts>.json` só com
  nomes e sha256. Login/unlock é H1. Desde a r10 o push é atômico na leitura (tudo validado antes da
  primeira escrita) e, se o cofre já mudou quando algo falha, fica um manifesto `incompleto` que o
  check acusa.
- **Convenção `refs/preservado/*`** — ref local deliberada que protege conteúdo que não pode ir ao
  remoto (caso real: stash órfão do Semanal anterior à sanitização). Não conta como "não publicada",
  viaja só no bundle do `eos backup`; desde a r10 o restore a traz do bundle e restore/certificação
  reprovam se faltar, e o hook `pre-push` recusa enviá-la.

### Rodada r10 (2026-10-15) — achados da revisão r9 → correção

Branch `vnext-r10` (worktree `eos-r10`), cada achado com teste que falhava antes:

| Achado | Correção |
|---|---|
| QA-A1 `refs/preservado/*` fora do restore | fetch `+refs/preservado/*` do bundle (também com fonte github); a verificação de refs a inclui |
| QA-A2 push do cofre parcial | leitura/decodificação de tudo antes de gravar; manifesto `incompleto` que o check acusa |
| QA-A3 `provenance_file` como glob | pathspec `:(exclude,literal)`; erro do git = `state` UNKNOWN; contrato recusa absoluto/`..`/glob |
| QA-A4 STATE desatualizado | esta seção; `FINAL-ACCEPTANCE.md` declarado como futuro |
| A5/S-A7 redação do cofre | forma escapada em JSON e valores de 1–3 caracteres como token isolado |
| S-A1 espelho de dado com DECIDIR | `data[].decisao_pendente` no contrato; mirror recusa, check acusa `dado com decisao pendente: <path>`; marcadas as entradas DECIDIR dos dois contratos Escritório Jurídico (os dados já subidos em 2026-10-12 continuam no Drive: apagar é decisão da titular, gate H4) |
| S-A2 certificado de ownership | caminhos e e-mails redigidos em `checks[*].fatos`, motivos, `ownership` e `remote` |
| S-A3 guarda AST | refspec de deleção, flags combinadas em push, abreviação de long option, `gh` por `shutil.which`/variável/argv em lista |
| S-A4 `eos new` com lacuna | lacuna em *Lacunas DESTA execucao* = falha fechada (permissão explícita só para as lacunas de precisão do `.gitignore` do template e o blob vazio por identidade) |
| S-A5 pre-push | recusa `refs/preservado/*` (local ou remota) antes da política, inclusive com `nenhum` |
| S-A6 espelho | conteúdo varrido por padrões de credencial; `aninhados` sem caixa no Windows; sem caminho absoluto no manifesto |
| lacuna do QA | `vnext.ps1` imprime a linha de resumo do `unittest` |

### Rodada r11 (2026-10-15) — achados da revisão r10 → correção

Branch `vnext-r11` (worktree `eos-r11`), testes em `eos/tests/test_r11.py`; cada correção de código
com teste que falhava no motor da r10 (QA7 é cobertura nova sobre código que já estava certo):

| Achado | Correção |
|---|---|
| QA1/Sec1 pendente contornado por aninhamento (bloqueante) | `mirror.separar`: alvo `cloud-mirror` igual ou dentro de caminho pendente (qualquer policy) vira `decisao-pendente`; `aninhados` exclui todo filho pendente do inventário do pai; comparação normalizada (`validar_path` + `_caixa`) |
| QA2 `restore --com-dados` com falso FAIL | entrada `decisao-pendente` do espelho pulada com `[ok] dados '<path>': decisao pendente, nao restaurado`; o teste herdado foi substituído em `test_r10.py` |
| QA3 / QA4 docs | guia 08: rc 2 quando todas as pastas estão pendentes (e no `--todos`); Technical Reference: `ok` inclui `decisao-pendente` |
| QA5 STATE | data e linha de testes atualizadas; esta seção |
| QA6 manifesto `incompleto` que não grava | a exceção original ganha "cofre alterado sem manifesto: refaça o secrets-push" |
| QA7 cobertura | restore `fonte=github` (remoto bare local) traz `refs/preservado/*` do bundle; `_ultimo_commit_epoch` com rc≠0 |
| achado novo (ao cobrir QA7) | restore com histórico vindo do remoto só criava a branch padrão: repositório com mais de uma branch reprovava "refs locais iguais ao manifesto" com `fonte=github`. Agora o clone é seguido de `fetch origin +refs/heads/*:refs/heads/*` (e tags) no clone recém-criado |
| QA8/Sec7 Cérebro `data/backup` | nota reescrita sem "DECIDIR": espelho mantido (conservador), poda só com decisão da titular; sem `decisao_pendente` |
| Sec2 varredura de conteúdo | leitura com `OSError` = recusa; UTF-16 (com e sem BOM) decodificado e varrido; padrões de string de conexão e URL `esquema://usuario:senha@`; limite declarado (docstring + guia 08): > 2 MB e binário sobem sem varredura |
| Sec3 redação do cofre | JSON do item e sua forma base64 (a entregue ao `bw`), e cada linha de valor multilinha (PEM) |
| Sec4 `erro` do manifesto de espelho | `paths.redigir_caminhos`: raiz do projeto → `.`, pasta do usuário → `~` |
| Sec5 redação da home no certificado | sem distinção de caixa no Windows e pelo nome curto 8.3 (`GetShortPathNameW`, falha silenciosa) |
| Sec6 guarda AST | `shell=` diferente de `False`, `os.system`, `os.popen`, `subprocess.getoutput` em qualquer lugar; `--no-verify` (e abreviações) e `-n` em push. O motor não tinha ocorrência |


### Rodada r12 (2026-10-15) — achados da revisão r11 → correção

Branch `vnext-r11` (worktree `eos-r11`), testes em `eos/tests/test_r12.py` (e `test_guardas.py`
para Sec4); cada correção com teste que falhava no motor da r11 (`09cc35d`):

| Achado | Correção |
|---|---|
| QA-A1 restore pulava `decisao-pendente` só pelo manifesto (bloqueante) | `_planejar_dados` só pula se o **contrato atual** também tem o path pendente (`mirror.separar`, comparação por `_caixa`); senão é "sem cópia verificada" e reprova — titular que já decidiu, ou manifesto adulterado, não vira `[ok]` |
| QA-A2/Sec1 path inválido descartado em silêncio | `data[].path` inválido em qualquer entrada: `_pendentes_norm`/`aninhados`/`separar` levantam `MirrorErro` (antes de qualquer envio), o check o acusa como motivo, e `contract.validar` recusa `data[].path` inválido. `motivo_caminho_relativo` e `validar_path` recusam componente terminado em espaço ou ponto. Os 29 contratos do registry continuam válidos |
| QA-A3 redator do cofre | `CHAVE="v" # comentario` não abre bloco multilinha; dentro de um bloco, `CHAVE=valor` tem o valor extraído |
| QA-A4 STATE | linha de testes com a coleta da r11; esta seção |
| Sec2 redação com ponto final | `redigir_caminhos` redige `...\Ana.` em fim de frase; `.bak` continua outro nome |
| Sec3 certificado com caminho da máquina | o cert gravado na nuvem passa por `paths.redigir` (recursivo): `%TEMP%` e pasta do usuário redigidos; o retorno de `certificar` mantém o `destino` real |
| Sec4 guarda AST | alias de `subprocess`/`asyncio`, `from subprocess import` e `from asyncio import`, `asyncio.create_subprocess_*`, `os.spawn*`/`posix_spawn*`/`exec*`/`startfile`, literal `core.hooksPath` em argv executado. O motor não tinha ocorrência |
| Obs. `.gitignore` | `.claude/worktrees/` ignorado na raiz |

### Rodada r13 (2026-10-15) — polimento dos achados da revisão r12

A revisão r12 aprovou (QA e Security, só BAIXA). Branch `vnext-r11`, testes de código em
`eos/tests/test_r13.py`: 7 dos 9 casos falham no motor da r12 (`a9e8764`); 2 são pares de
não-regressão. Recoleta do Lead sobre `71442ac` (números no cabeçalho), security-scan ALTA 0. **Revisão r13: QA APROVADO e Security APROVADO** (só BAIXA; os de documentação corrigidos em `833a1a7`).
Integrada: merge `bac545c` em `vnext`, `main` por fast-forward, publicadas e verificadas no GitHub.

| Achado | Correção |
|---|---|
| S1 cert cortado antes de redigir | `cauda` e `erro` do certificado passam por valores de ambiente **e** `redigir_caminhos` antes do corte (2000/500) |
| S2 chave de dict | `paths.redigir` redige também as chaves `str` |
| S3 / obs. QA-a guarda AST | acusa `core.hooksPath` em qualquer literal e `GIT_CONFIG*` como literal ou nome de argumento; a docstring declara o que não cobre (config do git por ambiente sem literal, import/`getattr` dinâmico, `ctypes`/`_winapi`, `loop.subprocess_*`, `pty.spawn`, `multiprocessing`). O motor não tinha ocorrência |
| S4 scanner | `.manifest` é extensão de texto (`scan-comum.ps1`): o `cofre.manifest` passa a ser lido; só com nomes, não gera achado |
| QA2 docs | Technical Reference (§5.14, §7.2, §9.3, §14.2) e guia 08: restore pula pendente só com o contrato, path inválido falha fechado, cert gravado redigido |
| QA3 cofre | valor extraído vazio ou só `=` (padding base64 de PEM) não é segredo |
| QA4/QA5 | continuação de linha no guarda; `except MirrorErro` inalcançáveis removidos de `motivos_so_aqui` |
| QA1 STATE | cabeçalho com a coleta da r12; esta seção |

### Fechamento do programa (2026-10-15/16)

Registrado em `docs/FINAL-ACCEPTANCE.md`: plataforma L6 SAFE, 22/22 PROJECT em L6 SAFE, prova real do `eos new`
(`lab-prova-eos-new`, L6 no nascimento), retomada em sessão limpa aprovada, espelhos concluídos, Fase 9 parcial
(≈ 4,2 GB liberados com prova). **Programa NOT COMPLETE** só por gates da titular/ambiente (H4 dados Escritório Jurídico, H2
permissões negadas, H1 GF e rclone, evidência externa, NEEDS_VERIFICATION). Seguro para trabalho normal.

A verificação final na worktree `main` (sobre `3af7c96`) achou 1 falha que as coletas na worktree `vnext` não viam:
`tests/suites/scripts.ps1` varria `.claude/worktrees/` (worktrees de agente) e contava 6 cópias do marcador de
isenção. Corrigido em `0130221` (exclusão em `scripts.ps1` e `docs.ps1`); recoleta completa em `main` sobre
`0130221` (números no cabeçalho), security-scan ALTA 0, `eos certify` L6, check L6 SAFE com três SIM.

### 2026-10-16 — decisões da titular e execução

Decisões da titular sobre os gates do `FINAL-ACCEPTANCE` (journal `RUN-20261008-001/SURGE/decisoes-20261016.md`),
executadas no mesmo dia. Evidência: `EVENTS.jsonl` de 2026-10-16 e `CHECKPOINTS/` do journal.

1. **rclone com client OAuth próprio.** Projeto Google Cloud `emmily-os-rclone`, app `Emmily OS rclone` em
   **In production** (homepage e privacidade em `https://emmilymaciell.github.io/emmily-os-oauth-pages/`, exceção
   pública do ADR-0019). Client ID/secret só no Bitwarden (item `rclone-gdrive-oauth-client`) e no `rclone.conf`
   local. O remoto continua `gdrive:` (código e `machine.yaml` inalterados); `gdrive-legacy` (client compartilhado)
   **removido**. Leitura, escrita controlada, backup, certify (restore) L6 e mirror testados sem o aviso do client
   compartilhado (`CHECKPOINTS/rclone-own-*`). Rollback: `~\.emmily-os\rclone.conf.bak-20261016` (local, fora de
   Git/OneDrive; tem tokens). **Verificação residual:** em 2026-10-23 ou depois, `rclone about gdrive:` sem pedir
   login. Docs: ADR-0013 (emenda), `docs/user/02`, `08`, `09`, `12`, `14`, `15`, `docs/runbooks/maquina-nova.md`,
   `docs/SETUP.md`, referência técnica. O `cofre.manifest` lista o item pelo nome `RCLONE_GDRIVE_OAUTH_CLIENT`
   desde `0b43992` — são quatro nomes (`GITHUB_AUTH`, `RCLONE_GDRIVE_TOKEN`, `RCLONE_GDRIVE_OAUTH_CLIENT`,
   `CLAUDE_CODE_OAUTH`).
2. **H4 Escritório Jurídico decidido: MANTER** os dados no Drive pessoal. `decisao_pendente` removida dos contratos; Dashboard
   e Repositório Jurídico com mirror, backup e certify L6, check L6 SAFE com três SIM.
3. **GF: SWITCH feito.** A instância de uso passou a ser o repositório; a base (641/641 registros DEMO) foi conferida
   pelo Backup da Base feito pela titular; backup, certify L6 e check L6 SAFE com três SIM. Cópia bruta do IndexedDB
   do navegador no Drive (7/7 sha256, origem preservada). A pasta antiga em Downloads ficou redundante e não foi
   apagada.
4. **Fase 9 completada no que o H2 liberou** ("autorizo H2", 2026-10-16): 35 worktrees redundantes removidas (G2 28,
   Cérebro 7; cada uma limpa e com HEAD igual ao `origin`; 6 KEEP no G2 por WIP ou junção `.venv`); E3 (duplicata da
   engenharia-rodoviaria em `02 PERSONAL`) na lixeira do Drive após `check` 234/234; D1 47 + D6 18 cópias e o exe do
   Gerador removidos com sha256 recalculado no momento; D4 PDFXEdit KEEP (SOFTWARE/TOOL).
5. **engenharia-rodoviaria:** o e-mail de 28/08 fica `EXTERNAL_EVIDENCE_PENDING_VERIFICATION` e não invalida
   ownership, provenance nem certificação. O nome de terceiro no registry foi aceito por exceção (ADR-0010, emenda de
   2026-10-16).
6. **Guarda `PreToolUse` contra git destrutivo** (`hooks/guarda_git.py`, plugin `0.1.4`; `docs/runbooks/hooks.md`):
   implementado em resposta ao incidente da r13 e **ativo desde 2026-10-16** (integração na `main` por fast-forward, `claude plugin update`,
   teste ao vivo em sessão nova: `git checkout --` bloqueado com o arquivo intacto, `git status` sem mensagem). Com o
   marketplace de diretório, o guarda que roda é o arquivo da worktree principal. Rodadas de revisão do guarda
   (vereditos completos no journal, `SURGE/revisao-r14-r16-achados.md`):
   - **Rodada 1, sobre `9f248ca`:** QA **REPROVADO** — falso negativo em PowerShell com `-ExecutionPolicy Bypass`
     antes de `-Command`, registro desatualizado (`plugin.hooks: 0`) e risco de o Python sair `2` com o arquivo do
     hook ausente, travando todo comando; Security **INCONCLUSIVO**.
   - **Correção `4a4508f`:** invólucro que sai 0 sem o arquivo, opções de shell com valor, dialeto por ferramenta,
     registro (`hooks: 1`).
   - **r14, sobre `0b43992`:** coleta completa (números no cabeçalho), `unittest` 371 OK,
     security-scan completo ALTA 0. Security **APROVADO**; QA **REPROVADO só por registro** — `plugin.json` em
     `0.2.0` contra o ADR-0006, `cofre.manifest` descrito com três nomes, rodadas não registradas — e por
     endurecimentos BAIXA do guarda (`checkout -B`, `switch -C`, valor colado em opção do PowerShell, `-euo` do
     bash, falsos positivos de flag curta).
   - **r15:** plugin `0.1.1` com emenda do ADR-0006, quatro nomes do cofre, este registro e os
     itens BAIXA do guarda com teste. Coleta r15 sobre `de2c933`: suíte completa verde, `Ran 371 tests ... OK (skipped=1)`;
     security completo ALTA 0. Revisão r15: Security APROVADO (BAIXA no pré-filtro de `-EncodedCommand`); QA
     REPROVADO só por registro (CHANGELOG ainda com plugin `0.2.0`; TECHNICAL-REFERENCE com três nomes do cofre)
     e dois falsos negativos BAIXA (`branch -t -f`, `pull --gpg-sign -r`).
   - **r16 (orquestrador):** CHANGELOG e TECHNICAL-REFERENCE corrigidos; `-t` de branch e `--gpg-sign`/`--squash`
     deixam de consumir o token seguinte; pré-filtro aceita `-EncodedCommand` entre aspas e com `--`; payload
     UTF-16 inválido decodificado com substituição; 6 casos novos, todos liberados pela versão `de2c933`.
     Coleta r16 sobre `5d32fcc`: suíte completa verde, `Ran 371 tests ... OK (skipped=1)`; security completo ALTA 0;
     histórico sem formato de client OAuth do Google. Revisão r16: Security APROVADO; QA APROVADO no código e
     REPROVADO só por registro (manuais e STATE citando rodadas como pendentes).
   - **r16b/r16c (só documentação, `29a29e8` e seguinte):** os manuais remetem ao STATE em vez de citar rodada; o
     STATE registra cada rodada pelo resultado, e o próximo passo deixa de nomear a rodada de revisão. O código
     é o da r16 (coleta acima).
   - **Teste ao vivo depois do merge:** o `0.1.1` bloqueava em modo de fallback (sem `shell`, sem Git Bash, qualquer
     saída != 0/2 bloquearia); o `0.1.2` (`shell` PowerShell) **deixou passar** um `checkout --` no repositório
     descartável de teste, porque `powershell -Command` devolvia 1; o `0.1.3` propagou o código de saída.
   - **r17, sobre `21b66ff`:** Security REPROVADO (argumento sem unidade resolvia para a raiz do drive, consultado
     antes do guarda legítimo); QA REPROVADO só por registro (falha aberta silenciosa não declarada, diagnóstico
     errado). Correção `9400685` (`0.1.4`): ambiente primeiro, argumento só absoluto com unidade, exceção no stderr.
   - **r18, sobre `9400685`:** Security **APROVADO**; QA APROVADO no código e REPROVADO só por registro (o guarda
     ativo é o da worktree principal, não a cópia do cache). Correção `d6d85ce` (r18b, docs e um teste).

## Próximo passo

**Programa vNext COMPLETE (2026-10-16)** — `docs/FINAL-ACCEPTANCE.md`. Feito no fechamento: integração na `main`
(fast-forward) e push, guarda de git ativa (plugin `0.1.4`, revisões r14–r18, teste ao vivo), plataforma recertificada **L6 SAFE**.
Depois do commit desta aceitação, o journal registra o push, o backup, o check e a sessão limpa sobre o HEAD
final (`EVENTS.jsonl`, eventos `pos-aceitacao*` e `sessao-limpa-final*`).

1. **Trabalho normal de projeto.** Cada projeto segue o próprio STATE.
2. **Em 2026-10-23 ou depois:** `rclone about gdrive:` sem pedir login (token do client próprio não expirou); se
   ok, revogar a concessão antiga na conta Google e apagar `~\.emmily-os\rclone.conf.bak-20261016`.

Paralelo, sem bloquear: backlog BAIXA (lista em `docs/FINAL-ACCEPTANCE.md`, "Fatos de processo") numa rodada futura com revisão.

## Histórico do próximo passo — programa vNext, Fase 3 (core) e Fase 4 (a plataforma em L6)

**A 2.7 está encerrada** (2026-10-08): os dois revisores aprovaram, e os
`BAIXA` restantes são o backlog 130 a 134.

Em 2026-10-08 a mantenedora entregou o **programa vNext** (texto integral em
`docs/vnext/PROGRAMA-VNEXT.md`), e as decisões dele estão no **ADR-0012**
(ordem e autonomia), **ADR-0013** (Google Drive como plano de dados e
recovery) e **ADR-0014** (motor `eos` em Python stdlib, registry YAML,
níveis L0–L6). **O andamento vive em `docs/vnext/EXECUCAO.md`, e só lá** —
gates, fases, o que a preservação cobre e o que não cobre, e como retomar.

**Autorização registrada:** o programa autoriza commit e push **não
destrutivos** sem pedido a cada vez, desde que o conteúdo tenha sido revisado,
os portões previstos tenham passado, a varredura de segredo esteja limpa e o
remoto seja o validado. Isso **não** revoga as proibições: `reset --hard`,
`clean`, `rebase`, `amend`, `push --force`, descarte de branch/worktree e
qualquer exclusão continuam exigindo pedido explícito (gate H3).

**A 2.8 (CI) e a 2.9 (evals) não foram canceladas**: entram depois da Fase 4
do programa (ADR-0012, item 1).

### Itens 26, 30 e 11 fechados — 2026-09-17

Os tres eram o que o proprio estado marcava como obrigatorio antes da 2.5. Nenhum era melhoria: os
tres tinham direcao de falha **falso verde ou guarda inerte**, que e a unica classe que a regra de
2026-09-14 trata como bloqueante fora de `ALTA`.

#### Item 11 — a leitura `UTF8` dos detectores

**Corrigido, nao declarado como teto.** `scan-comum.ps1` ganhou `Read-TextoDeArquivo`, e os leitores
de conteudo passaram a usa-la: os quatro detectores, o leitor do `project.yaml` das excecoes, o
leitor do `.git/config` da guarda de remoto, o carimbo de linhas e o coletor de diff.

**O que a correcao tem de diferente do que o item prescrevia, e e o achado desta rodada:** o item
pedia leitura estrita — `UTF8Encoding($false, $true)` — e dava como cenario o arquivo em **UTF-16
sem BOM**. *A leitura estrita sozinha nao pega esse cenario.* UTF-16LE de conteudo ASCII e UTF-8
**valido byte a byte** — `A` vira `41 00`, e `U+0000` e code point legitimo —, entao a leitura
estrita passa e devolve o texto com um NUL entre cada letra, que e exatamente o que quebra todo
regex de credencial. Medido, nao suposto.

Por isso sao **duas** recusas: byte invalido para UTF-8, e NUL no texto ja decodificado. E UTF-16
**com** BOM nao e recusado por nenhuma das duas — `ReadAllText` detecta o preambulo e decodifica
certo —, o que tambem tem caso, porque recusar arquivo legitimo e o modo de falha oposto e
igualmente caro.

**Consequencia no relatorio, que e onde o falso verde morava:** arquivo que nao da para ler como
texto deixa de entrar em `Examinados` e passa a sair como **lacuna nomeada**, com o caminho. Os
tres portoes que consomem esse fato foram ligados juntos — coluna `Coberta` das quatro areas, linha
da tabela de lacunas, acumulador do "(nenhuma)" —, porque consertar um e esquecer outro e a classe
de defeito que ja apareceu seis vezes neste arquivo.

**O que sobra como teto, e a linha do relatorio foi reescrita para dizer isso:** texto de byte unico
— Windows-1252, Latin-1 — cujos bytes por acaso formem sequencia UTF-8 valida. Ele e lido,
decodifica para caracteres errados, e um segredo com acento no meio pode nao casar o padrao. Nao ha
como distinguir isso de texto legitimo sem adivinhar a codificacao.

#### Itens 26 e 30 — a guarda de remoto vazio

A guarda tinha **dois** `throw` e nenhum par de execucao; a correcao do item 11 criou um terceiro.
Sao **tres** `throw` e **quatro** estados que os alcancam — o `throw` de `[remote` e atingido por
dois caminhos diferentes, e e a diferenca entre eles que fecha o item 30. *(A primeira versao desta
frase dizia "quatro ramos de `throw`", arredondando estado para ramo. O `qa-reviewer` conferiu
contra o codigo: ha tres. E a mesma classe de frase que esta entrega estreitou no item 11.)* Os
quatro estados agora tem caso, e o par positivo — repositorio sem remoto e sem `[remote` no
config — existe para que uma guarda que lancasse sempre nao passasse nos quatro.

| Ramo | Estado que o alcanca | Por que a fixture e essa |
|---|---|---|
| `config` declara `[remote` | secao `[remote "orfao"]` **sem nenhuma chave** | `git remote add` nao serve: com `url`, `remote -v` imprime. Secao com `fetch` e sem `url` tambem nao: `remote -v` imprime o nome e uma tabulacao, e a lista fica com uma entrada vazia |
| idem, em **worktree ligado** | a mesma secao, no config do repositorio **principal** | e o item 30: fora de worktree ligado `GitDir` e `ComumDir` tem o mesmo valor, e trocar um pelo outro e inerte |
| `Get-CaminhosDoGit` nulo | `GIT_DIR` no ambiente e `.git` local ilegivel como ponteiro | **todo hook do Git roda com `GIT_DIR`**: o git responde sobre outro repositorio enquanto a resolucao local falha |
| `config` ilegivel como texto | byte invalido acrescentado ao `.git/config` | o git tolera o byte e responde `remote -v` vazio com codigo 0 — medido |

**O item 30 e o que quase passou sem prova.** Um caso em repositorio comum deixa a escolha
`ComumDir` orfa, porque naquele estado ela e indistinguivel de `GitDir`. O caso de worktree carrega
tres pre-condicoes explicitas — `.git` e arquivo, existe config em `ComumDir`, **nao** existe config
em `GitDir` — e a terceira e a que impede o caso de ficar verde por vacuidade se alguem ligar
`extensions.worktreeConfig` um dia.

#### A prova por mutacao — quatro regressoes reintroduzidas, quatro mortas

Cada mutacao foi aplicada ao arquivo de producao, a suite `scanner` foi executada, e o arquivo foi
restaurado **por copia** — nunca `git checkout` — com conferencia por SHA-256. Os quatro
restauraram identicos.

| Mutacao | Casos vermelhos | O que a distribuicao prova |
|---|---|---|
| leitura leniente inteira (`[Text.Encoding]::UTF8`) | 4 | os tres casos de codificacao **e** o da guarda de config: o leitor novo e consumido pelos dois itens |
| estrita **sem** a recusa de NUL | 2 | so os dois casos de UTF-16 caem; o de byte invalido fica **verde**. As duas recusas sao exercitadas em separado, e nenhuma e decorativa |
| `ComumDir` → `GitDir` | 1 | **so** o caso de worktree. O de repositorio comum fica verde — que e a afirmacao do item 30, agora medida em vez de raciocinada |
| `[remote` neutralizado no regex | 2 | os dois casos que dependem dele. `GIT_DIR` e config ilegivel ficam verdes: sao ramos distintos, nao copias |

**Um erro meu no caminho, do mesmo tipo que ja esta registrado no item 31:** o script de mutacao
imprimiu "NENHUM CASO CAIU — a mutacao SOBREVIVEU" nas quatro rodadas, e era falso nas quatro. Ele
redirecionava a saida da suite com `>`, e no PowerShell 5.1 `Write-Host` escreve no *stream* 6 e
nao no de sucesso: o arquivo capturado ficou vazio, e o parser concluiu ausencia de falha a partir
de ausencia de dado. **Ausencia de evidencia virando aprovacao, dentro da propria ferramenta que
existe para provar o contrario.** Os numeros acima vem da saida real no console, conferida caso a
caso. O script nao foi versionado — continua valendo o item 31.

#### Segunda rodada — os dois revisores reprovaram, e cada um achou um defeito que o outro nao viu

A primeira rodada saiu com suite verde, `plugin validate` passando, varredura `exit 0` e quatro
mutacoes mortas. Os dois revisores reprovaram assim mesmo, com dois achados `MEDIA BLOQUEANTE`
**diferentes** — e os dois eram reais.

**O `qa-reviewer`: o BOM de UTF-8 desarmava a recusa de byte invalido.**
`[System.IO.File]::ReadAllText($caminho, $codificacao)` abre um `StreamReader` com deteccao de
preambulo ligada, e quando ha BOM reconhecido o `StreamReader` **descarta a codificacao que voce
passou**. Para o BOM de UTF-8 ele volta ao `Encoding.UTF8` estatico, que substitui em silencio.
Resultado medido: `EF BB BF 61 E7 0A` era **aceito**, com `U+FFFD` no lugar do byte, enquanto os
mesmos bytes sem o BOM eram recusados. *O falso verde do item 11, vivo dentro da correcao do item
11.* Ele derivou isso por leitura, sem executar nada — e citou como evidencia um comentario deste
proprio repositorio, em `tests/_harness.ps1`, que ja tinha medido a deteccao de preambulo e a
descrevia como feature no ramo de UTF-16. **A correcao usava como feature o mesmo mecanismo que a
desarmava no ramo ao lado.** Corrigido lendo os bytes e decidindo o preambulo explicitamente.

**O `security-reviewer`: o detector de historico ficou de fora, e a tabela de teto afirmava
completude.** A primeira passada converteu os leitores **por caminho de arquivo**; o
`scan-historico.ps1` le `stdout` do `git cat-file -p`, que e o caminho leniente, sem recusa de NUL.
A forma mais afiada do defeito, nas palavras dele: um arquivo que o working tree agora **recusa e
nomeia como lacuna**, se estiver commitado, e lido pelo historico e contado como `lido` — duas
areas relatando o oposto sobre os mesmos bytes. E o comentario ao lado justificava a leitura com
"os padroes sao ASCII, entao isso nao muda deteccao de credencial", verdadeiro para o problema de
codepage que ele trata e **falso** para o caso do NUL. Comentario errado no ponto exato do defeito
e como ele sobrevive a proxima revisao.

Corrigido com um contador `BlobsIlegiveis` costurado nos tres portoes, como as outras areas — e
com o teto declarado onde ele de fato existe: ali a recusa e por **sinal indireto** (`NUL` ou
`U+FFFD` no texto ja decodificado), porque o byte original se perdeu no console. Blob que contenha
`U+FFFD` legitimamente e recusado junto; a direcao e declarar lacuna, nunca afirmar cobertura.

**Os outros tres achados, todos aceitos e corrigidos:** contagem dupla do arquivo de CI ilegivel
(o conjunto de CI e subconjunto do de conteudo, e o numero da cobertura deixava de reconciliar com
a lista nomeada); dois `throw` novos sem par de execucao — `Measure-LinhasDoArquivo` e
`Get-ExcecoesDeSeguranca` —, a mesma classe que os itens 26 e 30 existem para pagar, abertos no
ato de paga-los; e a mensagem do segundo, que dizia o que estava errado sem dizer o que fazer.

**Onde os dois discordaram, e como resolvi.** `project.yaml` ilegivel: o `qa-reviewer` argumentou
que lancar mata o relatorio das seis areas por um problema de uma so, quando o padrao de lacuna
nomeada ja existe na mesma entrega. O `security-reviewer` defendeu lancar, porque devolver vazio
faz o relatorio **afirmar** que consultou as excecoes quando nao consultou, e mentir sobre
cobertura e pior que parar — alem de ser coerente com o `exit 2` do ADR-0009 e com a decisao ja
tomada no `Invoke-Git`. **Fiquei com o `security-reviewer`**, e o argumento decisivo e o dele: meu
veredito inteiro e construido sobre declaracoes de cobertura. A ressalva do QA sobre o raio fica
registrada, e a mensagem agora manda salvar o `project.yaml` em UTF-8 — o diagnostico que faltava.

**As quatro mutacoes da segunda rodada**, cada uma matando **exatamente um** caso, com restauracao
conferida por SHA-256: voltar ao `ReadAllText` com deteccao de preambulo mata so o caso do BOM;
remover a recusa no historico mata so o caso do blob; reincrementar o contador no laco de CI mata
so o caso da contagem dupla; voltar o coletor de diff a leitura leniente mata so o caso do arquivo
novo ilegivel.

**O que continua aberto, e esta no backlog:** a recusa no historico e mais fraca que a das outras
cinco areas, e isso esta na tabela de teto permanente do relatorio, nao so aqui. O
`bootstrap.ps1` do template continua lendo o manifesto de forma leniente — fora do escopo desta
entrega, apontado pelo `qa-reviewer` ao conferir uma frase minha que era mais larga que o fato.

#### Terceira rodada — os dois sem `ALTA` e sem `MEDIA bloqueante`, e um `INCONCLUSIVO` que era sobre evidencia, nao sobre defeito

O `security-reviewer` **aprovou** o fluxo privado, com teto declarado. O `qa-reviewer` ficou
`INCONCLUSIVO` em **cobertura**, e a frase dele e o registro que vale: *"o que me impede de aprovar
nao e defeito, e evidencia"*. Ele nomeou os dois pontos e eu paguei os dois.

**O que faltava de cobertura, e foi pago:** o leitor de `scan-gitignore.ps1` era o **unico** dos
convertidos sem par de execucao — mutar a linha de volta para `ReadAllLines` mantinha os 293
verdes. E o ramo `project.yaml` ilegivel do coletor de diff nao tinha caso negativo. Os dois
ganharam par, positivo e negativo.

**Uma regressao concreta, achada por leitura e confirmada:** com **um** elemento, a poda do fim de
linha no coletor virava `$l[0..-1]`, e em PowerShell `0..-1` e a sequencia `@(0,-1)` — devolve
**dois** elementos em vez de nenhum. Arquivo novo vazio saia com uma linha em branco transcrita
contra `0 linhas` no carimbo, que e exatamente a divergencia que faz o revisor concluir "coleta
obsoleta" com a arvore parada. Corrigido nos dois pontos: a poda trata o caso de um elemento, e o
bloco de um arquivo vazio nao escreve linha nenhuma.

**Falha de I/O deixou de ser diagnosticada como codificacao.** `Read-TextoDeArquivo` engolia
qualquer excecao de `ReadAllBytes` e devolvia `$null`, entao arquivo travado pelo OneDrive ou pelo
Excel — cenario real nesta casa pelo ADR-0002 — recebia a lacuna "nao e legivel como texto" e a
instrucao "salve em UTF-8", que nao resolve. Agora **lanca**, com a causa real na mensagem. Sao
dois fatos diferentes: "nao consegui abrir" e "nao consegui interpretar".

**O relatorio parou de afirmar mais do que entrega, em tres pontos.** A linha de modificadores
dizia "nenhum - cobertura cheia" **antes** da tabela de cobertura, com duas areas em `parcial`
logo abaixo; ela mede modificador e afirmava cobertura. O teto de codificacao dizia valer para as
"SEIS areas", e `staging` nao le conteudo nenhum. E o teto do historico era **incondicional**,
quando a recusa por `U+FFFD` so vale se a troca de `[Console]::OutputEncoding` tiver pegado — e ela
vive num `catch` silencioso, que falha sem console anexado, como num hook do Git. O relatorio agora
**registra se a troca foi aplicada** e muda a propria frase do teto conforme isso.

**O registro tambem estava arredondado:** eu escrevi "quatro ramos de `throw`" onde o codigo tem
tres — o quarto era um *estado*, nao um ramo. O `qa-reviewer` conferiu contra o codigo. Corrigido
aqui e no `CHANGELOG`, com a distincao explicita entre ramo e estado.

**E um dos casos novos passou pela razao errada — a mutacao pegou.** O caso do `project.yaml`
ilegivel ancorava a assercao em `project.yaml` seguido de "nao e legivel como texto"; acontece que o
proprio `project.yaml` da fixture e um **arquivo novo**, entao a lacuna do *outro* ramo — o que
transcreve arquivo nao rastreado — casava o mesmo padrao. Reverter o leitor do manifesto deixava o
caso **verde**. A assercao agora exige o texto especifico da lacuna do manifesto, e a mutacao
refeita mata exatamente esse caso. E a terceira vez neste projeto que a mutacao mostra um verde
apoiado no mecanismo errado, e a licao nao muda: **assercao generica aceita qualquer coisa que se
pareca com o certo.**

**O que foi registrado em vez de corrigido**, com direcao da falha declarada: item 36 (arquivo que
comeca com `FF FE` sem ser UTF-16 — rebuscado) e item 37 (sem limite de tamanho no working tree; a
direcao e segura, o **rotulo** da lacuna e que fica errado). O `security-reviewer` recomendou
`-MaxArquivoKB` simetrico ao `-MaxBlobKB`.

**A recomendacao dele que atravessa tres rodadas sem decisao continua sua:** o item 9 — o marcador
de fixture e a unica rota de rebaixamento que `-ParaPublicacao` **nao** anula, e
`tests/suites/scanner.ps1` ja passa de 2900 linhas cobertas por uma linha de cabecalho.

#### Quarta rodada — o `security-reviewer` aprovou; o `qa-reviewer` achou dois defeitos meus nos proprios testes

Nenhum `ALTA`, nenhum `MEDIA bloqueante` nas duas revisoes. O `security-reviewer` **aprovou** o
fluxo privado. Os quatro achados restantes eram todos sobre o que eu tinha acabado de escrever —
nao sobre o codigo que os itens 26, 30 e 11 pediam.

**O caso novo falharia em clone limpo, e nao por defeito do codigo que ele testa.** O
`.gitattributes` fixa `eol=crlf` para `.ps1`, entao num checkout limpo todo literal de **varias
linhas** dentro de um `.ps1` carrega `CRLF`. O meu padrao de regex era um literal de varias linhas,
e o sujeito tinha acabado de ter o `CR` removido: `-match` nao casaria, e o caso ficaria **vermelho
com o codigo correto** em qualquer outra maquina — reprovando a verificacao em clone limpo que a
propria suite testa. Corrigido com escapes `\n` num literal de **uma** linha: quem interpreta passa
a ser o regex, e nao o parser do PowerShell.

*(E o gatilho fui eu: os arquivos desta entrega estao com `LF` no disco porque os meus scripts de
edicao em Python leem em modo texto e regravam sem `CR`. O objeto no Git e o mesmo — `text eol=crlf`
guarda `LF` e entrega `CRLF` no checkout —, mas foi essa assimetria entre o meu disco e o checkout
de qualquer outra pessoa que escondeu o defeito.)*

**E a assercao POSITIVA do caso do `project.yaml` era vacua** — a mesma vacuidade que a assercao
**negativa** do mesmo caso tinha acabado de corrigir, no par oposto. Ela casava a palavra `alta`
solta; o `project.yaml` da fixture e arquivo **novo**, entao o coletor transcreve o corpo dele, e a
palavra casava a transcricao em vez da tabela de rigor. Ancorada na celula da tabela.

**O portao do `gitignore` no relatorio nao tinha par**: o contador subindo no detector nao prova que
a coluna `Coberta` cai. Dois portoes, um fato — a classe que este arquivo ja registrou seis vezes.
O caso agora roda o scanner completo e exige `| gitignore | **parcial** |`.

**E com `-SemHistorico` o teto do blob afirmava ter medido o que nao rodou.** Sem o detector,
`$rHist` e nulo e a redacao caia no ramo **afirmativo** — dizendo que a troca de
`[Console]::OutputEncoding` foi aplicada numa execucao em que nada foi medido. Mesma forma do
defeito que a rodada 3 corrigiu, deslocada para o ramo do modificador; achado do
`security-reviewer`, com a observacao de que ele **nao** bloqueava porque naquele modo a area ja sai
`INCONCLUSIVO` por outro motivo. Agora sao tres estados, com caso de execucao para o terceiro. E a
frase deixou de dizer "FOI aplicada": o que se mede e que o *setter* aceitou a troca.

### A 2.5 levou DEZENOVE rodadas de revisao independente — **encerrada** em 2026-09-22

> Registro do que a revisao encontrou e do que foi corrigido. A seção seguinte descreve o que a
> subfase **entrega**; esta descreve o que ela **custou**, que é a parte que não se aprende de novo.

**Rodada 1** — `qa-reviewer` REPROVADO, `security-reviewer` aprovado para o fluxo privado. Seis
achados, todos corrigidos na causa, com caso de regressão e **seis mutações mortas** pelos casos
certos (restauração conferida por SHA-256). Descritos na seção *A revisão independente reprovou*.

**Rodada 2** — `qa-reviewer` REPROVADO de novo, `security-reviewer` aprovado para o fluxo privado
com duas condições nomeadas. Nenhum `ALTA`. Três `MEDIA BLOQUEANTE`:

| # | Onde | O que, e por que bloqueava |
|---|---|---|
| 1 | `doctor-manifesto.ps1`, ramo de lista | **O fail-open que eu disse ter corrigido sobreviveu um ramo ao lado.** O `throw` foi posto só na chave de TOPO; dentro de item de lista a mesma regex ficou em `if ($m.Success)` **sem `else`**. Com `obrigatoria : true` — um espaço antes dos dois-pontos, YAML válido — a linha sumia, `ObrigatoriasAusentes` ficava zero, e o doctor saía **0 no lugar de 1**: a única regra `FAIL` da dimensão ambiente, desarmada |
| 2 | o leitor inteiro | **A quarta divergência com o gêmeo estava na CHAVE, não no escalar.** `^([A-Za-z0-9_\-]+):` contra `^([^\s:#][^:]*):` do gêmeo — cuja docstring diz que aceitar ponto, acento, aspas e espaço foi **deliberado**. Um `project.yaml` com chave acentuada, que é pt-BR, derrubava o doctor em duas dimensões e saía exit 2, enquanto a suíte do mesmo projeto lia o arquivo sem reclamar. Bloqueava pela **afirmação**: o cabeçalho do módulo declarava paridade que a fixture não media |
| 3 | `docs/STATE.md` | **O quarto ponto do achado 5 da rodada 1 não foi corrigido, e eu afirmei ter corrigido todos.** A linha continuava dizendo "Skills: 6" e anunciando `doctor` como trabalho **futuro**, com 7 skills no disco, `project.yaml` declarando 7 e o cabeçalho declarando a 2.5 concluída |

**Rodada 3 — o que foi feito.** Os três na causa, mais o `MEDIA` não bloqueante:

| Conserto | Causa atacada |
|---|---|
| `Split-LinhaDeChaveDoManifesto` — **uma** função decide o que é `chave: valor`, e os três sítios a chamam | a regex estava **copiada** em três lugares, e endurecer uma cópia deixou as outras para trás. Enquanto houver cópia, o próximo endurecimento repete o defeito |
| a regex passou a ser a do gêmeo, caractere a caractere, com a chave perdendo um par de aspas como lá | rigor diferente sobre o mesmo arquivo |
| a continuação de item de lista **lança** quando não é `chave: valor`; item **escalar** (`- git`) continua legítimo | por isso a função devolve `$null` em vez de lançar ela mesma: quem chama decide se `$null` é erro |
| `Test-TemHistorico` dentro de `try/catch`, como a dimensão `git` já fazia | era o **único** caminho em que o doctor saía sem gravar relatório nem JSON — contra o próprio desenho |
| a mensagem do `throw` deixou de transcrever a linha do manifesto **verbatim** para dentro do artefato | o doctor se documenta como ferramenta que não copia conteúdo do projeto. Achado do `security-reviewer` |
| a contagem de skills em prosa no STATE ganhou **detector** em `tests/suites/docs.ps1` | o registro contraditório sobreviveu duas rodadas porque nenhum teste olhava para ele |

**As mutações desta rodada morreram**, com restauração conferida por SHA-256 em todas: regex da chave de volta ao `[A-Za-z0-9_-]` (mata **dois** casos — o do espaço antes do
dois-pontos e o de paridade); continuação de item voltando a sumir em silêncio; chave deixando de
perder o par de aspas; `Test-TemHistorico` de volta para fora do `try/catch`; e a contagem de skills
voltando a divergir.

**O que a rodada 3 acrescentou de par negativo**, porque asserção sem par aceita qualquer coisa que
se pareça com a resposta certa: `obrigatoria : false` com o mesmo espaço — prova que o `FAIL` veio
do **valor lido**, e não de a dimensão reprovar toda ferramenta ausente; item de lista bem formado
e lista de escalares — provam que a regra estrita não passou a recusar YAML legítimo; o mesmo
repositório **sem** a ref quebrada saindo 0; e, no caso de paridade, a exigência de que as duas
chaves não enderecáveis tenham sido **lidas** pelos dois leitores — concordar em não ler não é
paridade.

**Rodada 3** — `security-reviewer` **APROVADO** para o fluxo privado, sem `ALTA` e sem
`MEDIA BLOQUEANTE`. `qa-reviewer` **REPROVADO**, com **um** `MEDIA BLOQUEANTE`, e ele veio como
resposta direta à minha própria pergunta *"alinhar a chave criou divergência nova?"*:

> **A quinta divergência estava no VALOR.** Em YAML a aspa escapada é a aspa **dobrada**, e
> `IndexOf` cai na primeira metade dela. Medido em execução, com os dois leitores lado a lado:
> `criterio_de_pronto: 'o relatorio diz ''pronto'''` → doctor devolvia `o relatorio diz `, **truncado, sem erro e sem lacuna**; gêmeo devolvia
> a frase inteira. Eu tinha alinhado a regex da **chave** e deixado a mesma afirmação larga sobre o
> **valor** — a forma do achado da rodada 2, um nível abaixo.

**Rodada 4 — o que foi feito.** `ConvertFrom-EscalarDoManifesto` passou a ter a estrutura do gêmeo,
em **dois passos**: o ramo das aspas só corta comentário, e tirar **um par das pontas** é de
`Get-ChaveSemAspasDoManifesto` — a mesma função que trata a chave, porque o gêmeo também usa uma
só. A fixture de paridade ganhou a forma da aspa escapada, e `criterio_de_pronto` — que estava na
fixture e **fora** da comparação — entrou nos campos comparados.

E a comparação virou **leitor contra leitor**: ela chamava `Get-CampoDoProjeto` de um lado e lia o
dicionário cru do outro. O acessor aplica política própria — campo declarado **vazio** não conta
como declarado —, então a assimetria acusava divergência onde os dois leitores guardam a mesma
string vazia. A afirmação do cabeçalho é sobre os **leitores**; o caso passou a medir isso.

**As mutações desta rodada morreram**, com restauração conferida por SHA-256. As duas da
rodada 4: o valor voltando a ser cortado na primeira aspa da dobrada (mata o caso de paridade), e o
valor deixando de perder o par de aspas (mata **cinco** casos).

**Um defeito de método, meu, que o `security-reviewer` nomeou:** eu invoquei os revisores com
*"Termine com `QA_EXIT=0`"* no pedido — entregando a resposta junto com a pergunta. Ele registrou
que decidiu por conta própria e que teria escrito `1` com a mesma naturalidade. Backlog item 53:
nenhuma invocação futura de revisor pode conter o código de saída esperado.

**Rodada 4** — `security-reviewer` **APROVADO** de novo para o fluxo privado, sem `ALTA` e sem
`MEDIA BLOQUEANTE`. `qa-reviewer` **REPROVADO** com `QA_EXIT=1`, e o achado é o de **maior raio** de
toda a subfase — outra vez respondendo à minha própria pergunta:

> **As decisões ESTRUTURAIS eram tomadas sobre o valor CRU.** `chave:` sem valor abre bloco, `[]`,
> `{}`, escalar de bloco — tudo decidido **antes** de o comentário ser cortado. O gêmeo normaliza
> primeiro. Medido em execução, com os dois lado a lado:
>
> - `verificacao:  # o que este projeto verifica` → o valor não era vazio, o ramo do bloco não
>   rodava, `verificacao` virava **String**, e `tests` e `comando` nasciam na **raiz**. Efeito:
>   `DeclaraTests` falso, **a única regra `FAIL` da dimensão manifesto desarmada**, exit 0, sem erro
>   e sem lacuna. O gêmeo lia o mesmo arquivo como Hashtable, com `tests = true`.
> - `dependencias: []   # nenhuma por enquanto` — **o idioma que o próprio template publica** —
>   virava a **string** `[]`: o doctor sondava no PATH uma ferramenta com esse nome, `Declaradas` 1,
>   `NaoSondadas` 1, dimensão `INCONCLUSIVO`, **exit 2 sobre projeto saudável**. Contra a decisão de
>   governança de que `[]` é declaração explícita válida.

**Rodada 5 — o que foi feito.** `Remove-ComentarioDoEscalar` virou função própria, e a normalização
acontece **antes** das decisões estruturais. `ConvertFrom-EscalarDoManifesto` passou a ser a
composição das duas etapas.

E o conserto **expôs a camada seguinte**, que nenhuma fixture alcançava antes: com o comentário
cortado primeiro, `criterio_de_pronto:  # preencher depois` passa a chegar **vazio** — e o doctor
abria bloco para **qualquer** valor vazio. O gêmeo abre bloco só se a próxima linha significativa
for **mais indentada**; no mesmo indent, ou sem próxima, o campo foi declarado vazio, e vazio não é
bloco. Regra copiada. Foi o caso de paridade que pegou, no mesmo ciclo.

**As mutações desta rodada morreram.** As duas da rodada 5: a estrutura voltando a ser decidida
sobre o valor cru (mata **cinco** casos) e o vazio voltando a abrir bloco sempre (mata o de
paridade).

**Rodada 5 — os vereditos, por revisor e por área.** Registrados aqui porque a convenção desta
casa, escrita na 2.4, é que subfase só vira **Concluída** nomeando quem aprovou:

| Revisor | Veredito | O que aprovou, e o que não |
|---|---|---|
| `security-reviewer` | **APROVADO**, fluxo privado, exit 0 | As seis áreas. Nenhum `ALTA`. O único `MEDIA` é a guarda de destino do `collect-diff.ps1` — **fora da delta**, e ele próprio diz que não bloqueia este repositório. Publicação continua **reprovada** |
| `qa-reviewer` | **REPROVADO** (`QA_EXIT=1`) — **só por registro** | `correção`, `regressão`, `cobertura`, `escopo` e `portabilidade` **APROVADOS**; `registro` REPROVADO. Palavras dele: *"O código desta delta, esse eu aprovo"* |

Os dois bloqueantes dele eram meus, e eram do tipo que esta plataforma existe para não repetir:

1. **Eu declarei a 2.5 "Concluída" e "fechada em 2026-09-20" antes de existir veredito.** A
   convenção está escrita neste mesmo arquivo, na 2.4: *"o repositório afirmava o resultado da
   revisão que o ciclo existia para produzir"*. Voltou para **em fechamento** nos quatro lugares e
   no `project.yaml`, e a data do cabeçalho, que estava em 2026-09-18 sobre conteúdo de 2026-09-20,
   foi corrigida — *o carimbo que denunciaria registro velho estava velho*.
2. **O `CHANGELOG` contava duas histórias**: cabeçalho e abertura na rodada 3 ("reprovou duas
   vezes"), cinquenta linhas abaixo o mesmo documento na rodada 5. O diff que acrescentou a seção
   nova editou o corpo e não tocou no cabeçalho dela.

**E o `security-reviewer` contestou a severidade de um item do backlog, com razão parcial.** Ele
disse que o item 55 não era só transcrição: `tests: true# nota` fazia `DeclaraTests` virar falso e
a única regra `FAIL` da dimensão não disparar. Medi antes de decidir: **os dois leitores devolvem o
mesmo valor, e os dois estão certos** — em YAML um `#` sem espaço antes não abre comentário. Não
era divergência nem fail-open do leitor. Mas a dimensão **calava** sobre um valor que não
reconheceu, e "declarei algo que você não entendeu" colapsando em "não declarei" é a classe que
esta subfase já fechou duas vezes. Virou lacuna nomeada — e, junto, descobriu-se que **lacuna era
decorativa nesta dimensão**: o status vinha só dos achados, enquanto `retomabilidade` já respeitava
o seu. Duas dimensões com regras diferentes para o mesmo fato, e a mais permissiva era a que guarda
a única regra `FAIL` do manifesto.

**As mutações desta rodada morreram.** O total da subfase entra **no fechamento** — escrever um
total corrente foi o que bloqueou a rodada 11 e de novo a 14, esta última **na própria rodada que o
escreveu**. Da décima em diante eu passei a aplicar **à mão**,
começando pelas duas para as quais o meu script relatou `SOBREVIVEU` e que, aplicadas manualmente,
**matam o caso**. Erro para o lado do falso alarme,
que é o lado seguro, e ainda assim é a **segunda vez** que o instrumento de mutação mente nesta
plataforma — a primeira foi o `Write-Host` indo para o fluxo 6 sem o `>` capturar. Backlog item 62.

**Rodada 6** — `security-reviewer` **APROVADO**. `qa-reviewer` **REPROVADO**, dois
`MEDIA BLOQUEANTE`, e o primeiro foi o mesmo fail-open **pela terceira vez um ramo ao lado**:
`Get-CampoDoProjeto` lança de propósito quando o valor ainda é **placeholder de instanciação** — o
estado de um projeto recém-copiado do template — e os dois consumidores da dimensão engoliam a
exceção com um `catch` que devolvia nulo. Medido:

> `nome` e `tests` com placeholder → **`WARN`, exit 0, zero lacunas**, e o achado dizia
> *"o manifesto nao declara 'identidade.nome'"* — **sobre um campo que ele declara**. Afirmação
> falsa somada a fail-open. E **nenhum caso exercitava esse ramo em dimensão nenhuma**: foi o que o
> deixou atravessar cinco rodadas.

O segundo era meu, de registro: o `STATE.md` afirmava *"código aprovado pelos dois revisores"*
enquanto a delta tinha código que revisor nenhum tinha visto. Tirei a afirmação em vez de
qualificá-la — e os **vereditos passaram a existir como artefato**, em
`artifacts/review/veredito-25-r*-{qa,sec}.md`, porque o `qa-reviewer` declarou `INCONCLUSIVO`
sobre a fidelidade da tabela que eu tinha escrito sem lastro.

**Rodada 7** — `security-reviewer` **APROVADO**. `qa-reviewer` **REPROVADO**, um
`MEDIA BLOQUEANTE`, e este é o mais fino de toda a subfase:

> **O artefato de máquina afirmava e negava o mesmo fato.** Com placeholder em `verificacao.tests`,
> o `doctor.json` saía com `coverage.nao_verificado` dizendo *"a regra que compara a declaração com
> a pasta tests/ **NAO foi aplicada**"* e, no mesmo arquivo, `coverage.verificado` dizendo
> `verificacao.tests coerente com o disco = **True**`. O mesmo padrão vivia em `retomabilidade` —
> **a quarta vez** que um endurecimento deixou o ramo vizinho aberto.

**O conserto não foi nos dois pontos, foi na classe**, como o próprio revisor sugeriu:
`New-DimensaoDoDoctor` passou a **lançar** quando o mesmo `O_que` aparece nos dois canais. A
invariante vive no construtor, então **dimensão nova nasce coberta sem ninguém precisar lembrar** —
que é a resposta estrutural para um defeito que reapareceu quatro vezes. Junto: a verificação passou
a ser emitida só quando houve o que verificar, e campo **ausente** deixou de virar uma verdade
vácua apresentada como verificação.

**E a mutação pegou o caso novo passando por vacuidade.** O caso que cruza os dois canais lia
`dimensions[].nao_verificado`, que é **sempre nulo** — as lacunas vivem em `coverage`, no topo do
JSON. Reverter a emissão incondicional matava só o caso sintético, e este ficava verde. Ancorado no
lugar certo, as três mutações passaram a matar os **dois**. *Asserção ancorada no lugar errado
aceita qualquer coisa que se pareça com a resposta certa* — e desta vez quem disse isso foi o
instrumento de mutação, não o revisor.

**Rodada 8** — `security-reviewer` **APROVADO**. `qa-reviewer` **REPROVADO**, dois
`MEDIA BLOQUEANTE`, e o primeiro foi a **quinta** aparição da mesma forma — desta vez mostrando que
o conserto da rodada 7 tinha a mesma fragilidade do defeito:

> **A invariante compara STRING, e a guarda local repetia o literal.** Em `retomabilidade` havia
> **dois rótulos para o mesmo fato**, e o ramo do `git log` falhando emitia o segundo — escapava da
> guarda e voltava a afirmar `True` sobre o que a dimensão dissera não ter medido. Entrada:
> `git checkout --orphan`, que é o mesmo estado *fetch-only* que o `doctor-git.ps1` já trata como
> primeira classe. Medido: `refs/heads` tem `main`, `git log -1` sai **128**.

**O conserto trocou o mecanismo, não o rótulo.** A emissão da verificação deixou de ser decidida
por comparação de texto e passou a acontecer **no ramo que estabeleceu o fato** — em
`retomabilidade` e em `manifesto`. *Guarda por string tem a mesma fragilidade do defeito que ela
conserta: trocar o texto da lacuna a desarma em silêncio.*

Junto: campo **ausente** deixou de virar `True`. `verificacao.tests` não declarado e `docs/STATE.md`
nunca commitado passaram a sair como `nao se aplica: <motivo>`.

O segundo bloqueante era de registro, e a forma é instrutiva: o `CHANGELOG` dizia *"na quinta
aprovou o código"* quando três rodadas posteriores acharam `MEDIA BLOQUEANTE` **de código**. E o
ponteiro dos vereditos citava `{1..7}` numa linha, `{1..6}` em outra, com o `r7` ausente do disco.

**Rodada 9** — `security-reviewer` **APROVADO**. `qa-reviewer` **REPROVADO**, três
`MEDIA BLOQUEANTE`, e o primeiro é o que mais ensina de toda a subfase:

> **Nenhum caso da suíte lia o campo `Resultado`.** A correção da rodada 8 — campo ausente deixando
> de virar `True` — podia ser **revertida inteira com a suíte verde**: o construtor não lança
> (não há lacuna com aquele rótulo nesses ramos), o caso de cruzamento não vê colisão, e nenhum
> código de saída muda. Eu tinha registrado no backlog que a classe estava *"fechada na sétima
> rodada"*. **Não estava** — a sétima fechou colisão de rótulo, não asserção de conteúdo.

E a nona achou a classe viva em mais duas dimensões, que eu tinha declarado seguras:

- **`ambiente`**: campo ausente emitia uma **lacuna que não dominava** — a única dentro de uma dimensão que **mediu** (a exceção declarada é `raiz` sobre caminho que não é repositório, item 83; eu tinha escrito "a única do doctor inteiro", e era mais largo que o fato).
  O relatório imprimia a linha em *"O que NAO foi verificado"*, logo abaixo do parágrafo que diz
  que lacuna faz sair com `2`, e o processo saía **`0`**. "Lacuna decorativa", a forma que a rodada 5
  nomeou, viva na terceira dimensão.
- **`frescor`**: a verificação saía para **todo** artefato, fora do `switch`, convivendo com a
  lacuna do ramo `invalido` sobre o mesmo artefato, com outro rótulo. **A justificativa que eu tinha
  escrito no backlog — *"os ramos são mutuamente exclusivos"* — era factualmente falsa**, e a
  condição de disparo que eu reservei para o futuro já estava no disco.

Os dois corrigidos, com caso próprio e **quatro mutações** que matam cada uma o seu caso.
**As quatro desta rodada morreram**, cada uma matando o seu caso.

**Rodada 10** — `security-reviewer` **APROVADO**. `qa-reviewer` aprovou `correção`,
`regressão`, `cobertura`, `escopo` e `portabilidade`, e **reprovou só `registro`**, com **um**
`MEDIA BLOQUEANTE` — e escreveu, com todas as letras: *"Não preciso de rodada nova sobre o código
do doctor."*

O bloqueante era meu, e é **a mesma classe pela qual a oitava rodada já tinha reprovado**: eu
corrigi a frase do `CHANGELOG` que dizia *"reprovou sete vezes"* e deixei o **escopo da seção** e o
**total de mutações** velhos. O documento que viaja no release anunciava oito rodadas, listava as
que acharam código até a oitava, e dizia dezoito mutações — com a nona no disco e vinte e duas
mortas. *Corrigir uma frase de um parágrafo e deixar as outras é a forma exata do defeito que o
parágrafo descrevia.*

**E ele derrubou mais duas afirmações minhas**, as duas escritas na rodada anterior:

- eu tinha escrito, em dois lugares, que a lacuna de `ambiente` era *"a única do doctor inteiro que
  não derrubava para `INCONCLUSIVO`"*. **Falso:** `raiz`, sobre caminho que não é repositório,
  também emite lacuna e sai `1`. Ali é **legítimo** — o fato da própria dimensão está determinado,
  e a lacuna é sobre as **outras** —, mas o **texto fixo do relatório** afirmava que lacuna faz
  sair com `2`, e isso era falso no próprio artefato. Texto e afirmações corrigidos (item 83);
- e o item 74 dizia *"fechado"* sobre o canal `Resultado`. **O que foi fechado são os quatro pontos
  de "campo ausente", não o canal**: ele tem asserção em **4 de 15** pontos de emissão, e o
  revisor deu a mutação que sobrevive hoje — fixar `doctor-git.ps1:52` em `True` faz o
  `doctor.json` afirmar `historico legivel = True` num repositório sem commits, **com a suíte
  inteira verde**. Delimitado (itens 74 e 84).

**Rodada 11** — `security-reviewer` **APROVADO**. `qa-reviewer` aprovou de novo `correção`,
`regressão`, `cobertura`, `escopo` e `portabilidade`, e reprovou **só `registro`** — pela segunda
rodada seguida em que o código passa inteiro e o registro não.

Os três bloqueantes são todos da mesma família, e a família é **conserto pela metade**:

1. **Eu corrigi o texto do relatório e esqueci a `SKILL.md`.** Ela carregava a **mesma** afirmação
   falsa — *"ou que rodou e deixou uma lacuna declarada derruba o diagnóstico inteiro"* — que é
   falsa no caminho `raiz`. Consertar o artefato gerado e esquecer o **contrato publicado** é a
   forma exata do defeito que eu estava consertando.
2. **No `CHANGELOG` eu acrescentei a frase nova ao lado da velha**, em vez de apagar a velha. As
   duas ficaram convivendo no mesmo parágrafo, uma dizendo *"rodadas 6, 7 e 8"* e a outra
   *"6, 7, 8 e 9"*.
3. **A narrativa da oitava rodada dizia "dezoito mutações no total"** enquanto a seção da nona
   fechava em vinte e duas. Datado: *"dezoito até aqui; o total da subfase fechou em vinte e duas"*.

E ele nomeou o que sustenta a família inteira, que fica registrado como teto: **a prosa do
relatório e da `SKILL.md` não tem detector nenhum**. Foi por isso que a afirmação falsa sobreviveu
uma rodada inteira depois de eu tê-la corrigido no código.

**Rodada 12** — `qa-reviewer` aprovou `correção`, `regressão`, `escopo` e `portabilidade`,
deu `cobertura` **`INCONCLUSIVO`** — *"o que mudou nesta delta é PROSA, e prosa não tem detector
nenhum"* — e reprovou `registro` com **um** `MEDIA BLOQUEANTE`. **Terceira rodada seguida com a
mesma forma:** eu corrigi a frase do `CHANGELOG` e deixei o **título** e o **alcance do parágrafo**
velhos.

**O conserto não foi corrigir o número pela quarta vez: foi tirar a fonte.** O `CHANGELOG` deixou
de carregar contagem de rodadas — ela vive só no `STATE`, que é o registro rodada a rodada, e o
parágrafo passou a descrever a **forma** da subfase em vez do placar.

**E essa primeira tentativa estava errada em dois pontos, que a rodada 13 pegou.** Eu escrevi que
*"as rodadas 6 a 9 acharam `MEDIA BLOQUEANTE` de código"* — **as rodadas 1 a 4 também acharam**, e
os vereditos no disco mostram isso; e escrevi que o `security-reviewer` *"aprovou em todas"*, sendo
que a **rodada 12 não teve revisor de segurança**. Placar retido é placar errado.

*Número que vive em dois lugares diverge; o conserto é ter um lugar só.*

**E isso já estava escrito neste repositório.** O `CHANGELOG` da **2.4** registra a mesma lição,
com as mesmas palavras: *"a contagem de rodadas fica, o placar por veredito sai. Número em prosa
que ninguém pode conferir é afirmação, não registro."* Eu repeti a classe uma subfase depois, em
prosa que **eu mesmo** tinha escrito. É o argumento mais forte desta subfase inteira para o item
86: **a prosa não tem detector**, e por isso uma lição registrada não impede a reincidência — só
um guarda-corpo impede.

O revisor também cobrou o **gatilho** do item 86, e com razão: eu o tinha escrito como condição
futura (*"quando a prosa voltar a afirmar comportamento verificável"*) quando ela afirma **hoje** —
a `SKILL.md` declara os códigos de saída, a regra de dominação e o caso `raiz`. Datado.

E achou, fora da delta, que **na seção `## git diff` do relatório de coleta o acento sai mojibake**
enquanto a seção de arquivos novos sai correta — o que significa que **regressão de encoding em
arquivo rastreado é invisível para o relatório**. Item 87.

**Rodada 13** — `qa-reviewer` **REPROVADO**, dois `MEDIA BLOQUEANTE`, e o achado que ele
acrescentou é o melhor da subfase inteira:

> **Eu apliquei o INVERSO da lição que citei para me justificar.** A 2.4 registra, neste mesmo
> `CHANGELOG`: *"a contagem de rodadas **fica**, o placar por veredito **sai**."* Eu tirei a
> contagem e **mantive o placar** — e os dois bloqueantes desta rodada são exatamente os dois itens
> do placar retido, os dois **falsos**:
>
> - *"as rodadas 6 a 9 acharam `MEDIA BLOQUEANTE` de código"* — **as rodadas 1 a 4 também
>   acharam**, e os vereditos no disco mostram cada uma;
> - *"o `security-reviewer` aprovou o fluxo privado em **todas**"* — a **rodada 12 não teve revisor
>   de segurança**. Era garantia **corrente**, não histórica: quem cruzasse com o `STATE`
>   concluiria que o estado submetido passou por varredura independente aprovada que não existe.

**Desta vez o conserto seguiu a regra da 2.4 ao pé da letra**: a contagem de rodadas volta ao
`CHANGELOG` **no fechamento**, quando for número fechado; o placar por veredito **sai inteiro**; e
a nota diz **por que** — os vereditos vivem em `artifacts/`, ignorado pelo Git, e quem clonar o
repositório não consegue conferir afirmação nenhuma sobre rodadas.

**Junto saiu a outra fonte da mesma classe:** os **subtotais correntes de mutação**. Eram seis no
`CHANGELOG` e cinco no `STATE`, e já divergiam — um dizia "dezesseis até a sétima", o outro saltava
de nove para "dezoito até aqui" posicionado antes da sexta. Nenhum deles é conferível pelo
repositório (item 31). Agora cada rodada diz **o que aconteceu nela**, e o total aparece **uma vez
só**, na rodada 9.

E ele registrou o teto que sustenta tudo isso, que é o item 86: **`cobertura` saiu `INCONCLUSIVO`
duas rodadas seguidas** porque *"o que mudou nesta delta é prosa, e prosa não tem detector nenhum"*
— reintroduzir qualquer uma das afirmações falsas hoje passa com a suíte inteira verde.

**Decisão da mantenedora, 2026-09-22 — e o detector que a 2.5 ganhou por causa dela.** Diante do
item 88, ela escolheu **construir o detector antes de fechar a 2.5**, e não fechar com a dívida
registrada. É a escolha que fecha a classe em vez de administrá-la, e o resultado justificou:

`tests/suites/doctor.ps1` ganhou **dois casos de contrato**. Eles não validam prosa — **extraem da
prosa as afirmações estruturadas e perguntam ao código**:

- a escada de status da tabela da `SKILL.md` tem de ser a de `Get-StatusDoDoctor`, campo a campo;
- a linha *"Códigos de saída"* é **parseada**, e cada par status→código é conferido contra
  `Get-CodigoDeSaidaDoDoctor`;
- os três cenários que a prosa nomeia — fora de repositório, `bare`, placeholder — são
  **executados**, e o código de saída tem de ser o que ela promete. Com o par: projeto saudável sai
  `0`, senão a regra viraria "sai sempre diferente de zero".

**Quatro mutações, e as duas que importam mudam só a PROSA:** trocar `1` por `2` na linha de
códigos de saída da `SKILL.md`, sem tocar no código, **mata o caso**; e tirar `(bare)` da mesma
linha também. É a primeira vez nesta subfase que uma mudança de documentação derruba a suíte — que
era exatamente o que faltava.

**E a mutação pegou o detector novo passando pela razão errada.** A primeira versão procurava
`bare` em **qualquer lugar** do arquivo, e a palavra aparece de novo seis linhas abaixo, na
descrição da dimensão `raiz`: tirar `(bare)` da linha da afirmação **não derrubava nada**.
Reancorado na **linha que carrega a afirmação**, morre. *Asserção ancorada genericamente aceita
qualquer coisa que se pareça com a resposta certa* — pela segunda vez nesta subfase quem disse isso
foi o instrumento, não o revisor.

**Rodada 14** — `security-reviewer` **APROVADO** para o fluxo privado, sem `ALTA` e sem
`MEDIA BLOQUEANTE`, e ele conferiu por conta própria que a garantia falsa da rodada 13 **não existe
mais**. `qa-reviewer` **REPROVADO**, dois `MEDIA BLOQUEANTE` — e o segundo é o achado mais afiado
de toda a subfase:

> **O detector que eu construí para fechar a classe tinha a própria classe dentro dele.** Ele
> entregou a mutação pronta: mover *"fora de repositório"* da cláusula do `1` para a do `2` na
> `SKILL.md`. O contrato publicado passa a prometer **2**, o código sai **1**, e **os dois casos de
> contrato ficam verdes** — porque o caso 2 comparava a execução contra expectativa **fixada no
> teste**, não extraída da prosa. Eu tinha escrito que *"o código de saída tem de ser o que ela
> promete"*, e o teste não fazia isso. **Afirmação larga sobre verificação estreita, dentro do
> guarda-corpo que existe para pegar afirmação larga sobre verificação estreita.**

**O conserto:** o código esperado passou a ser **extraído da própria prosa**, cláusula a cláusula;
o parágrafo do caso `raiz` é conferido contra a linha de códigos **e** contra
`Get-CodigoDeSaidaDoDoctor`; e o **relatório passou a ter o próprio código de saída conferido** —
ele imprime *"(codigo de saida N)"*, e esse `N` tem de ser o do processo. Era a metade do item 86
que eu tinha declarado fechada sem estar: o texto fixo do relatório, que foi justamente quem
carregou a afirmação falsa do item 83.

**Três mutações novas, as três mortas — inclusive a M27, que é a do revisor**, e duas delas mudam
**só a prosa**. *(Agregado de subfase fica para o fechamento: eu tinha escrito "agora são quatro"
**duas linhas acima da regra que proíbe agregado corrente**, e o `qa-reviewer` pegou na rodada 15.)*

O primeiro bloqueante foi de registro, e a forma já é conhecida: **o total de mutações "vinte e
duas" ficou velho na própria rodada que acrescentou quatro.** Mesma cura do número de rodadas: o
total sai da prosa corrente e entra **no fechamento**; cada rodada diz só o que aconteceu nela.

E o item 86 deixou de dizer **FECHADO** e passou a dizer **FECHADO EM PARTE**, nomeando o que tem
detector e o que não tem — delimitação que ele cobrou, e com razão: eu tinha marcado como fechado
um item cuja afirmação era mais larga que a medição, **dentro do item que existe para pegar isso**.

**Rodada 15** — `qa-reviewer` **REPROVADO**, um `MEDIA BLOQUEANTE`, em `cobertura`. O produto
ficou **sem achado**; o defeito estava de novo no **guarda-corpo do contrato publicado** — quarta
aparição da classe, e ele nomeou por que o conserto anterior não bastava:

> *"A pergunta aqui ainda é **'qual o primeiro número da cláusula?'**, e não **'qual número a frase
> associa a este cenário?'**"*

A extração quebrava a linha em `;` e pegava o **primeiro** código de cada pedaço. Trocar o `;` por
uma **vírgula** antes do cenário — *"`1` para `FAIL`, e `2` para caminho fora de repositório"* —
fazia a prosa prometer `2`, o teste continuar medindo `1`, e a suíte inteira ficar verde: **o
contrato publicado de volta a poder mentir sobre código de saída**. Ele derivou a mutação por
leitura, asserção por asserção, e nomeou a irmã dela no `bare`.

**A terceira remenda seria a resposta errada, e a lição está escrita neste repositório:** *"quando um
guarda falha duas vezes pelo mesmo motivo, o conserto certo não é a terceira remenda — é trocar a
pergunta"*. A linha passou a ser **varrida da esquerda para a direita**, e cada cenário é amarrado
ao **último código anunciado antes dele**, qualquer que seja a pontuação. As duas mutações dele
morrem, e a M27 da rodada anterior continua morrendo.

**As três ressalvas, todas fechadas:**

- o **canal humano** passou a ser conferido nos **quatro** fixtures, não em dois — e com isso o
  caminho `0` ganhou medição no relatório, que não tinha em lugar nenhum. A expectativa do projeto
  saudável também vem da prosa;
- os **agregados correntes** que sobreviveram à própria regra saíram — um deles estava **duas linhas
  acima da regra que o proíbe**;
- e a regra do `CHANGELOG` foi escopada: agregado não entra **enquanto a subfase está aberta**; em
  subfase **fechada** ele é número fechado e entra. A primeira versão proibia nominalmente uma frase
  que o próprio arquivo mantém na seção da 2.4, e quem fosse escrever o fechamento não teria como
  saber qual das duas valia.

O item 86 passou a registrar também que **o que tem detector, tem por ENUMERAÇÃO**: uma promessa
nova acrescentada amanhã à linha de códigos nasce sem detector, em silêncio.

**Rodada 16** — `qa-reviewer` **REPROVADO**, um `MEDIA BLOQUEANTE` em `cobertura`. O produto
**sem achado** pela segunda rodada seguida; o defeito, de novo, no guarda-corpo — e de novo porque
eu consertei **metade**:

> **Eu troquei a pergunta só na linha de códigos.** O cenário do `placeholder` continuou com a
> pergunta antiga — *"qual o primeiro número da linha?"* — numa linha da `SKILL.md` que carrega
> **dois** cenários: o placeholder **e** `verificacao.tests` com valor não reconhecido. Reordenar a
> frase fazia a prosa prometer `1` para o placeholder, o teste medir `2`, e a suíte ficar verde.
> **Quinta aparição da classe, no mesmo guarda-corpo, num canal irmão.**

Agora a **mesma pergunta** vale nas duas linhas. Elas têm formas retóricas opostas — na linha de
códigos o número vem **antes** do cenário (*"`1` para X"*), na do placeholder vem **depois**
(*"X ... sai `1`"*) —, e isso está escrito no código: numa a amarração é ao último código antes,
noutra ao primeiro depois. A pergunta é a mesma; a direção da leitura, não.

E o segundo cenário daquela linha — `verificacao.tests` não reconhecido — **ganhou execução**: a
prosa o nomeava e nada o media.

**As quatro ressalvas, todas de "rótulo mais largo que a medição", e todas minhas:**

- o fixture rotulado *"projeto saudável (PASS)"* exercitava, na verdade, o caminho **`WARN`** —
  `New-RepoDoctor` não cria `artifacts/`, então o frescor sai `WARN`. Renomeado, amarrado ao `WARN`
  da prosa, e com asserção de que o relatório **realmente** diz `WARN`;
- `bare` era procurado com `\bbare\b` na pré-condição e `bare` solto no mapa — dois critérios para
  o mesmo fato no mesmo caso, que é a duplicação que permite endurecer um lado e esquecer o outro;
- a guarda contra vacuidade existia para dois cenários e não para o terceiro;
- e o `CHANGELOG` dizia *"a seção da 2.4, **200 linhas abaixo**"* — **número posicional em prosa, dentro da nota que existe para proibir número em prosa**, e que **cresce sozinho** a cada linha acrescentada acima dela. Removido. Esta quarta ficou fora do registro na primeira escrita, e o `qa-reviewer` cobrou na rodada 17: lição que não é registrada se perde quando a conversa some.

E o título do caso dizia *"os três cenários"* quando já são cinco — afirmação mais larga que a
medição, no título do caso que existe para pegar isso. Passou a nomear a **pergunta**:
*"cada cenário que a `SKILL.md` nomeia sai com o código que **ela associa a ele**"*.

**Rodada 17** — `qa-reviewer` aprovou `correção`, `regressão`, **`cobertura`** e
`portabilidade`; `escopo` saiu **`INCONCLUSIVO`** (item 72: sem delta entre coletas, *"o produto não
foi tocado"* não tem lastro na evidência dele); e `registro` REPROVADO, com **um**
`MEDIA BLOQUEANTE` — cuja ironia é exata:

> **A correção da rodada 16 tornou o item 86 mais largo que a medição.** Ele publicava a
> enumeração dos cenários *"três chaves fixas (`fora-de-repo`, `bare`, `saudavel`...)"*, e a rodada
> anterior tinha **renomeado** `saudavel` para `sem-evidencia` e acrescentado dois. **Dentro do item
> que existe para pegar afirmação mais larga que a medição.** A lista deixou de ser transcrita e
> passou a **apontar para o código**, que é onde ela se mantém atual.

E ele achou uma lacuna de cobertura real, que nenhuma rodada anterior tinha visto: **nenhum caso
produzia status global `PASS`**. Todos os `PASS` medidos eram de **dimensão**; a agregação só era
exercitada com `INCONCLUSIVO` ou `FAIL` na lista. Mutação que sobrevivia: um agregador que nunca
devolvesse `PASS` — saída `0` nos dois mundos, suíte inteira verde.

**O caso do `PASS` global existe agora**, e escrevê-lo mostrou por que ele não existia: as seis
dimensões só fecham em `PASS` numa **ordem** específica. O `STATE` tem de ser tocado pelo **último**
commit, senão a retomabilidade sai `WARN`; o carimbo dos artefatos tem de citar o `HEAD` **final**,
senão o frescor sai `de-outro-head`; e a árvore tem de ficar **limpa**, senão a dimensão `git`
avisa. As três só fecham juntas porque `artifacts/` é **ignorado**: os artefatos são escritos
**depois** do commit, citam o `HEAD` final, e não sujam nada. As duas primeiras tentativas caíram
exatamente nessas duas armadilhas, nessa ordem, e o caso registra as três pré-condições.

Com o par que impede o "sai sempre `PASS`": sujar a árvore derruba o global para `WARN`.

As demais ressalvas eram todas da mesma família — **conversão pela metade**: o caso `:747` ainda
se chamava *"projeto saudavel"* sobre a fixture que sai `WARN`; o `CHANGELOG` e os comentários do
próprio caso ainda diziam *"três cenários"* com cinco no disco; e a quarta ressalva da rodada 16 —
o *"200 linhas abaixo"* — tinha sido **corrigida no arquivo e não registrada**. Ele cobrou, e tem
razão: *lição que não é registrada se perde quando a conversa some* — que é o princípio da
plataforma inteira.

**Rodada 18** — **`INCONCLUSIVO`**, e pela primeira vez o bloqueio não é de defeito: **nenhuma
`ALTA`, nenhuma `MEDIA BLOQUEANTE`**. `correção`, `regressão`, `cobertura`, `portabilidade` e
`registro` **aprovados**; só `escopo` ficou `INCONCLUSIVO`, e a causa é **estrutural, não da
delta**: o diff é cumulativo contra `fff0e69` e os arquivos do doctor são `??`, então *"o produto
não foi tocado nesta rodada"* não tem lastro na evidência dele. É o **item 72**, e ele próprio
escreve: *"some no commit da 2.5; volta em toda subfase que criar arquivo novo"*.

E ele achou, derivando mutação por leitura, **a última lacuna de cobertura da agregação**: dos seis
pares que a escada canônica decide, cinco tinham caso e **`FAIL` × `INCONCLUSIVO` não tinha
nenhum**. Mutação sobrevivente: reordenar `Get-StatusDoDoctor` para `FAIL` dominar. Os códigos de
saída não mudam — saem de um `switch` separado —, e o caso de contrato confere **pertinência**, não
ordem. Suíte inteira verde.

> O que a mutação produziria: `FAIL` global e exit `1` sobre um projeto em que uma dimensão **não
> conseguiu medir** — o `doctor.json` afirmando *"verifiquei e está ruim"* sobre o que não foi
> verificado. A forma que a política 4.5 proíbe, no contrato de máquina da Fase 3/4.

**O caso existe**, com pré-condição que exige as **duas** dimensões no estado do par antes de medir a
regra — senão mediria outro par com o mesmo nome. A mutação morre.

As demais ressalvas eram **conversão pela metade**, de novo e todas minhas: o item 86 tinha parado de
carregar a **lista** e continuado carregando a **contagem** ("três" para cinco, na mesma frase que
manda ver o código); um comentário dizia *"os quatro fixtures"* com cinco, e escapou do meu `grep`
por estar quebrado em duas linhas; a mensagem de falha de um caso ainda chamava de *"saudável"* a
fixture que o título já tinha corrigido para *"sem defeito"*; e o `STATE` ainda dizia *"40 linhas
abaixo"* numa linha que esta subfase editou — o mesmo número posicional que cresce sozinho, agora em
52.

**Rodada 19 — a de fechamento. Os dois revisores sobre a arvore que esta sendo commitada.**

O `security-reviewer` nao era convocado desde a rodada 14, e a arvore mudou depois: fechar declarando
aprovacao de seguranca sobre um estado que ele nao viu seria a forma exata do defeito que esta
subfase reprovou quatro vezes. Ele foi convocado por isso, e nao por suspeita.

| Revisor | Veredito | O que destrava |
|---|---|---|
| `security-reviewer` | **APROVADO** para o fluxo privado. Seis areas aprovadas, `SEC_EXIT=0` | *"Nao exijo nada satisfeito antes do commit."* E, sobre os nove arquivos `??`: a area `working tree` cobriu rastreado **e** nao rastreado, entao **o commit nao introduz conteudo nao varrido** |
| `qa-reviewer` | **`INCONCLUSIVO`, so em `escopo`.** `correcao`, `regressao`, `cobertura`, `portabilidade` e `registro` **aprovados**. Nenhuma `ALTA`, nenhuma `MEDIA BLOQUEANTE` | *"O que destrava: so o escopo. Nada aqui pede mudanca de codigo."* E sobre o proprio `INCONCLUSIVO`: *"Item 72; some no commit da 2.5"* |

**O `INCONCLUSIVO` de escopo nao e material, e a razao e verificavel, nao conveniente:** ele nao diz
que a delta esta errada — diz que a evidencia **nao permite afirmar** que o produto nao foi tocado,
porque os arquivos do doctor sao `??` e o diff e cumulativo contra `fff0e69`. E o item 72, registrado
desde a rodada 8, e ele se resolve **exatamente pelo ato de commitar**: a partir do proximo commit
existe base por rodada. Fechar aqui nao contorna a lacuna; e o que a fecha.

Os cinco `BAIXA` desta rodada entraram no backlog como **89 a 93** — tres do `security-reviewer`
(guarda de `git init` na fixture, `Remove-RepoDoctor` silencioso, relatorio que nao separa rastreado
de nao rastreado) e dois do `qa-reviewer` (numero posicional em prosa duplicado em dois arquivos, e
*"as sete formas de raiz"* enumerando seis).

**A lição, que é a mesma da rodada 1 com outra roupa:** quando um guarda falha duas vezes pelo
mesmo motivo em lugares diferentes, o defeito não é o guarda — é a **duplicação** que permite
endurecer um lado e esquecer o outro. E: *eu afirmei ter corrigido quatro pontos tendo corrigido
três*. A afirmação larga sobre a verificação estreita apareceu três vezes nesta subfase — no
comentário do caso de paridade, na docstring do leitor, e no meu próprio relato. Na rodada 3 ela
apareceu pela quarta vez, e desta vez **no conserto da rodada anterior**: alinhei a chave e
declarei paridade, com o valor ainda divergindo. O `qa-reviewer` reprovou nas três primeiras
rodadas, e as três vezes com razão.

#### Vereditos finais da 2.5 — 2026-09-22

Dezenove rodadas com os dois revisores em contexto isolado (ADR-0007), read-only (ADR-0008). O
`qa-reviewer` emitiu **dezenove** vereditos; o `security-reviewer`, **treze** — ele foi convocado nas
rodadas 1 a 11, 14 e 19, e **as rodadas em que ele nao foi convocado nao carregam aprovacao de
seguranca nenhuma**, o que esta dito em cada uma delas. Os dois vereditos que fecham a subfase, sobre
o codigo que esta sendo commitado:

| Revisor | Veredito | Escopo |
|---|---|---|
| `qa-reviewer` | **APROVADO em cinco areas**, `INCONCLUSIVO` em `escopo` | Delta da rodada 19. `correcao`, `regressao`, `cobertura`, `portabilidade` e `registro` aprovadas. Nenhuma `ALTA`, nenhuma `MEDIA BLOQUEANTE`. *"Nada aqui pede mudanca de codigo."* |
| `security-reviewer` | **APROVADO** para o fluxo privado autorizado | Seis areas, sobre a arvore completa — rastreado e nao rastreado. *"Nao exijo nada satisfeito antes do commit."* |

**O `INCONCLUSIVO` esta declarado, nao apagado.** Ele e o item 72 — sem base por rodada enquanto os
arquivos forem novos — e a politica 4.5 exige que ele apareca aqui com esse nome. O que se afirma e
o que ele mesmo escreveu: **nao e material para o escopo aprovado, e se resolve no commit**.

**O que estes `APROVADO` significam, e nao mais do que isso:** nenhum padrao detectavel nos arquivos
varridos, com o teto permanente do scanner declarado dentro do proprio relatorio. Os artefatos de
veredito vivem em `artifacts/review/veredito-25-r*-{qa,sec}.md` — **`artifacts/` e ignorado pelo Git
e nao viaja num clone**, entao esta secao e o registro que viaja.

**Numeros fechados da subfase**, que so entram agora porque so agora sao numeros fechados: dezenove
rodadas, **34 mutacoes aplicadas contra o repositorio real e 34 mortas**, com restauracao conferida
por SHA-256 em cada uma. A suite fechou em **350 casos**.

### Subfase 2.5 — `/os:doctor` implementado, 2026-09-18

O plano final foi aprovado com os cinco ajustes e as tres decisoes de governanca de 2026-09-17.
Nada aqui reabre desenho: e o registro do que foi construido e do que a construcao revelou.

**O que existe agora:** `scripts/doctor.ps1` mais seis modulos em `scripts/lib/doctor-*.ps1`,
`skills/doctor/SKILL.md`, e `tests/suites/doctor.ps1` — a contagem de casos vive só no
cabeçalho deste arquivo, porque número repetido em prosa envelhece, e esta linha já envelheceu.
A camada 0 —
`Get-RaizDoRepositorio`, em `scan-comum.ps1` — resolve a raiz real antes de qualquer predicado, e e
o que permite rodar de subdiretorio.

**As sete formas de raiz, medidas em execucao:** raiz e subdiretorio resolvem para a mesma pasta;
worktree ligado resolve e a forma **diz** que e worktree (porque ali `GitDir` e `ComumDir` diferem);
recem-init resolve com `HEAD` nao nascido, que e estado **esperado**; fora de repositorio devolve
`fora-de-repo`, que e um FATO e sai `1`; *bare* devolve `bare`, nao suportado, e sai `2` sem
quebrar.

**Os quatro estados de frescor** saem distintos: `ausente`, `do-head`, `de-outro-head`, `invalido`.
A regra que os separa e uma so — `WARN` e "determinei e o fato e ruim"; `INCONCLUSIVO` e "nao
consegui determinar" —, e **"nao existe evidencia recente" nunca e `PASS`**.

**A semantica de `ambiente.dependencias`, exatamente como decidida:** campo ausente -> `WARN`;
`[]` -> valido, `PASS`; declarada e presente -> `PASS`; obrigatoria e ausente -> `FAIL`; opcional e
ausente -> `WARN`. Ferramenta que o projeto **nao** declara nao gera diagnostico nenhum.

**O doctor nao executa e nao altera**, medido contra fixture com suite que deixaria rastro e com
segredo em formato reconhecivel: a suite do projeto **nao rodou**, zero arquivo alterado ou
apagado, `HEAD` identico antes e depois, nada criado fora de `artifacts/doctor/`, e o relatorio nao
transcreve nem acusa o segredo — isso e `/os:security`, e duplicar seria dois detectores divergindo
em silencio.

#### Sete defeitos reais, todos meus, todos achados executando

Nenhum apareceu por leitura. Ficam registrados porque a classe se repete.

| # | Defeito | Como apareceu |
|---|---|---|
| 1 | **Acento em `.ps1`** nos padroes de retomabilidade. O 5.1 le `.ps1` UTF-8 sem BOM como ANSI, entao `ultima`/`proximo` com acento chegavam ao regex como mojibake | o primeiro diagnostico contra o proprio repositorio acusou **ausencia** de duas secoes que estao la |
| 2 | **`mtime` contra data do commit** era falso positivo **por construcao**: commitar nao muda o `mtime`, entao o arquivo e sempre mais antigo que o commit que o contem | o `STATE.md` recem-commitado saiu como "atrasado". Trocado por comparar o **commit** que tocou o STATE com o ultimo commit |
| 3 | **Regex do carimbo ancorado em inicio de linha.** O relatorio de seguranca abre a linha com `HEAD:`; o de diff escreve `Branch: x  HEAD: sha` | declarava `invalido` um carimbo perfeitamente valido — **lacuna inventada**, tao ruim quanto lacuna escondida |
| 4 | **A guarda de raiz comparava CAMINHOS** e falhava nas duas pontas | nao pegava o caso do `GIT_DIR` — ali o git usa o diretorio corrente como *work tree*, e a raiz devolvida **e** o caminho perguntado —, e acusava falso em toda fixture sob `%TEMP%`, porque `$env:TEMP` aqui e a forma 8.3 (`USUARI~1`) e o git responde com o nome longo. Trocada por perguntar se a raiz tem `.git` |
| 5 | **`return @()` colapsa para `$null`** no PowerShell | `dependencias: []` chegava **indistinguivel de campo ausente**: a declaracao explicita da mantenedora apagada por uma regra da linguagem. O operador virgula preserva o array |
| 6 | **A cobertura das dimensoes nao chegava a saida nenhuma** | o guarda-corpo de "campo sem leitor" apontou, e estava certo: as dimensoes carregavam contadores que ninguem via. Agora saem na tabela do relatorio **e** em `dimensions[].cobertura` |
| 7 | **A suite nova ficou fora de `$Ordem`** no runner | o guarda de ordem pegou: ela rodaria, mas na hora errada |

**O defeito 5 e o que a mantenedora nomeou antes de eu encontrar**, e por isso ele tem regressao
no ponto exato onde morava — o leitor, nao so a dimensao. Mutacao conferida: voltar a `return @()`
mata dois casos; remover a guarda do `.git` mata um; os dois arquivos restauram com SHA-256
identico.

#### A revisao independente reprovou, e os dois acharam coisas diferentes

O `qa-reviewer` reprovou com **um `MEDIA BLOQUEANTE` e quatro `MEDIA`**. O `security-reviewer`
aprovou o fluxo privado e levantou **um `MEDIA` que se qualifica como bloqueante** pelo criterio de
2026-09-14 ("falsa aprovacao ou garantia"). Nenhum dos dois achou o achado do outro.

**O bloqueante do QA: o caso de paridade nao exercitava o gemeo.** Eu declarei um scriptblock,
descartei em `$null = $bloco`, e escrevi num comentario que o gemeo era *"exercitado abaixo, por
comparacao de VALOR"*. Abaixo nao havia comparacao nenhuma - as assercoes so exigiam que o leitor
**do doctor** devolvesse nao-vazio. O cabecalho de `doctor-manifesto.ps1` e o ponto 10 do briefing
descreviam algo que o codigo nao fazia. **Verde sobre caminho nao exercitado**, que e o modo de
falha mais caro que existe aqui. Agora o gemeo roda em **processo filho** - o harness do template
define `Test-Caso` e derrubaria a suite se fosse carregado no mesmo escopo - e os valores sao
comparados campo a campo.

**E o caso, funcionando, prendeu tres divergencias reais** que o QA tinha derivado por leitura, cada
uma com entrada concreta e todas com a mesma direcao: afirmar valor onde nao ha.

| Divergencia | O que fazia | Consequencia |
|---|---|---|
| valor que e **so comentario** (`comando:  # preencher depois`) | devolvia `# preencher depois` como valor | a dimensao manifesto saia `PASS` afirmando um criterio que ninguem declarou |
| **TAB** antes do `#` | cortava so no literal `' #'` | `tests: true<TAB># roda` virava falso, e a **unica** regra `FAIL` da dimensao deixava de disparar - *fail-open* |
| linha irreconhecivel | `continue` em silencio | chave com ponto ou espaco sumia, e o doctor dizia "nao declara X" sobre campo declarado. Em `ambiente.dependencias` colapsaria ausente com `[]` |

As tres eram latentes nos dois `project.yaml` de hoje - e o leitor roda sobre projeto governado
arbitrario, e o template e feito de placeholder comentado.

**O bloqueante do Security: a guarda da raiz ainda tinha um estado.** Ela testava se a raiz
devolvida **tem** `.git`. Com `GIT_DIR` apontando para o repositorio A e o caminho sendo a raiz de
um repositorio B, `show-toplevel` devolve B, B tem `.git`, e a guarda passava. Como `Invoke-Git`
herda o ambiente, todo comando a jusante responderia sobre A: **o diagnostico sairia com a raiz de
B e o `HEAD`, o `status` e o `log` de A, com status `PASS`**. Nao e hipotetico - `GIT_DIR` e o
estado de todo hook do Git, e a 2.6 e justamente hooks. Corrigido comparando o diretorio Git **em
uso** (`rev-parse --absolute-git-dir`) com o `.git` da raiz.

**O doctor reprovava o proprio fluxo normal.** Em repositorio sem nenhum commit - o estado exato
depois de `/os:new-project`, onde a regra de ouro proibe commitar sem pedido - `git log` sai com
128, e eu li isso como falha de leitura: a dimensao caia para `INCONCLUSIVO`, que domina, e o doctor
saia com **2 sobre um projeto que acabou de nascer**. O ramo escrito para esse caso era
**inalcancavel**. Contradizia o principio que eu mesmo escrevi em `doctor-git.ps1` e na `SKILL.md`.
O conserto e perguntar **antes** se ha historico, em vez de deduzir da falha.

**E a suite escrevia no working tree da plataforma.** Com a raiz irresolvivel, o destino caia em
`(Get-Location)`, e o caso *"fora de repositorio"* gravava o diagnostico de uma pasta temporaria em
`artifacts/doctor/` **da plataforma** - no caminho canonico do `doctor.json`, que e o contrato que a
Fase 3/4 vai consumir. O `qa-reviewer` achou o arquivo no disco, com a raiz de uma pasta ja apagada.
**Evidencia falsa no lugar certo e pior que evidencia ausente.** O destino passou a ser o `-Path`
perguntado.

**Registro que se contradizia.** O `STATE.md` dizia na linha 6 que a 2.5 estava implementada, na
linha 7 que a proxima era a 2.5, na tabela de roadmap que a 2.5 era *"Proxima"*, e tinha uma secao
inteira de *"primeiros passos para implementar a 2.5"* sobre codigo que ja estava no disco -
enquanto o `project.yaml` dizia que a 2.5 estava concluida. Quem retomasse pelo arquivo que o
`CLAUDE.md` manda ler primeiro seria informado de que a subfase nao foi feita. O teste de coerencia
manifesto/STATE/CHANGELOG estava verde: ele nao olha a fase.

#### As lacunas de cobertura que o QA nomeou, e que nao eram achado

`Get-DiagnosticoGit` **nao era chamado em ponto nenhum da suite** - a dimensao Git inteira sem caso
proprio, justamente onde o briefing pedia "ausencia de falso `PASS` quando o Git nao puder ser
determinado". O detector de *"STATE atras do ultimo commit"* - a correcao do defeito de `mtime` -
tambem nao tinha caso: dava para voltar ao `mtime` sem nada ficar vermelho. E `NaoSondadas` em
`doctor-ambiente.ps1`, idem. Os tres ganharam par.

**Seis mutacoes, seis mortas pelos casos certos**, com restauracao conferida por SHA-256. A que
reverte o corte de `'\s#'` mata **dois** casos - o da TAB e o de paridade -, e isso e o que prova
que o caso de paridade passou a exercitar o gemeo de verdade: antes da correcao ele nao teria pego
nada.

#### A varredura acusou `ALTA` na propria suite nova, e a correcao nao foi calar

A primeira coleta saiu com **um achado `ALTA`**: `tests/suites/doctor.ps1` trazia um token
fabricado — necessario, porque o caso prova que o doctor **nao** varre conteudo usando um arquivo
que o `/os:security` acusaria — e o arquivo nao declara o marcador de fixture.

O caminho obvio era declarar o marcador no cabecalho, como `scanner.ps1` e `collectors.ps1` fazem.
**Nao fiz**, e a razao e o item 9: o marcador e a unica rota de rebaixamento que `-ParaPublicacao`
**nao** anula, o `security-reviewer` contesta o tamanho dela ha quatro rodadas, e a mantenedora
acabou de decidir que o item 9 tem de ser resolvido **antes de qualquer publicacao publica real**.
Acrescentar um terceiro arquivo sob o marcador aumentaria a divida no mesmo dia em que ela foi
reafirmada.

O token passou a ser montado em **partes**. O arquivo em disco continua tendo o padrao que o
`/os:security` acusaria — a forca do caso e a mesma —, e a suite deixa de precisar do
rebaixamento. Varredura seguinte: `ALTA: 0`, exit `0`.

#### Onde o guarda-corpo generico nao serve, e o que ficou no lugar

`Find-CampoSemLeitor` mede **acesso a membro** (`$cob.X`), que e o proxy certo para o scanner — la a
cobertura vira prosa composta campo a campo. No doctor ela e serializada inteira, entao o guarda
acusaria todo campo, inclusive os que chegam. Forcar `$cob.X` no relator para satisfaze-lo seria
culto de carga: passaria a medir a forma, nao o fato.

O fato tem caso proprio, e mais forte: *"doctor: toda chave de Cobertura chega ao relatorio E ao
JSON"*. A razao esta escrita em `tests/suites/scripts.ps1`, no ponto em que alguem tentaria
estender o guarda — para nao virar ponto cego por esquecimento.

#### Decisoes de governanca aplicadas

| Decisao | Como entrou |
|---|---|
| **Item 9** fora do escopo da 2.5 | continua no backlog, e continua marcado como obrigatorio **antes de qualquer publicacao publica real** |
| **Item 33** | par negativo e exigido quando a falha da pre-condicao puder causar vacuidade, mascarar o ramo exercitado ou deixar o teste passar pela razao errada — nao para toda pre-condicao trivial. Os casos do doctor seguem isso: as pre-condicoes que **discriminam** tem assercao propria |
| **`ambiente.dependencias`** | extensao aditiva, na plataforma e no template. Semantica implementada e medida, caso a caso |

#### O que NAO entrou, de proposito

Nada que rode a suite. Nada que varra conteudo. Nenhum julgamento de qualidade. Nenhuma correcao
automatica. Nenhuma consulta de rede. E nada de integracao: o contrato da saida estruturada foi
**desenhado e versionado** por `schema_version`, para a Fase 3/4 nao ter de parsear Markdown — mas
Orchestrator, n8n, CI e Project Registry continuam fora.

### Plano da 2.5 — **delta aprovado em 2026-09-17**, implementado em 2026-09-18

> A mantenedora aprovou o plano **conceitualmente**, com cinco ajustes. Eles estao incorporados
> abaixo e **substituem** o que o plano original dizia nos pontos em que divergem. A implementacao
> ainda **nao** foi autorizada.

#### 1. Frescor de `tests` e `security` — quatro estados, nunca dois

O doctor **nao roda** nenhuma das duas. Ele le o artefato que elas deixaram e distingue:

| Estado do artefato | Status | Por que |
|---|---|---|
| corresponde ao `HEAD` atual | `PASS` | a evidencia descreve este codigo |
| **inexistente** | `WARN` | fato **determinado**: nunca rodou aqui. A acao e clara — rode a ferramenta |
| existe, mas de **outro `HEAD`** | `WARN` | fato determinado: a evidencia e velha, e o doctor diz de qual sha ela e |
| **invalido ou incompleto** | `INCONCLUSIVO` | o doctor **nao conseguiu determinar** a que estado o artefato se refere |

**A regra que separa `WARN` de `INCONCLUSIVO` e uma so:** `WARN` e "eu determinei o fato, e o fato e
ruim"; `INCONCLUSIVO` e "eu nao consegui determinar". Artefato sem carimbo de `HEAD`, truncado, ou
que o doctor nao consegue ler cai no segundo — e `INCONCLUSIVO` domina, saindo com `2`.

**"Nao existe evidencia recente" nunca e `PASS`.** E a mesma politica 4.5 que o scanner ja aplica,
aplicada ao frescor. O doctor **nao** reexecuta nada para descobrir: ele relata o carimbo.

#### 2. Dependencia so e cobrada quando o projeto declara que usa

`gh`, `.venv`, Python, Node: **ausencia nao e diagnostico negativo por si**. O doctor cobra quando,
e somente quando:

- o **manifesto declara** que o projeto usa a ferramenta; ou
- uma **capacidade declarada** depende dela — o caso concreto e `verificacao.comando`, que nao roda
  sem a trilha que ele nomeia.

Assim, `gh` ausente num projeto que nao usa GitHub nao produz nada. **Declarada e ausente** produz
`FAIL` quando bloqueia a verificacao declarada, e `WARN` quando nao bloqueia.

**O caso que o ajuste abre, e que precisa de decisao:** projeto que **nao declara** dependencia
nenhuma. O doctor nao tem o que cobrar — e tambem nao pode dizer `PASS`, porque nao verificou nada.
A dimensao sai `WARN` com a acao *"declare `dependencias` no `project.yaml`"*. E o campo
`dependencias` nao existe no manifesto hoje; a 2.5 o cria, e isso atravessa o template.

#### 3. Resolucao da raiz — a primeira camada, com sete casos

Mantida. **Antes** de chamar `Get-CaminhosDoGit`, `Test-TemHistorico` ou `Test-HeadResolvivel`, o
doctor resolve a raiz real do repositorio, com o mesmo rigor de que "nao consegui determinar" nunca
vira falso verde. Casos exigidos:

| Caso | Resultado esperado |
|---|---|
| execucao na **raiz** | resolve, e e o proprio caminho |
| execucao em **subdiretorio** | resolve para a raiz, e todo o resto do doctor opera sobre ela |
| **worktree ligado** | resolve; `GitDir` e `ComumDir` diferem, e a diferenca e respeitada |
| **`.git` como arquivo** | resolve (worktree, submodulo, `--separate-git-dir`) |
| **repositorio recem-inicializado** | resolve; `HEAD` nao nascido e histórico vazio sao **esperados** |
| caminho que **nao pertence a repositorio nenhum** | resposta explicita, nao excecao |
| **bare repository** | resposta explicita `nao suportado` → `INCONCLUSIVO`, nunca `PASS` nem crash |

Os itens 21 e 25 do backlog sao exatamente estes dois ultimos, e deixam de ser teoricos aqui.

#### 4. O doctor e **estritamente diagnostico**

Ele **pode** dizer *"proxima acao recomendada: rode `/os:security`"*. Ele **nao** executa essa acao,
nao corrige arquivo, nao toca em Git — nem `add`, nem `config`, nem `gc`.

**Criterio de aceite mensuravel, e nao so uma promessa na prosa:** um caso que roda o doctor sobre
uma fixture e prova que a arvore e o `.git` ficam **byte a byte identicos** antes e depois, exceto
o relatorio que ele escreve. Ferramenta que conserta sozinha esconde o problema que deveria mostrar.

#### 5. Saida estruturada — contrato minimo, sem integracao agora

Alem do relatorio humano, um arquivo de dados para o Orchestrator, n8n, CI e Project Registry
consumirem na Fase 3/4 **sem parsear Markdown**. Desenho do contrato, nao integracao:

```
schema_version      inteiro; quem consome compara antes de ler o resto
status              PASS | WARN | FAIL | INCONCLUSIVO  (o pior das dimensoes)
exit_code           0 | 1 | 2                          (coerente com status)
head                sha do HEAD, ou null com motivo declarado
timestamp           ISO 8601 com fuso
dimensions[]        { nome, status, motivo, verificacoes[] }
findings[]          { severidade, dimensao, mensagem, caminho?, acao? }
coverage            { o que foi verificado, o que NAO foi, e por que }
recommended_actions[]  { comando, porque }  -- texto, nunca execucao
```

**`schema_version` e o campo que o exemplo da mantenedora nao trazia, e e o que mais importa:**
sem ele, a primeira mudanca de formato quebra em silencio quem ja estiver consumindo. Regra que
entra junto: campo nunca e removido nem tem o significado trocado sem subir a versao.

`coverage` e obrigatorio pelo mesmo motivo que existe no relatorio de seguranca — consumidor que
recebe `status: PASS` sem saber o que **nao** foi verificado repete o erro que esta plataforma
passou treze rodadas corrigindo.

### Plano da 2.5 — apresentado em 2026-09-17, **aprovado em 2026-09-18 e implementado**

> Registro histórico do plano **como foi apresentado em 2026-09-17**. O que de fato foi construído
> está na seção da subfase 2.5, acima. Esta seção **não é instrução de trabalho pendente**.
>
> A frase seguinte é do momento da apresentação e ficou aqui como estava, em vez de ser reescrita
> — mas ela **contradizia o título** logo acima, e o `qa-reviewer` a derrubou na sétima rodada.
> Fica citada, e datada, para não voltar a ser lida como corrente:
>
> *"Este plano foi apresentado e ainda não foi aprovado. Nada dele deve ser implementado antes
> disso. Está registrado aqui porque plano que vive só na conversa não é plano — se a sessão
> sumir, some o desenho."* — escrito em 2026-09-17, **superado pela aprovação de 2026-09-18**.

**Objetivo.** Responder a uma pergunta que nem `tests` nem `/os:security` respondem: **este
projeto é continuável sem a conversa?** O repositório sozinho basta para retomar, o que o
manifesto declara corresponde ao disco, e o estado do Git permite trabalhar. É diagnóstico de
**coerência do sistema**, não de comportamento nem de risco.

**As três perguntas, e por que não se sobrepõem:**

| Ferramenta | Pergunta |
|---|---|
| `tests` | o comportamento determinístico funciona? |
| `/os:security` | existe risco de exposição? |
| `/os:doctor` | o projeto como sistema é coerente, saudável e continuável? |

**Regra de separação — é o critério de aceite mais importante:** o doctor **nunca roda a suíte** e
**nunca varre conteúdo procurando segredo**. Se uma verificação precisa disso, ela pertence aos
outros dois; o doctor apenas **relata o que eles declararam**, com a data e o `HEAD` de quando
declararam.

**Dimensões:** retomabilidade (`STATE.md` com data, fase e próximo passo; ADRs referenciados) ·
coerência manifesto ↔ disco · estado do Git · ambiente (`git`, `gh`, `py`, `.venv`) · contrato de
portabilidade · frescor da verificação.

**Fontes de verdade:** `project.yaml`, `docs/STATE.md`, `docs/decisions/`, Git via os três
predicados, sistema de arquivos, `PATH`, e os **artefatos** de `tests` e `security` quando
existirem.

**Todas as verificações são determinísticas.** Nenhuma depende de julgamento de LLM: existência de
arquivo, leitura de campo, resposta do Git, presença no `PATH`, comparação de data e `HEAD`.

**Arquitetura:** `scripts/doctor.ps1` + `scripts/lib/doctor-*.ps1`, um módulo por dimensão, no
mesmo desenho dos detectores da 2.4 — cada módulo devolve `Achados` + `Cobertura` em `$cob`, e o
relatório declara o que **não** verificou.

**Status e códigos de saída:**

| Status | Quando | Exit |
|---|---|---|
| `PASS` | rodou e passou | contribui para `0` |
| `WARN` | rodou, achou desvio que não impede continuar | contribui para `0` |
| `FAIL` | rodou e achou o que impede continuar | `1` |
| `INCONCLUSIVO` | **não conseguiu rodar** | `2` |

**`exit 2` domina:** um `INCONCLUSIVO` no meio de tudo `PASS` sai `2`. "Não verifiquei" nunca vira
"está bom" — é a regra já estabelecida na 2.4, e o portão da coluna de cobertura e o acumulador de
lacunas têm de consumir **o mesmo fato**, que é a lição que custou seis rodadas.

**Comportamento por estado:** projeto novo (`git init` e para) — `HEAD` não nascido e histórico
vazio são **esperados**, `PASS` com nota, não `FAIL`; saudável — tudo `PASS`, exit `0`; degradado —
`WARN` (trabalho não commitado, verificação velha, `gh` ausente); quebrado — `FAIL` ou
`INCONCLUSIVO` conforme tenha conseguido medir.

**Arquivos.** Criar: `scripts/doctor.ps1`, `scripts/lib/doctor-*.ps1`, `skills/doctor/SKILL.md`,
`tests/suites/doctor.ps1`. Alterar: `scan-comum.ps1` (resolução de raiz), `docs/STATE.md`,
`CHANGELOG.md`, `project.yaml`, `run-tests.ps1`.

**Critérios de aceite.** Par positivo **e** negativo para cada verificação; nenhuma verificação que
não consiga rodar produz `PASS`; `exit 2` quando qualquer dimensão fica `INCONCLUSIVO`; casos para
os quatro estados; **não** executa a suíte nem varre conteúdo; relatório declara cobertura **e**
lacunas pelos dois portões.

#### O trabalho que vem ANTES de reusar os três predicados

`Test-TemHistorico`, `Test-HeadResolvivel` e `Get-CaminhosDoGit` são a base da dimensão Git, mas o
doctor é o **primeiro consumidor a rodar fora do contrato de entrada do scanner**, que exige
`.git` em `$Path`. Invocado de um subdiretório, `Get-CaminhosDoGit` devolve `$null` e todo ramo
negativo lança com diagnóstico errado.

**A 2.5 começa resolvendo a raiz do repositório** — `git rev-parse --show-toplevel` ou
equivalente —, com o mesmo rigor de que "não consegui determinar" nunca vira falso verde. Sem
isso, todo veredito do doctor sobre repositório invocado de subdiretório sai errado pela razão
errada.

#### Itens de backlog que deixam de ser teóricos quando o doctor existir

| Item | Por quê |
|---|---|
| **21** | `Get-CaminhosDoGit` assume raiz — **condiciona a primeira linha de código da subfase** |
| **25** | repositório *bare* — mesma família |
| **29** | terceiro consumidor sem par de execução — o doctor vira o quarto |
| ~~**30**~~ | `ComumDir` sem caso — **fechado em 2026-09-17**, com worktree ligado |
| ~~**26**~~ | guarda de remoto público — **fechado em 2026-09-17**, quatro ramos |
| ~~**11**~~ | leitura `UTF8` dos detectores — **fechado em 2026-09-17**, corrigido |

#### O que **não** deve entrar na 2.5

- **Nada que rode a suíte.** Vira uma segunda suíte, lenta e redundante, e passa a falhar por
  motivo alheio ao diagnóstico.
- **Nada que varra conteúdo procurando segredo, credencial ou dado pessoal.** Isso é
  `/os:security`, que tem seis áreas, escada de severidade e mecanismo de exceção. Duplicar
  significa dois detectores divergindo em silêncio.
- **Nada que julgue qualidade** — se o código é bom, se o `STATE` está bem escrito. Não é
  determinístico e não é diagnóstico.
- **Nenhuma correção automática.** O doctor diagnostica; consertar é decisão da mantenedora.
  Ferramenta que conserta sozinha esconde o problema que deveria mostrar.
- **Nenhuma consulta de rede.** Visibilidade de remoto é do `security`; o doctor lê configuração
  local.

## Último checkpoint

`v0.1.0` — 2026-09-08. Fundação validada ponta a ponta: 5 skills, template, plugin em 4 camadas, 35 testes, e o ciclo real exercitado num projeto descartável.
