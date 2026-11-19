# Aceitação final — programa vNext (F10)

> Registro do fechamento do **FINAL AUTONOMOUS COMPLETION PROGRAM** (RUN-20261008-001). Primeira avaliação em
> 2026-10-15/16 (NOT COMPLETE por gates da titular). Reavaliação em 2026-10-16, depois das decisões da titular
> (`SURGE/decisoes-20261016.md`): uma primeira emissão COMPLETE (`198ddee`) foi **reprovada** pela revisão de QA e
> é substituída por esta. Cada linha diz o que foi medido, onde está a evidência e o veredito. Evidência bruta no
> journal `C:\AI-WORKSPACE\_platform\_runs\RUN-20261008-001\` (`EVENTS.jsonl`, `CHECKPOINTS/`, `SURGE/`); a cópia
> do journal no Drive (`99 RECOVERY/runs/RUN-20261008-001/`) é conferida por `rclone check` e o resultado gravado
> no próprio journal.

## Veredito

```
EMMILY AI PROJECT OS vNEXT: COMPLETE
PLATAFORMA: L6 SAFE · 22/22 PROJECT em L6 SAFE · guarda de git revisada (r14–r18: codigo APROVADO por QA e Security)
SAFE TO BEGIN NORMAL PROJECT WORK: YES
```

**Ordem do fechamento** (para que a declaração não fique à frente da prova): as medições abaixo foram feitas antes
deste commit; o commit desta aceitação é publicado e coberto por backup + check em seguida, e uma sessão limpa roda
sobre ele. Esses passos ficam no journal (eventos `pos-aceitacao`, `pos-aceitacao-2` e seguintes; sessão limpa:
`sessao-limpa-final*`), porque um documento não
pode registrar o resultado do próprio commit.

**Verificação pós-conclusão** (não bloqueia; o que ela confirma já foi testado): em **2026-10-23 ou depois**,
`rclone about gdrive:` sem pedir login prova que o token do client OAuth próprio, emitido com o app *In production*,
não expira em 7 dias. Se falhar: `rclone config reconnect gdrive:` (ADR-0013, emenda).

## Matriz de aceitação

| # | Critério | Resultado | Evidência |
|---|---|---|---|
| 1 | PLATFORM L6 | **PASS** — `eos certify` APROVADA (restauração + teste no restore) sobre `ef5a1d9`; `eos check` **L6 SAFE**, apagar sessão/pasta/trocar de PC = SIM, depois de publicar a única ref local pendente (branch de agente já contida na `main`). Para o HEAD final: o evento `pos-aceitacao` mais recente do journal | `CHECKPOINTS/final-certify-20261016-e.txt`, `final-check-20261016-f.txt` |
| 2 | ALL KNOWN ENTITIES GOVERNED | **PASS** — 30 contratos válidos (22 PROJECT, 4 COLLECTION, 3 ARCHIVE, 1 EXTERNAL_SOURCE); o único repositório público (`emmily-os-oauth-pages`) é governado pelo ADR-0019, fora do registry de propósito; 9 itens `NEEDS_VERIFICATION` em notas de 8 contratos ficam como pendência informativa (decisão 6 da titular: não bloqueiam) | `registry/projects/`; ADR-0019 |
| 3 | ALL ELIGIBLE PROJECTS MIGRATED | **PASS** — o último pendente, o GF, fez o SWITCH: backup in-app da titular (641/641 DEMO, sha256 `203b0ba6…` igual no Drive), servidor do repo conferido na 4173 (`index.html` servido = `dist/index.html`), certify L6 | `CHECKPOINTS/gf-backup-conferencia-20261016.txt`, `gf-servidor-repo-20261016.txt`, `gf-certify-20261016.txt`; STATE do GF (`b66477a`) |
| 4 | ALL ELIGIBLE PROJECTS REMOTE-PROTECTED | **PASS** — 22/22 PROJECT com `clone=SIM pc=SIM` no status do portfólio sobre `0f1b983`; `gh repo list`: 24 privados + 1 público (ADR-0019) | `CHECKPOINTS/status-final-20261016-h.txt`; `evidencias-finais-20261016.txt` |
| 5 | GOOGLE DRIVE RECOVERY COMPLETE | **PASS** — rclone com **client OAuth próprio** (app *In production*, publicado pela titular), único remoto `gdrive:` com `client_id`/`secret`, nenhum aviso de client compartilhado; leitura, escrita controlada, backup, restore (certify L6) e mirror testados. Escritório Jurídico: H4 **MANTER**, `decisao_pendente` removido, mirror/backup/certify L6 | `CHECKPOINTS/rclone-own-*`, `evidencias-finais-20261016.txt`, `juridico-*-20261016.txt`; ADR-0013 emenda |
| 6 | BITWARDEN/SECRETS PORTABLE | **PASS** — `.env` dos projetos no cofre; client OAuth do rclone no item `rclone-gdrive-oauth-client` (existência atestada pela conferência da titular — o bloco só gravava o remoto com ID terminando em `.apps.googleusercontent.com` e secret não vazio lidos do item — e indiretamente pelo remoto funcionando com client próprio; não há saída de `bw get`, de propósito); `cofre.manifest` com quatro nomes; histórico da plataforma e do repo de páginas sem formato de client Google (0) | `cofre.manifest`; `evidencias-finais-20261016.txt` |
| 7 | OWNERSHIP & PROVENANCE ACTIVE | **PASS** — ownership PASS nos 22 PROJECT; engenharia-rodoviaria com declaração da titular, provenance e cópia sanitizada; e-mail de 28/08 como `EXTERNAL_EVIDENCE_PENDING_VERIFICATION` (decisão 5 da titular: não invalida); nome de terceiro aceito por exceção (ADR-0010, emenda) | `status-final-20261016-h.txt` (`own=PASS`); contrato |
| 8 | CRYPTOGRAPHIC SIGNING ACTIVE / VERIFIED | **PASS** — commits assinados por SSH; `gh api`: `ef5a1d9`, `0f1b983` e o commit do repo de páginas `verified=true` | `evidencias-finais-20261016.txt`, `assinatura-0f1b983.txt` |
| 9 | NEW PROJECT AUTO-PROTECTION | **PASS** — `lab-prova-eos-new` nasceu em L6 e continua L6 SAFE | `eos-new-prova-20261015.txt`; `status-final-20261016-h.txt` |
| 10 | DISASTER RECOVERY CERTIFIED | **PASS** — todos os PROJECT certificados por restauração real (L6); plataforma recertificada sobre `ef5a1d9` | certificações por projeto; `final-certify-20261016-e.txt` |
| 11 | PHASE 7 COMPLETE | **PASS** — acervos classificados e protegidos (2026-10-11); GF migrado (2026-10-16) | `docs/vnext/EXECUCAO.md` |
| 12 | PHASE 8 COMPLETE | **PASS** — certificação DR (2026-10-11), mantida em todo PROJECT | idem |
| 13 | PHASE 9 COMPLETE | **PASS** — limpeza só com prova: ≈ 4,2 GB (2026-10-15) + 35 worktrees redundantes (6 KEEP por WIP/junção), duplicata E3 (lixeira do Drive, 234/234 iguais), cópias D1 (47) e D6 (18) e o exe do Gerador, todos com sha256 recalculado no momento; D4 PDFXEdit KEEP; `Downloads\EMPRESAX_GESTAO` redundante, protegida no Drive e **mantida** até a titular pedir | `SURGE/fase9-*-20261016.md`; `worktrees-remocao-20261016.txt`, `h2-duplicatas-remocao*.txt`, `e3-*` |
| 14 | USER MANUAL COMPLETE | **PASS** — `docs/user/00`–`15` presentes; 02, 06, 08, 09, 12, 13, 14 e 15 atualizados em 2026-10-16; suíte `docs` 20/0 | `docs/user/`; `suite-docs-*` |
| 15 | POP COMPLETE | **PASS** — `docs/user/03-POP-OPERACIONAL.md` | — |
| 16 | FLOWCHARTS COMPLETE | **PASS** — `docs/user/04-FLUXOGRAMA-DE-USO.md` | — |
| 17 | TECHNICAL REFERENCE COMPLETE | **PASS** — `docs/architecture/EMMILY-AI-PROJECT-OS-TECHNICAL-REFERENCE.md` (rclone próprio, guarda de git, cofre) | — |
| 18 | NEW MACHINE READINESS | **PASS** — `docs/runbooks/maquina-nova.md` e manual 09 com o procedimento do client OAuth a partir do Bitwarden; restauração provada por certify em pasta isolada. O bootstrap rclone+Bitwarden numa máquina nova não foi executado de ponta a ponta (só documentado) | runbook; certificações |
| 19 | SESSION INDEPENDENCE | **PASS** — `claude -p` sem histórico reconstruiu projeto, HEAD, testes, revisões, rclone, Escritório Jurídico, GF e próximo passo só pelo repositório | `CHECKPOINTS/sessao-limpa-20261016.txt` |
| 20 | FINAL CLEAN-SESSION ACCEPTANCE | **PASS** — critério: a sessão limpa reconstrói o estado e não acha **divergência material** (que leve a ação errada). Sessão sobre `0f1b983`: reconstruiu tudo e listou quatro imprecisões, nenhuma material — linha histórica do SESSIONS com `0.1.1`; "merge" para um avanço fast-forward; cabeçalho do STATE sem r17/r18; prova do HEAD final no journal —, corrigidas neste commit as três primeiras. A emissão de `0f1b983` escreveu "qualquer divergência" e o QA apontou que trocar o critério depois do resultado era defeito: o critério fica corrigido aqui, às claras | `CHECKPOINTS/sessao-limpa-20261016-final.txt` |
| — | Testes | **PASS** — coleta completa r16 sobre `5d32fcc`: 504/504, `unittest` Ran 371 OK (skipped=1). Depois mudaram o guarda (uma linha), o `hooks.json`, o teste do guarda e documentação: sobre `0f1b983` (o código e os testes desta aceitação; o commit dela só muda docs e um contrato), `unittest` do guarda 28 OK e suítes `plugin`/`policy`/`docs` verdes; a suíte `docs` roda de novo sobre o commit desta aceitação (evento `pos-aceitacao` mais recente) | `diff-report-r16-20261016.md`; `guarda-unittest-0f1b983.txt`, `suite-*-0f1b983.txt` |
| — | Segurança | **PASS** — `security-scan` completo ALTA 0 (MEDIA 2 sob exceção ADR-0010; o único blob não lido é o blob vazio canônico `e69de29b`); pre-push com histórico em todo push | `security-report-r18-20261016.md` |
| — | Revisão independente | **PASS no código** — guarda de git: rodada 1, r14, r15, r16, r17 e r18; na r18, Security APROVADO e QA APROVADO em correção, regressão e cobertura; o registro, corrigido em `d6d85ce`, foi conferido pela revisão final de QA da aceitação: REPROVADA sobre `0f1b983` (duas MEDIA de registro), APROVADA sobre `8b0c20b` com BAIXAs, das quais as que podiam levar a ação errada foram corrigidas em seguida. Os vereditos de cada rodada estão persistidos | `SURGE/revisao-r14-r16-achados.md` |
| — | Guarda contra git destrutivo | **PASS** — hook `PreToolUse` do plugin `os` `0.1.4`; teste ao vivo em sessão nova: `git checkout -- f.txt` BLOQUEADO com o arquivo intacto, `git status` sem mensagem de hook. O guarda ativo é o arquivo da worktree principal (marketplace de diretório); a falha é aberta e silenciosa (runbook) | `CHECKPOINTS/guarda-ao-vivo-0.1.4-20261016.txt` |
| — | Proteção server-side de branch | **N/A** — exige GitHub Pro; vale a proteção client-side (ADR-0011) e a guarda acima | — |

## Fatos de processo registrados

- r13: um implementador usou `git checkout -- tests/suites/scanner.ps1` em edições próprias não commitadas. O
  arquivo voltou idêntico ao HEAD (nada alheio perdido). **Prevenção:** a guarda acima.
- 2026-10-16: o teste ao vivo da guarda, feito depois do merge, achou dois defeitos que os testes unitários não
  pegavam (modo de fallback do Claude Code sem `shell`; código de saída do `powershell -Command`). No `0.1.2` um
  `git checkout --` passou num repositório descartável de teste. Corrigido no `0.1.3`/`0.1.4` e revisado (r17, r18).
- 2026-10-16: a primeira emissão COMPLETE (`198ddee`) foi reprovada pelo QA (declaração à frente da prova); a
  segunda (`0f1b983`) também (critério da linha 20 trocado depois do resultado; testes não rodados sobre o HEAD);
  esta versão as substitui e foi APROVADA pela re-revisão sobre `8b0c20b`.
- 2026-10-16: duas coletas completas foram encerradas pelo sistema por falta de memória e refeitas a pedido da
  titular; nenhuma tarefa pesada rodou em paralelo.
- Backlog BAIXA (não bloqueia): `restore.py` corta `erro` sem redação no ramo `com_dados`; md5 fora do `try` em
  `mirror.py`; `data[].path` em nome 8.3; padrões de client OAuth do Google no scanner; travessão como prefixo de
  opção no guarda; argumento do hook entre aspas duplas (um `$` no caminho do plugin seria expandido); remoto órfão
  `prog` (sem tipo, inutilizável) no `rclone.conf`; revogar o token antigo do rclone e apagar
  `~\.emmily-os\rclone.conf.bak-20261016` depois da verificação de 23/10; um doctor que confira se o guarda está
  ativo (hoje só o teste ao vivo prova).
