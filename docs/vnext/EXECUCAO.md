# Programa vNext — estado de execução

> Fonte canônica do **andamento** do programa (`PROGRAMA-VNEXT.md`). Decisões estão nos
> ADR-0012 a 0018; o journal detalhado (eventos, saídas brutas) vive em
> `C:\AI-WORKSPACE\_platform\_runs\RUN-20261008-001\`, fora do repositório, com cópia no Drive.
> Se este arquivo e o journal divergirem, **o disco, o Git e a nuvem vencem**: reconcilie antes de agir.

## Gates

| Gate | Estado | Evidência |
|---|---|---|
| `RECOVERY_2_7_GATE` | **PASS** — 2026-10-08 | rodada 7 APROVADO nos dois revisores; `15e4496` no `main` e no remoto |
| `PRESERVATION_GATE` | **PASS** — 2026-10-08 | 12 projetos preservados (refs, WIP de 12 árvores sujas, 2 bancos); 449 arquivos no Drive, `rclone check` 0 diferenças; completude conferida contra o estado atual de cada projeto |
| `PORTABILITY_LAB_CERTIFICATION` | **PASS** — 2026-10-08 | `emmily-portability-lab` certificado **L6**; restore também provado pelo transporte Drive Desktop |
| `EMMILY_AI_PROJECT_OS = L6` | **PASS** — 2026-10-11 | `eos certify emmily-ai-project-os` APROVADA sobre `5a1dfd7` |

## Fases

| Fase | Estado |
|---|---|
| −1 Recovery 2.7 | concluída |
| 0 Preflight | concluída — inventário em `RUN-20261008-001/F0-preflight/INVENTARIO.md` |
| 1 Preservação de emergência | concluída — `99 RECOVERY/emergency-preservation/RUN-20261008-001/` |
| 2 Portability Lab | concluída — L6 |
| 3 Core vNext | **concluída** em 2026-10-11. r1 e r2 reprovaram nos revisores formais. A r3 (`c0887c2`) passou por pré-revisão adversarial: 10 de 12 achados provados. A r4 (`508618f`) reprovou na revisão formal: `GIT~1`, o nome 8.3 do `.git`, passava pela recusa do restore, e a regra de nome de segredo deixava subir `.env.ps1`. A **r5** (`98a55da`, `d3458d5`) foi **APROVADA pelos dois revisores** (QA e Security). Evidência: 13 casos novos, 91 testes do motor, mutação 17/17, suíte 488/0, 0 lacunas, `registry-vs-disco` com 154 itens e 12 faltas anotadas. Os BAIXAs da r5 estão no backlog 146–149 do STATE. Integrada no `main` por fast-forward |
| 4 Plataforma em L6 | **concluída** em 2026-10-11: `main` em `5a1dfd7` (publicada), backup e `eos certify` APROVADA, **L6** |
| 5 Registry | **30 contratos** em `registry/projects/` (22 PROJECT, 4 COLLECTION, 3 ARCHIVE, 1 EXTERNAL_SOURCE; 2026-10-16), validados; todo PROJECT com seção `ownership` (ADR-0018) |
| 6 Migração | ver tabela abaixo |
| 7 Acervos | **concluída** (2026-10-11), conservadora: nada movido, apagado ou mesclado; origens intocadas. Cópia de proteção dos acervos no Drive (`rclone check` 0 diferenças). Classificadas: TRABALHO SISTEMAS e P1 HIDROLOGIA (COLLECTION UNIVERSITY), teste claude (ARCHIVE; não é cópia do Projeto Pessoal A), Documents/Codex (COLLECTION LAB), acervo Dynatest (COLLECTION-mãe, **não** monorepo). **Decisões da mantenedora (2026-10-11) aplicadas:** (a) cada automação real do acervo Dynatest virou PROJECT com repo próprio em `${AI_WORKSPACE}\work\prog\`: `prog-gerador-dossie` (com o antecessor DOSSIE SCRIPT CIS no 1º commit e o código do zip V005 na branch órfã `archive/v005-capas-com-borda`), `prog-prestacao-contas-automacao` (variante "DEU CERTO" no 1º commit), `prog-indice-produtos`, `prog-criador-pastas`, `prog-grd-certificadora`, e o ARCHIVE `prog-automacoes-arquivo`; categoria **PROG** pela evidência no código (nenhum item Dynatest não-Programa comprovado; domínio dynatest na descrição). Cópia fiel por SHA-256 contra origem e levantamento (`CHECKPOINTS/automacoes-prog/`), 13 arquivos só-nuvem baixados pela leitura; zip V005 (175 MB, só-nuvem, com 2 arquivos de código únicos) protegido no Drive. (b) **Empresa X Gestão** = PROJECT próprio (`${USERPROFILE}\EmpresaX_Gestao`, PORTFOLIO, domínio empresax), independente do Portfolio; cópia fiel da instância de Downloads (= pacote de entrega), `npm test` 18/18 e build ok; fora do Git no Drive (marketing com GPS no EXIF, inventários com nome de terceiro, capturas de QA); SWITCH da instância de uso é ação da mantenedora (passo a passo no STATE do projeto). (c) `engenharia-rodoviaria` = **Programa**, `drive_root` `01 PROG/` (cópia server-side conferida), **REMOTE_STATUS = BLOCKED_BY_EXTERNAL_LICENSE**. Levantamentos: `SURGE/fase7-dynatest-automacoes.md`, `SURGE/fase7-empresax-gf.md`. NEEDS_VERIFICATION registrados nos contratos (versão canônica da prestação de contas, `analisar_empresas.py`, destino do mapeamento SharePoint e da lista mestre, GRD Certificadora PROJECT×ARCHIVE, IndexedDB do GF) |
| 8 Certificação DR | **concluída** (2026-10-11). **L6 e SAFE (14):** plataforma, conversor-utm, portability-lab, Dashboard, Cérebro, Grupo1, Semanal, SharePoint (recertificado com o Parceiro), Escritório Jurídico, Empresa X Portfolio, Organizador, Projeto Pessoal A, **G2** (STATE da mantenedora commitado verbatim em `947418e` + nota de infra `fc7fcb8`; certificação APROVADA sobre `fc7fcb8`). **Restauração certificada, nível L1 só por falta de remoto (8):** `empresax-gestao`, os 5 PROJECT Programa extraídos, `prog-automacoes-arquivo` (ARCHIVE) e `engenharia-rodoviaria` (remoto bloqueado por licença). Os 7 novos não têm remoto porque `gh repo create` foi **negado pela permissão do ambiente (H2)**; nada contornado. Defeitos achados pela certificação de projetos reais ao longo da fase: matplotlib não declarado no G2, `git add -N` no motor (r6/r7), smoke do Dashboard dependente da fonte real, `requirements.txt` com acento no Grupo1. Backlog novo: 156 (scanner aborta com nome não-ASCII), 157 (scanner grava `artifacts/` no WIP de repo que não o ignora) **Atualização 2026-10-12:** os 7 novos ganharam remoto privado; os 6 PROJECT foram recertificados em **L6**, assim como o `emmily-os-calendar-sync`. Resultado: **20 de 21 PROJECT em L6**, e o `engenharia-rodoviaria` fica em L1 até a decisão H4 sobre proveniência e remoto. **Atualização 2026-10-16:** H4 opção C aplicada; **22 de 22 PROJECT em L6 SAFE** (inclui `lab-prova-eos-new`) |
| 9 Limpeza | **concluída em 2026-10-16** (H2 da titular: 35 worktrees redundantes, duplicata E3, cópias D1/D6 e exe do Gerador removidos com sha256 recalculado no momento; D4 KEEP; Downloads do GF redundante e mantida — `SURGE/fase9-*-20261016.md`). Antes: **executada com prova, parcial** (2026-10-15, H3 da titular em `SURGE/decisoes-h3-h4-20261015.md`). Removido só o que tinha backup + hash/equivalência + redundância provados: F4, F1, A2a/b/d, A3a (arquivado antes), A4a, A5, A6, E1a, B1–B4 `gc` (objetos provados nos bundles), D3 (exes no Drive `releases/`), D5, D7, D8, D10, C2 `tmp/` — ≈ 4,2 GB. C1b: 208 saídas únicas das worktrees do G2 no Drive (sha256 do servidor conferido). **Bloqueado pelo classificador do ambiente** (não contornado): `git worktree remove` C1a/C1b/C2, `rclone purge` E3, cópia do IndexedDB do GF. KEEP/NEEDS_VERIFICATION: D4, D6, (CÓPIA) do D1, Downloads do GF, "Prestação de contas - Copia DEU CERTO". **Complemento 2026-10-16 (H2 da titular):** 35 worktrees redundantes removidas (G2 28, Cérebro 7; 6 KEEP no G2 por WIP/junção `.venv`), E3 na lixeira do Drive após `check` 234/234, D1 47 + D6 18 cópias e o exe do Gerador removidos com sha256 recalculado no momento; D4 PDFXEdit KEEP (SOFTWARE/TOOL); cópia bruta do IndexedDB do GF no Drive (7/7 sha256) |
| 10 Programa final | **COMPLETE em 2026-10-16** — `docs/FINAL-ACCEPTANCE.md` (reavaliado depois das decisões da titular de 2026-10-16: 20 critérios PASS, branch protection N/A, revisão final de QA registrada no journal; verificação pós-conclusão do token do rclone em 2026-10-23) |

## Programa final (F10, 2026-10-12)

| Frente | Estado |
|---|---|
| Remotos dos 7 projetos novos | **feito**: `gh repo create --private` liberado pela instrução de 2026-10-12; varredura pré-push com exceções estreitas do ADR-0017; os 6 PROJECT em **L6**, o ARCHIVE certificado |
| Reconciliação do ecossistema | +`emmily-os-calendar-sync` (PROJECT PERSONAL, L6; teste do próprio projeto corrigido, 104/104) e +`codigos-trabalho-mecanica` (ARCHIVE UNIVERSITY, bundle no Drive) |
| Ownership & provenance | `eos ownership-check | ownership-certify | ownership-init` (ADR-0018); arquivos de proveniência em 20 repos; **19 certificados PASS**; engenharia-rodoviaria (em 2026-10-11) **EM APURAÇÃO** (forense INDETERMINADO → H4) |
| Assinatura | SSH signing ativo (commits e tags); chave registrada no GitHub (2026-10-15): commits **verified** |
| engenharia-rodoviaria (H4 opção C) | declaração da titular, evidência original intacta, PROVENANCE, cópia sanitizada, remoto privado `prog-engenharia-rodoviaria`, mirror, **L6**, ownership PASS, `-ParaPublicacao` 0/0/0 |
| Cofre | `.env` de G2, Cérebro e SharePoint no Bitwarden; contratos `store: bitwarden` |
| Prova do `eos new` | `lab-prova-eos-new` nasceu em **L6** (assinado/verified, remoto PRIVATE, Drive, backup, certificação) |
| Nascimento protegido | `eos new` (registry, workspace, Git assinado, varredura, remoto privado, Drive, backup, ownership, adapters) |
| Dados fora do Git | `eos mirror` (cópia aditiva conferida por md5) e `restore --com-dados`; o check passa a considerar o espelho |
| Scanner / coletor | 156 e 157 corrigidos; coletor sem citação octal; legibilidade de blob do histórico pelos bytes |
| Documentação | `docs/user/` (16 + índice), `docs/architecture/...TECHNICAL-REFERENCE.md`, `docs/runbooks/maquina-nova.md`, kit `99 RECOVERY/disaster-recovery/` no Drive |
| Revisão independente | r8, r9 (os dois), r10 e r11 (QA) reprovadas e corrigidas com teste que falha no código antigo; **r12 e r13 APROVADAS** por QA e Security; integrada no `main` (`bac545c`). Guarda de git (2026-10-16): rodada 1 e r14–r18; código **APROVADO** por QA e Security na r18, registro corrigido em `d6d85ce` (journal `SURGE/revisao-r14-r16-achados.md`) |
| Proteção server-side | indisponível no plano gratuito (rulesets/branch protection = GitHub Pro); fica a proteção client-side do ADR-0011 |

## Remotos privados (autorizados pela mantenedora em 2026-10-11; política no ADR-0015)

| Projeto | Remoto | Como |
|---|---|---|
| conversor-utm | `lab-conversor-utm` | push direto |
| prog-relatorio-g2 | `prog-relatorio-g2` | push direto, 36 refs conferidas |
| prog-dashboard-juridico | `prog-dashboard-juridico` | push direto |
| organizador-dynatest-pessoal | `personal-organizador-dynatest` | push direto (ADR-0016) |
| prog-cerebro-documental | `prog-cerebro-documental` | push direto: documentos brutos medidos sem dado pessoal |
| prog-relatorio-grupo1 | `prog-relatorio-grupo1` | push direto: idem |
| empresax-portfolio | `portfolio-empresax` | **primeiro commit já sanitizado** (`db7943c`): contatos fora do Git em arquivos `.local` ignorados; HTML do portfólio byte a byte idêntico |
| exemplo-pessoal-a | `personal-exemplo-pessoal-a` | **histórico sanitizado adotado** (gate H3, 2026-10-11) e publicado |
| prog-relatorio-semanal | `prog-relatorio-semanal` | **sanitizado em 2 passadas** (a 2ª pegou CPF de assinatura digital que a 1ª não cobria) e publicado. `output/visual_review/golden/` (35 PNG) **saiu do rastreamento e do histórico publicado** (force push autorizado e feito em 2026-10-11; `63be648`, decisão da mantenedora de 2026-10-11), com os originais no Drive. (O espelho de `_recovery/sanitizacao-golden/` já foi adotado em 2026-10-11; não há force push pendente.) |
| prog-organizacao-sharepoint | `prog-organizacao-sharepoint` | sanitizado e publicado; `200_transferir.ps1` lê a conta do `.env` (valor resolvido idêntico ao antigo, por hash) |
| prog-repositorio-juridico | `prog-repositorio-juridico` | sanitizado (opção B) e **publicado** (`1edbb6d`) depois que a mantenedora confirmou, em 2026-10-11, que o e-mail Programa dos commits é dela/da equipe |

## Backups do motor (`eos backup`)

Todos os projetos Git têm backup do motor com manifesto no Drive (2026-10-08 e, para empresax,
organizador e Projeto Pessoal A, 2026-10-11). Depois da adoção do histórico sanitizado, novos backups em
2026-10-11 de Semanal, Escritório Jurídico, SharePoint, Empresa X e Cérebro, todos conferidos por hash.
Os bancos passaram por `integrity ok`: `organizacao.db` com 325 MB e `cerebro.db` com 958 MB. A auditoria de 2026-10-11 dos 9 `wip.tar.gz` já enviados não
achou nenhum patch nem arquivo com nome de segredo: o defeito da r2 (segredo dentro do patch) não
se materializou.

## O que a preservação de emergência cobre — e o que NÃO cobre

Cobre, por projeto: `git bundle --all` (com o HEAD de toda worktree conferido como alcançável), o
WIP de cada árvore suja (arquivos inteiros + `staged.patch` + `unstaged.patch` + status), e os
bancos `cerebro.db` e `organizacao.db` por API de backup do SQLite (`integrity_check` ok).

**Não cobre**, e isso é declarado, não esquecido:
- pastas de saída e dados ignorados (`output/` do Grupo1 6,1 GB, do Semanal 994 MB, do G2 332 MB;
  `data/` do Dashboard), que entram na política de dados por projeto;
- os backups antigos de banco do Cérebro (`data/backup/`, cerca de 7 GB), que são histórico e não
  estado vivo;
- `.env` e qualquer arquivo ignorado, nunca copiados de propósito;
- `.venv` e `node_modules`, reconstruíveis.

## Ações humanas recomendadas (nenhuma bloqueia agora)

1. **H1/H2 — `client_id` próprio do rclone.** O rclone avisa que o client compartilhado deixa de
   funcionar durante 2026, e refazer o login também resolve a pendência T-09 (token exposto num log
   em 01/10). O transporte Drive Desktop cobre a falta até lá. **Feito em 2026-10-16:** client OAuth
   próprio (`emmily-os-rclone`, *In production*), remoto `gdrive:` com o mesmo nome; ver ADR-0013,
   emenda.
2. **H1 — Bitwarden CLI**, quando chegar a fase de segredos e de criptografia de backup.

## Decisões da mantenedora já levantadas, com relatórios no journal (`RUN-20261008-001/SURGE/`)

- **Gate H3, sanitização de histórico** (Projeto Pessoal A, Semanal, Repositório Jurídico, Organização
  SharePoint): plano completo e simulado em `plano-adocao-sanitizacao.md`. O procedimento troca as
  refs atomicamente e preserva o WIP; os testes passam no HEAD sanitizado. Três decisões:
  - Escritório Jurídico: opção B;
  - Semanal: 67 PNG incertas e branches `worktree-agent-*`;
  - SharePoint: patch do `200_transferir.ps1`.
- **Fase 7, acervos:** `acervos-fase7.md`, com 16 contratos propostos e decisões listadas.
  Achado de risco: cerca de 10 automações com código só no OneDrive (Dynatest Engenharia -
  Pessoal), sem Git.
- **Ambiente por projeto:** `ambiente-por-projeto.md` (já aplicado ao registry), com 7
  pendências transversais.

## Para retomar

1. Leia este arquivo e o `RUN_STATE.json` do journal.
2. `git -C C:\AI-WORKSPACE\_platform\emmily-ai-project-os worktree list`: a worktree `vnext` deve
   existir.
3. `py -3.13 -m eos status` (na raiz da plataforma): o retrato atual de cada projeto registrado.
4. Continue pela primeira fase não concluída da tabela acima. Uma tarefa pesada por vez: a suíte e
   os revisores usam vários GB, e a máquina já ficou sem memória uma vez (2026-10-08).
