> **Especificação de origem** (2026-10-12) do motor de ownership e do `eos new`, copiada do journal
> (`RUN-20261008-001/SURGE/spec-ownership-novo-projeto.md`) para dentro do repositório (revisão r8, Q15).
> O comportamento implementado — que prevalece onde divergir — está em
> `docs/architecture/EMMILY-AI-PROJECT-OS-TECHNICAL-REFERENCE.md` §28 e no ADR-0018.

# Especificação — Ownership & Provenance + nascimento protegido (2026-10-12)

Fonte única para os agentes que implementam e documentam. O Lead integra.

## 1. Contrato v1 — seção nova `ownership` (opcional no schema; obrigatória por política para PROJECT novo)

```yaml
ownership:
  declared_owner: 'Emmily Maciel'          # titular DECLARADA (str, obrigatório na seção)
  owner_github: Emmilymaciell              # dono esperado do remoto (str, opcional)
  creators: [Emmily Maciel]                # strlist, obrigatório na seção
  contributors: []                         # strlist: contribuição real de terceiro, nunca apagar
  tool_accounts: []                        # strlist: contas/ferramentas usadas SEM autoria (ex.: conta Claude de colega)
  employer_or_client: PROG                 # str opcional: contexto contratual (não é autoria)
  license: proprietary                     # str: SPDX ou 'proprietary'
  third_party:                             # list de map: componente de terceiro (nunca reivindicado)
    - name: openpyxl
      license: MIT
      path: ''                             # opcional
  provenance_file: PROVENANCE.md           # str opcional (default PROVENANCE.md)
  signing: required                        # enum required | recommended | none
  identities:                              # strlist: identidades Git (nome <email>) que SÃO da titular
    - 'Emmily Maciel'          # so o NOME (decisao posterior: e-mail no registry e dado pessoal)
  evidence: []                             # strlist: notas factuais de evidência
```

`identity.type` ganha `REFERENCE_DATA` (classificado, sem nível, como ARCHIVE/COLLECTION).

## 2. `py -3.13 -m eos ownership-check <id> [--json]`

Read-only. Itens, cada um PASS / WARN / FAIL / N/A, com motivo:

| item | regra |
|---|---|
| declared_owner | seção `ownership` existe e tem declared_owner + creators (FAIL se PROJECT sem seção) |
| ownership_files | PROVENANCE.md e OWNERSHIP.md e AUTHORS.md (ou AUTHORS) existem no working tree (WARN se faltar) |
| notice | se third_party não vazio: NOTICE existe (WARN) |
| license | campo license preenchido; se != proprietary, arquivo LICENSE existe (WARN) |
| git_identities | todo autor/committer de `git log --format=%aN <%aE>` está em identities ∪ creators ∪ contributors ∪ tool_accounts (comparação por e-mail e por nome; FAIL = autor não explicado = contradição) |
| signing | git config efetivo do repo: gpg.format, user.signingkey (arquivo existe), commit.gpgsign=true; e % dos commits desde o primeiro commit assinado (`%G?`); `signing: required` sem config = FAIL; recommended = WARN |
| remote_owner | owner do `remote.origin.url` (github.com/<owner>/...) == owner_github (FAIL se diferente; N/A sem remoto) |
| codeowners | `.github/CODEOWNERS` (ou `CODEOWNERS`/`docs/CODEOWNERS`) cita @owner_github (WARN se faltar; N/A sem remoto) |
| manifest | último certificado de ownership (se existir) bate com o hash atual dos arquivos de ownership (WARN se divergir = arquivo mudou depois da certificação) |
| contradictions | lista agregada: texto em README/LICENSE/NOTICE/headers que atribui autoria a nome fora de creators/contributors (grep de `Author:`, `Autor:`, `Copyright`, `©`) — WARN com arquivo:linha |

Código de saída: 0 sem FAIL; 1 com FAIL; 2 erro.

## 3. `py -3.13 -m eos ownership-certify <id> [--tag]`

Roda o check; recusa com FAIL. Grava evidência JSON:
`{project, certified_at, head, ownership (seção do contrato), files: {path: sha256}, authors: [...], signing: {...}, remote, checks: [...], tool_version}`
- no ledger da nuvem (mesmo mecanismo do certificado de portabilidade: `cloud` store, pasta `ownership/` do projeto) **e**
- cópia local em `<repo>/.os/ownership-certificate.json`? NÃO — não sujar o WIP: grava só na nuvem + journal da máquina (`%LOCALAPPDATA%` ou o dir de estado do motor que já existe).
- `--tag`: cria tag ASSINADA `ownership-YYYYMMDD` no HEAD (falha fechado se a assinatura não estiver configurada).

## 4. Integrações

- `eos status`: coluna `own` (PASS/WARN/FAIL/-) por projeto (sem rede extra além do que já usa).
- `eos check <id>`: dimensão informativa `ownership` (NÃO altera a escada L0–L6).
- `scripts/doctor.ps1`: verificação de assinatura do próprio repositório da plataforma (gpg.format/signingkey/commit.gpgsign e HEAD assinado) — WARN, não FAIL.
- skill `session-close`: passo de rodar `ownership-check` quando o projeto tiver seção ownership.

## 5. `py -3.13 -m eos new <id> --name "<nome>" --category <CAT> [--runtime python|node|none] [--sem-remoto] [--dry-run]`

Nascimento protegido. Ordem, cada passo verificado, falha fechado com relatório do que já foi feito (sem apagar nada):
1. valida id (ID_RE), recusa se já existir no registry ou se o diretório existir e não estiver vazio;
2. cria `${AI_WORKSPACE}\work\<categoria-minúscula>\<id>` (fora do Drive/OneDrive);
3. copia `templates/project-standard` + STATE.md, HANDOFF.md, docs/decisions/, PROVENANCE.md, OWNERSHIP.md, AUTHORS.md, NOTICE (vazio-explicativo), `.github/CODEOWNERS`, `.env.example`, `.gitignore`, `.gitattributes`, CLAUDE.md e AGENTS.md (adapters);
4. `git init -b main`, commit inicial ASSINADO;
5. contrato `registry/projects/<id>.yaml` completo (identity, workspace, git, cloud.drive_root `<NN CATEGORIA>/<id>`, state, environment, secrets, backup, ai, portability target L6, ownership);
6. remoto: `gh repo create <owner>/<prefixo>-<id> --private` (prefixo da categoria só se o id não começar por ele), `git push -u origin main`, visibilidade conferida = PRIVATE; `--sem-remoto` pula e registra;
7. Drive root criado (`rclone mkdir`) — via a camada `cloud` existente;
8. primeiro backup (`backup.backup`) + `portability.verificar` → relatório com o nível atingido.
`--dry-run` imprime o plano sem efeito. Testes com fixture: sem rede (gh/rclone falsos injetáveis), em diretório temporário.

## 6. Arquivos de ownership (modelo)

- `PROVENANCE.md`: origem, data de criação, criadora, contexto (empresa/cliente), ferramentas usadas (inclusive IA e contas), componentes de terceiro, cadeia de custódia (onde o original vive, hashes).
- `OWNERSHIP.md`: titular declarada, base da declaração, o que NÃO é reivindicado (dependências, terceiros), contato.
- `AUTHORS.md`: criadora(s), contribuidores reais.
- `NOTICE`: atribuições de terceiros.
- `.github/CODEOWNERS`: `* @<owner_github>`.
