# ADR-0014 — Motor vNext em Python stdlib; registry em YAML por projeto; níveis L0–L6 derivados de fato

- **Data:** 2026-10-08
- **Status:** Aceita
- **Fase:** programa vNext, Fases 2–3

## Contexto

O programa exige registry canônico, contrato de projeto versionado e validado, backup, restore,
check e certificação de portabilidade, saúde separada em segurança × operação, e respostas
objetivas ("posso apagar a pasta?"). A plataforma é PowerShell 5.1. O runbook de armadilhas registra
o custo disso: caixa insensível, `\` que não escapa, encoding, CRLF, `TryParse` dependente de
cultura, stderr virando erro terminante. O 5.1 também não tem SQLite nativo nem YAML, e snapshot
consistente de banco vivo é requisito do programa (§14).

## Decisão

1. **Motor `eos/` em Python 3, só com a stdlib**, rodado por `py -3.13 -m eos`. Só stdlib porque o
   motor precisa funcionar numa máquina recém-formatada antes de qualquer `pip`: é ele que
   restaura o resto. Há guarda que falha se aparecer `import` fora da stdlib. Os scripts
   PowerShell existentes (scanner, doctor, hooks, fluxo) **não são reescritos**: o motor os compõe.
2. **Registry: um YAML por item** em `registry/projects/<id>.yaml`, versionado. O índice SQLite
   (`%LOCALAPPDATA%\emmily-os\registry.db`) é **derivado**: `eos index` o reconstrói, e ele nunca é
   lido como fonte de verdade. O YAML é um subconjunto estrito (`eos/yamlite.py`), que recusa fluxo
   (`[a, b]`), âncora, bloco literal, TAB e chave duplicada, citando a linha. Recusar é melhor que
   ler errado: o leitor de manifesto da plataforma já leu lista de fluxo como um valor só
   (backlog 42).
3. **Contrato v1** (`eos/contract.py`): campo desconhecido é erro, enum fora do vocabulário é erro,
   e `PROJECT` exige `workspace`, `git`, `cloud`, `backup` e `portability`. O contrato declara
   **intenção**. Estado medido não mora nele: nível, saúde e último backup são derivados por
   verificação. A única exceção é o bloco `certification`, que é evidência de um evento passado.
4. **Níveis cumulativos, derivados de fato** (`eos/portability.py`):

   | Nível | Exige, além do anterior |
   |---|---|
   | L1 | repositório com commit (unborn é L0: Git existir não é proteção) |
   | L2 | remoto **privado** confirmado pela API, toda branch e tag publicada (`ls-remote`) |
   | L3 | na nuvem: bundle com as refs atuais, WIP com impressão digital igual à atual, bancos sem mudança desde o snapshot |
   | L4 | manifesto de ambiente e bootstrap; manifesto de segredos (só nomes); nenhum `.env` rastreado |
   | L5 | estado canônico neutro de provedor presente e não mais velho que o último commit |
   | L6 | certificação por restauração isolada aprovada há no máximo 30 dias |

   `UNKNOWN` nunca conta como `PASS`. "Posso apagar a pasta local?" é SIM só a partir de L3, e só
   se **nada existir apenas nesta pasta** (`portability._so_nesta_pasta`). Cada um destes casos
   impede o SIM:
   - pasta de dados `cloud-mirror` (o espelho de dados ainda não existe, e o motor não finge que
     existe);
   - `.env` com `secrets.store: local-env`, porque os valores só existem aqui;
   - arquivo ignorado que o contrato não declara;
   - arquivo em `backup.exclude` (excluir do upload não é o mesmo que poder perder);
   - submódulo ou repositório embutido;
   - stash.

   "Posso trocar de computador?" é SIM a partir de L5, **e** só se nada existir apenas nesta pasta.
   Trocar de computador também deixa a pasta para trás, então os mesmos casos que bloqueiam o
   apagar bloqueiam a troca. *(Revisado em 2026-10-11, após as rodadas r1 a r3 da revisão
   independente do motor e a pré-revisão adversarial do `c0887c2`. Esta última provou que o L5
   respondia SIM com um `.env` local e um ignorado não declarado. A versão anterior citava só o
   `cloud-mirror`.)*

   > **EMENDA 2026-10-12 (rodada r9) — o espelho de dados passou a existir.** O texto acima ("o
   > espelho de dados ainda não existe") era verdade até o commit `e3da8e1` e fica como registro
   > histórico. Desde então, `eos mirror <id>` (`eos/mirror.py:espelhar`) copia cada `data[]` com
   > `policy: cloud-mirror` para `<cloud.drive_root>/dados/<path>`. A cópia é **aditiva** (nada é
   > apagado na nuvem) e incremental por tamanho + md5. A versão substituída é preservada antes em
   > `<drive_root>/dados-anteriores/<ts>/<path>`. Nome de segredo e symlink/junção são recusados, e
   > cada arquivo é conferido (tamanho + md5) **depois** da cópia. O manifesto vai para
   > `99 RECOVERY/manifests/<id>/mirror-<ts>.json`, com cópia no journal da máquina.
   >
   > Com isso, o caso `cloud-mirror` deixou de bloquear **sempre**. `_so_nesta_pasta` agora
   > pergunta a `eos/mirror.py:motivos_so_aqui`, que considera a pasta coberta só se o **último
   > espelho com `ok: true`** tiver cada arquivo atual com o mesmo tamanho e `mtime`. Arquivo novo
   > ou alterado depois do espelho, arquivo recusado (nome de segredo, symlink) ou nuvem ilegível
   > continuam impedindo o SIM. A certificação (item 6) **não** baixa os dados; quem baixa e confere
   > é `eos restore <id> --para <dir> --com-dados`. O resto desta decisão não muda.
5. **Segurança × operação.** `SAFE` a partir de L3. Fonte externa obrigatória indisponível (por
   exemplo, o SharePoint) derruba só a **operação** para `DEGRADED`, nunca a segurança.
6. **Certificação** restaura num temporário isolado. O histórico vem do GitHub (quando há
   remoto), completado pelo bundle da nuvem com as refs que o remoto não tem. A certificação
   confere refs, HEAD, impressão do WIP de cada worktree, hash e `integrity_check` dos bancos e a
   presença do estado canônico, e roda o `smoke_command` **dentro do restore** com
   `PROJECT_ROOT` apontando para ele. Sem `smoke_command` declarado, reprova. A evidência vai para
   `manifests/<id>/cert-<ts>.json` na nuvem.
7. **Adaptadores de IA derivam do core.** O estado canônico é `docs/STATE.md`, os ADRs e
   `AGENTS.md` (lido por Codex e outros). `CLAUDE.md` é adaptador. O contrato declara os dois
   (`ai.canonical`, `ai.adapters`), e o L5 exige o canônico.

## Alternativas consideradas

- **Motor em PowerShell 5.1.** Rejeitada pelos motivos do contexto, e porque um snapshot de banco
  dependeria de um `sqlite3.exe` que não existe na máquina.
- **PyYAML / pydantic.** Rejeitadas: dependência instalada antes do restore é um problema circular.
- **SQLite como registry canônico.** Rejeitado pelo programa (§9): binário, sem diff e sem revisão.

## Consequências

- O runner da plataforma ganha a suíte `vnext`, que roda o `unittest` do motor em processo separado
  e os guardas estruturais.
- Duas linguagens na plataforma. Fronteira: PowerShell para o que já existe e para a integração com
  o Git do dia a dia; Python para o motor de continuidade.
- O `project.yaml` da plataforma passa a declarar `python: "3.13"` quando o motor entrar no `main`.
